import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: CameraViewModel

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
                    // 质心点可视化
                    if let center = viewModel.personCenter,
                       let frame = viewModel.renderedFrame,
                       viewModel.isSessionRunning {
                        GeometryReader { geometry in
                            let imageSize = CGSize(width: frame.width, height: frame.height)
                            let viewSize = geometry.size
                            
                            // 计算scaledToFill的缩放比例和偏移
                            let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
                            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                            let offsetX = (scaledSize.width - viewSize.width) / 2
                            let offsetY = (scaledSize.height - viewSize.height) / 2
                            
                            // 将质心坐标映射到屏幕坐标
                            // 注意：渲染器返回的 center 是基于 CIImage 坐标系（左下角原点）
                            // 但 CGImage 显示时使用 UIKit 坐标系（左上角原点），需要翻转 y 轴
                            let uiKitY = imageSize.height - center.y
                            let screenX = center.x * scale - offsetX
                            let screenY = uiKitY * scale - offsetY
                            
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .overlay {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                        .frame(width: 16, height: 16)
                                }
                                .position(x: screenX, y: screenY)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            // 将拖动位置转换为图像坐标（UIKit 坐标系）
                                            let imageX = (value.location.x + offsetX) / scale
                                            let imageY = (value.location.y + offsetY) / scale
                                            // 注意：CGImage 使用 UIKit 坐标系（左上角原点），但 Core Image 使用左下角原点
                                            // 由于渲染器最终输出 CGImage，我们需要确保坐标一致
                                            // 但实际渲染时使用的是 CIImage 坐标系，所以需要翻转 y 轴
                                            let flippedY = imageSize.height - imageY
                                            let imagePoint = CGPoint(x: imageX, y: flippedY)
                                            viewModel.updateManualPersonCenter(imagePoint, imageSize: imageSize)
                                        }
                                )
                        }
                    }
                }

            VStack {
                Spacer()
                if viewModel.authorizationStatus == .authorized {
                    ControlPanelView(viewModel: viewModel)
                } else {
                    PermissionView(requestAction: {
                        viewModel.requestPermission()
                    })
                    .padding()
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
}

