import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: CameraViewModel
    @State private var initialZoom: CGFloat = 1.0
    
    // 新手帮助相关状态
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var onboardingStep: Int = 0
    @State private var showAdvancedControlsForOnboarding = false

    var body: some View {
        ZStack {
            CameraPreviewView(frame: viewModel.renderedFrame)
                .overlay(alignment: .topLeading) {
                    // 帧率显示（左上角，下移一点）
                    if viewModel.isSessionRunning {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(Int(viewModel.currentFPS)) FPS")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            
                            // 缩放倍数显示
                            Text("\(String(format: "%.2f", viewModel.currentZoom))x")
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            
                            // 质心调试信息
                            if let center = viewModel.personCenter {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("质心: (x: \(Int(center.x)), y: \(Int(center.y)))")
                                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.top, 60)
                        .padding(.leading)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    VStack(alignment: .trailing) {
                        if let success = viewModel.lastSaveSuccess {
                            SaveStatusBadge(isSuccess: success)
                        }
                        if viewModel.isSaving {
                            ProgressView()
                                .padding(8)
                                .background(.ultraThinMaterial,
                                            in: Capsule(style: .continuous))
                        }
                    }
                    .padding(.top, 60)
                    .padding(.trailing)
                }
                .overlay {
                    // 质心点可视化（主人物 + 分身）
                    if let frame = viewModel.renderedFrame,
                       viewModel.isSessionRunning {
                        GeometryReader { geometry in
                            let imageSize = CGSize(width: frame.width, height: frame.height)
                            let viewSize = geometry.size
                            
                            // 计算scaledToFill的缩放比例和偏移
                            let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
                            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                            let offsetX = (scaledSize.width - viewSize.width) / 2
                            let offsetY = (scaledSize.height - viewSize.height) / 2
                            
                            // 主人物质心
                            if let center = viewModel.personCenter {
                                let uiKitY = imageSize.height - center.y
                                let screenX = center.x * scale - offsetX
                                let screenY = uiKitY * scale - offsetY
                                
                                CenterPointView(
                                    color: .red,
                                    isSelected: viewModel.selectedCloneId == nil,
                                    label: "主"
                                )
                                .position(x: screenX, y: screenY)
                                .highPriorityGesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            viewModel.selectClone(id: nil)
                                            let imageX = (value.location.x + offsetX) / scale
                                            let imageY = (value.location.y + offsetY) / scale
                                            let flippedY = imageSize.height - imageY
                                            let imagePoint = CGPoint(x: imageX, y: flippedY)
                                            viewModel.updateManualPersonCenter(imagePoint, imageSize: imageSize)
                                        }
                                )
                            }
                            
                            // 分身质心
                            ForEach(viewModel.clones) { clone in
                                let uiKitY = imageSize.height - clone.center.y
                                let screenX = clone.center.x * scale - offsetX
                                let screenY = uiKitY * scale - offsetY
                                let cloneIndex = viewModel.clones.firstIndex(where: { $0.id == clone.id }) ?? 0
                                
                                CenterPointView(
                                    color: .blue,
                                    isSelected: viewModel.selectedCloneId == clone.id,
                                    label: "\(cloneIndex + 1)"
                                )
                                .position(x: screenX, y: screenY)
                                .highPriorityGesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            viewModel.selectClone(id: clone.id)
                                            let imageX = (value.location.x + offsetX) / scale
                                            let imageY = (value.location.y + offsetY) / scale
                                            let flippedY = imageSize.height - imageY
                                            let imagePoint = CGPoint(x: imageX, y: flippedY)
                                            viewModel.updateCloneCenter(id: clone.id, center: imagePoint, imageSize: imageSize)
                                        }
                                )
                            }
                        }
                    }
                }

            // 左侧控制列
            HStack {
                if viewModel.authorizationStatus == .authorized && viewModel.isSessionRunning {
                    SideControlPanelView(viewModel: viewModel)
                        .padding(.leading, 8)
                        .padding(.top, 100)
                }
                Spacer()
            }
            
            VStack {
                Spacer()
                if viewModel.authorizationStatus == .authorized {
                    ControlPanelView(viewModel: viewModel, showAdvancedControls: $showAdvancedControlsForOnboarding)
                } else {
                    PermissionView(requestAction: {
                        viewModel.requestPermission()
                    })
                    .padding()
                }
            }
            
            // 新手帮助覆盖层
            if !hasCompletedOnboarding && onboardingStep > 0 && viewModel.isSessionRunning {
                if let center = viewModel.personCenter,
                   let frame = viewModel.renderedFrame {
                    GeometryReader { geometry in
                        let imageSize = CGSize(width: frame.width, height: frame.height)
                        let viewSize = geometry.size
                        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
                        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                        let offsetX = (scaledSize.width - viewSize.width) / 2
                        let offsetY = (scaledSize.height - viewSize.height) / 2
                        
                        OnboardingGuideView(
                            currentStep: $onboardingStep,
                            isCompleted: $hasCompletedOnboarding,
                            personCenter: center,
                            viewSize: viewSize,
                            imageSize: imageSize,
                            scale: scale,
                            offsetX: offsetX,
                            offsetY: offsetY
                        )
                    }
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .gesture(
            MagnificationGesture(minimumScaleDelta: 0.01)
                .onChanged { value in
                    if initialZoom == 1.0 {
                        initialZoom = viewModel.currentZoom
                    }
                    viewModel.updateZoomByScale(value, initialZoom: initialZoom)
                }
                .onEnded { _ in
                    initialZoom = 1.0
                }
        )
        .onAppear {
            viewModel.onAppear()
            // 首次进入时启动新手帮助
            if !hasCompletedOnboarding && viewModel.authorizationStatus == .authorized {
                // 等待相机启动后再显示帮助
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if viewModel.isSessionRunning && viewModel.personCenter != nil {
                        onboardingStep = 1
                        // 步骤3需要显示高级控件
                        if onboardingStep == 3 {
                            showAdvancedControlsForOnboarding = true
                        }
                    }
                }
            }
        }
        .onChange(of: onboardingStep) { newStep in
            // 步骤3需要显示高级控件
            if newStep == 3 {
                showAdvancedControlsForOnboarding = true
            }
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
}

// MARK: - 质心点视图组件

struct CenterPointView: View {
    let color: Color
    let isSelected: Bool
    let label: String
    
    var body: some View {
        ZStack {
            // 外圈（选中时显示）
            if isSelected {
                Circle()
                    .stroke(color.opacity(0.5), lineWidth: 2)
                    .frame(width: 32, height: 32)
            }
            
            // 中心点
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 18, height: 18)
                }
            
            // 标签
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
                .offset(y: 20)
        }
    }
}

