import SwiftUI

struct ControlPanelView: View {
    @ObservedObject var viewModel: CameraViewModel
    var showAdvancedControls: Binding<Bool>?
    @State private var internalShowAdvanced = false
    @State private var capturePressed = false

    private var showAdvanced: Bool {
        showAdvancedControls?.wrappedValue ?? internalShowAdvanced
    }

    private func toggleAdvanced() {
        if let b = showAdvancedControls { b.wrappedValue.toggle() }
        else { internalShowAdvanced.toggle() }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 高级控件抽屉
            if showAdvanced {
                advancedPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // 主控制栏
            mainBar
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showAdvanced)
    }

    // MARK: - 高级控件抽屉

    private var advancedPanel: some View {
        VStack(spacing: 16) {
            sliderRow(
                label: NSLocalizedString("Person Scale", comment: ""),
                value: String(format: "%.2fx", viewModel.config.personScale),
                binding: Binding(
                    get: { viewModel.config.personScale },
                    set: { viewModel.updateScale($0) }
                ),
                range: 1.0...1.8,
                step: 0.05
            )
            sliderRow(
                label: NSLocalizedString("Background Blur Intensity", comment: ""),
                value: "\(Int(viewModel.config.blurRadius))",
                binding: Binding(
                    get: { viewModel.config.blurRadius },
                    set: { viewModel.updateBlur($0) }
                ),
                range: 0...20,
                step: 1
            )

            // 分割质量选择器
            Picker(NSLocalizedString("Segmentation Quality", comment: ""), selection: Binding(
                get: { viewModel.config.quality },
                set: { viewModel.updateQuality($0) }
            )) {
                ForEach(SegmentationConfig.Quality.allCases) { q in
                    Text(q.displayName).tag(q)
                }
            }
            .pickerStyle(.segmented)
            .colorScheme(.dark)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .liquidGlass(cornerRadius: 24)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func sliderRow(label: String, value: String, binding: Binding<CGFloat>, range: ClosedRange<CGFloat>, step: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            }
            Slider(value: binding, in: range, step: step)
                .tint(.white)
        }
    }

    // MARK: - 主控制栏

    private var mainBar: some View {
        VStack(spacing: 12) {
            // 录像时长胶囊
            if viewModel.recordingVM.isRecording {
                recordingBadge
                    .transition(.scale.combined(with: .opacity))
            }

            // 按钮行
            HStack(spacing: 0) {
                // 左：模式切换
                modeToggleButton
                    .frame(maxWidth: .infinity)

                // 中：捕获按钮
                captureButton
                    .frame(maxWidth: .infinity)

                // 右：切换摄像头
                switchCameraButton
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)
        }
        .padding(.top, 12)
        .padding(.bottom, max(safeAreaBottom, 24))
        .background {
            // 液态玻璃底栏
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    // 顶部高光线
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .topTrailing) {
            advancedToggleButton
                .padding(.top, -44)
                .padding(.trailing, 16)
        }
    }

    // MARK: - 录像时长胶囊

    private var recordingBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .overlay {
                    Circle()
                        .fill(Color.red.opacity(0.4))
                        .frame(width: 16, height: 16)
                        .scaleEffect(1.0)
                }
            Text(viewModel.recordingVM.formattedDuration)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .liquidGlassCapsule()
    }

    // MARK: - 模式切换按钮

    private var modeToggleButton: some View {
        let isPhoto = viewModel.captureMode == .photo
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                viewModel.toggleCaptureMode()
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: isPhoto ? "video.fill" : "camera.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                Text(isPhoto ? NSLocalizedString("Video", comment: "录像") : NSLocalizedString("Photo", comment: "拍照"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .liquidGlassCircle(diameter: 56)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.recordingVM.isRecording)
        .opacity(viewModel.recordingVM.isRecording ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: viewModel.recordingVM.isRecording)
    }

    // MARK: - 捕获按钮

    private var captureButton: some View {
        Group {
            if viewModel.captureMode == .photo {
                photoButton
            } else {
                videoButton
            }
        }
    }

    private var photoButton: some View {
        Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                capturePressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                capturePressed = false
            }
            viewModel.capturePhoto()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            ZStack {
                // 外环
                Circle()
                    .stroke(.white.opacity(0.9), lineWidth: 3)
                    .frame(width: 76, height: 76)
                // 内圆（液态玻璃白色）
                Circle()
                    .fill(.white)
                    .frame(width: 64, height: 64)
                    .shadow(color: .white.opacity(0.4), radius: 12)
            }
            .scaleEffect(capturePressed ? 0.88 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.renderedFrame == nil)
        .opacity(viewModel.renderedFrame == nil ? 0.4 : 1.0)
    }

    private var videoButton: some View {
        let isRec = viewModel.recordingVM.isRecording
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.recordingVM.toggle(videoSize: viewModel.renderedFrame.map {
                    CGSize(width: $0.width, height: $0.height)
                } ?? CGSize(width: 1080, height: 1920))
            }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        } label: {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.9), lineWidth: 3)
                    .frame(width: 76, height: 76)
                    .recordingPulse(isRecording: isRec)

                if isRec {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                        .shadow(color: .red.opacity(0.6), radius: 8)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 64, height: 64)
                        .shadow(color: .red.opacity(0.5), radius: 12)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.renderedFrame == nil)
        .opacity(viewModel.renderedFrame == nil ? 0.4 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRec)
    }

    // MARK: - 切换摄像头

    private var switchCameraButton: some View {
        Button {
            viewModel.switchCamera()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white)
                .liquidGlassCircle(diameter: 56)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.recordingVM.isRecording)
        .opacity(viewModel.recordingVM.isRecording ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: viewModel.recordingVM.isRecording)
    }

    // MARK: - 高级控件切换按钮

    private var advancedToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                toggleAdvanced()
            }
        } label: {
            Image(systemName: showAdvanced ? "slider.horizontal.3" : "slider.horizontal.3")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(showAdvanced ? .white : .white.opacity(0.7))
                .frame(width: 36, height: 36)
                .background {
                    Circle()
                        .fill(showAdvanced ? Color.white.opacity(0.25) : Color.white.opacity(0.12))
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(showAdvanced ? 0.5 : 0.2), lineWidth: 0.6)
                        }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 安全区高度

    private var safeAreaBottom: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows.first?.safeAreaInsets.bottom ?? 0
    }
}
