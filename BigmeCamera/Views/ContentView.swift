import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: CameraViewModel
    @State private var initialZoom: CGFloat = 1.0

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var onboardingStep: Int = 0
    @State private var showAdvancedControlsForOnboarding = false

    var body: some View {
        ZStack {
            CameraPreviewView(frame: viewModel.renderedFrame)
                .overlay(alignment: .topLeading) { debugHUD }
                .overlay(alignment: .topTrailing) { savingIndicator }
                .overlay { interactionOverlay }

            // 左侧控制列
            VStack {
                HStack {
                    if viewModel.authorizationStatus == .authorized && viewModel.isSessionRunning {
                        SideControlPanelView(
                            cloneVM: viewModel.cloneVM,
                            stickerVM: viewModel.stickerVM,
                            filterVM: viewModel.filterVM,
                            personCenter: viewModel.personCenter
                        )
                        .padding(.leading, 8)
                        .padding(.top, 100)
                    }
                    Spacer()
                }
                Spacer().frame(height: 180)
            }

            // 底部控制栏
            VStack {
                Spacer()
                if viewModel.authorizationStatus == .authorized {
                    ControlPanelView(viewModel: viewModel, showAdvancedControls: $showAdvancedControlsForOnboarding)
                } else {
                    PermissionView(requestAction: { viewModel.requestPermission() })
                        .padding()
                }
            }

            // 新手引导
            if !hasCompletedOnboarding && onboardingStep > 0 && viewModel.isSessionRunning,
               let center = viewModel.personCenter,
               let frame = viewModel.renderedFrame {
                GeometryReader { geo in
                    let cs = ImageCoordinateSpace(
                        imageSize: CGSize(width: frame.width, height: frame.height),
                        viewSize: geo.size
                    )
                    OnboardingGuideView(
                        currentStep: $onboardingStep,
                        isCompleted: $hasCompletedOnboarding,
                        personCenter: center,
                        viewSize: geo.size,
                        imageSize: CGSize(width: frame.width, height: frame.height),
                        scale: cs.scale,
                        offsetX: cs.offsetX,
                        offsetY: cs.offsetY
                    )
                }
            }

            // 保存庆祝动画
            if viewModel.showSaveCelebration, let success = viewModel.lastSaveSuccess {
                SaveSuccessCelebrationView(isSuccess: success) {
                    viewModel.dismissSaveCelebration()
                }
            }

            // 录像保存庆祝动画
            if viewModel.recordingVM.showSaveCelebration,
               let success = viewModel.recordingVM.lastSaveSuccess {
                SaveSuccessCelebrationView(isSuccess: success) {
                    viewModel.recordingVM.dismissCelebration()
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .gesture(
            MagnificationGesture(minimumScaleDelta: 0.01)
                .onChanged { value in
                    if initialZoom == 1.0 { initialZoom = viewModel.currentZoom }
                    viewModel.updateZoomByScale(value, initialZoom: initialZoom)
                }
                .onEnded { _ in initialZoom = 1.0 }
        )
        .onAppear {
            viewModel.onAppear()
            if !hasCompletedOnboarding && viewModel.authorizationStatus == .authorized {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if viewModel.isSessionRunning && viewModel.personCenter != nil {
                        onboardingStep = 1
                    }
                }
            }
        }
        .onChange(of: onboardingStep) { newStep in
            if newStep == 3 { showAdvancedControlsForOnboarding = true }
        }
        .onDisappear { viewModel.onDisappear() }
    }

    // MARK: - 子视图

    @ViewBuilder
    private var debugHUD: some View {
        if viewModel.isSessionRunning {
            HStack(spacing: 8) {
                // FPS 胶囊
                Text("\(Int(viewModel.currentFPS)) FPS")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .liquidGlassCapsule()

                // 缩放倍数
                Text("\(String(format: "%.1f", viewModel.currentZoom))×")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .liquidGlassCapsule()
            }
            .padding(.top, 56)
            .padding(.leading, 16)
        }
    }

    @ViewBuilder
    private var savingIndicator: some View {
        if viewModel.isSaving {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.75)
                    .tint(.white)
                Text("保存中...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .liquidGlassCapsule()
            .padding(.top, 56)
            .padding(.trailing, 16)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var interactionOverlay: some View {
        if let frame = viewModel.renderedFrame, viewModel.isSessionRunning {
            GeometryReader { geo in
                let cs = ImageCoordinateSpace(
                    imageSize: CGSize(width: frame.width, height: frame.height),
                    viewSize: geo.size
                )

                // 主人物质心
                if let center = viewModel.personCenter {
                    let screenPt = cs.toScreen(center)
                    CenterPointView(
                        color: .red,
                        isSelected: viewModel.cloneVM.selectedCloneId == nil,
                        label: "主"
                    )
                    .position(screenPt)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0).onChanged { value in
                            viewModel.cloneVM.select(id: nil)
                            viewModel.updateManualPersonCenter(
                                cs.toImage(value.location),
                                imageSize: cs.imageSize
                            )
                        }
                    )
                }

                // 分身质心
                ForEach(viewModel.cloneVM.clones) { clone in
                    let screenPt = cs.toScreen(clone.center)
                    let idx = viewModel.cloneVM.clones.firstIndex(where: { $0.id == clone.id }) ?? 0
                    CenterPointView(
                        color: .blue,
                        isSelected: viewModel.cloneVM.selectedCloneId == clone.id,
                        label: "\(idx + 1)"
                    )
                    .position(screenPt)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0).onChanged { value in
                            viewModel.cloneVM.select(id: clone.id)
                            viewModel.cloneVM.updateCenter(
                                id: clone.id,
                                center: cs.toImage(value.location),
                                imageSize: cs.imageSize
                            )
                        }
                    )
                }

                // 贴纸控制点
                ForEach(viewModel.stickerVM.stickers) { sticker in
                    let screenPt = cs.toScreen(sticker.center)
                    StickerControlView(
                        sticker: sticker,
                        isSelected: viewModel.stickerVM.selectedStickerId == sticker.id,
                        screenScale: cs.scale
                    )
                    .position(screenPt)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0).onChanged { value in
                            viewModel.stickerVM.select(id: sticker.id)
                            viewModel.stickerVM.updateCenter(
                                id: sticker.id,
                                center: cs.toImage(value.location),
                                imageSize: cs.imageSize
                            )
                        }
                    )
                }
            }
        }
    }
}

// MARK: - 质心点视图

struct CenterPointView: View {
    let color: Color
    let isSelected: Bool
    let label: String
    @State private var dragging = false

    var body: some View {
        ZStack {
            // 选中光晕
            if isSelected {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 44, height: 44)
                    .blur(radius: 4)

                Circle()
                    .stroke(color.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 34, height: 34)
            }

            // 中心点
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
                .overlay {
                    Circle()
                        .stroke(Color.white, lineWidth: 2.5)
                        .frame(width: 20, height: 20)
                }
                .shadow(color: color.opacity(0.6), radius: 6)

            // 标签
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .offset(y: 22)
        }
        .scaleEffect(dragging ? 1.25 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: dragging)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in dragging = true }
                .onEnded { _ in dragging = false }
        )
    }
}

// MARK: - 贴纸控制视图

struct StickerControlView: View {
    let sticker: StickerInstance
    let isSelected: Bool
    let screenScale: CGFloat

    var body: some View {
        let stickerColor = Color(
            red: sticker.type.color.r,
            green: sticker.type.color.g,
            blue: sticker.type.color.b
        )
        ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange, lineWidth: 2)
                    .frame(width: 60, height: 60)
            }
            Circle()
                .fill(isSelected ? Color.orange : Color.white.opacity(0.6))
                .frame(width: 16, height: 16)
                .overlay {
                    Circle().stroke(Color.white, lineWidth: 2).frame(width: 20, height: 20)
                }
            Image(systemName: sticker.type.rawValue)
                .font(.system(size: 12))
                .foregroundColor(stickerColor)
                .offset(x: 16, y: -16)
        }
    }
}
