import SwiftUI

struct ControlPanelView: View {
    @ObservedObject var viewModel: CameraViewModel
    var showAdvancedControls: Binding<Bool>?
    @State private var internalShowAdvancedControls = false
    
    init(viewModel: CameraViewModel, showAdvancedControls: Binding<Bool>? = nil) {
        self.viewModel = viewModel
        self.showAdvancedControls = showAdvancedControls
    }
    
    private var actualShowAdvancedControls: Bool {
        showAdvancedControls?.wrappedValue ?? internalShowAdvancedControls
    }
    
    private func toggleAdvancedControls() {
        if let binding = showAdvancedControls {
            binding.wrappedValue.toggle()
        } else {
            internalShowAdvancedControls.toggle()
        }
    }

    var body: some View {
            VStack(spacing: 0) {
            // 上方控件区域（高级控件，可折叠）
            if actualShowAdvancedControls {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(NSLocalizedString("Person Scale", comment: "")) \(String(format: "%.2f", viewModel.config.personScale))x")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                        Slider(value: Binding(
                            get: { viewModel.config.personScale },
                            set: { viewModel.updateScale($0) }
                        ), in: 1.0...1.8, step: 0.05)
                        .tint(.white)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(NSLocalizedString("Background Blur Intensity", comment: "")) \(Int(viewModel.config.blurRadius))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                        Slider(value: Binding(
                            get: { viewModel.config.blurRadius },
                            set: { viewModel.updateBlur($0) }
                        ), in: 0...20, step: 1)
                        .tint(.white)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 100)
            }
            
            Spacer()
            
            // 底部控制区域（类似 iPhone 原生相机）
            VStack(spacing: 16) {
                // Picker 在拍照按钮上方中央
                Picker(NSLocalizedString("Segmentation Quality", comment: ""), selection: Binding(
                    get: { viewModel.config.quality },
                    set: { viewModel.updateQuality($0) }
                )) {
                    ForEach(SegmentationConfig.Quality.allCases) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                .colorScheme(.dark)
                
                // 录像时显示时长
                if viewModel.isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                        
                        Text(viewModel.formattedRecordingDuration)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background {
                        Capsule()
                            .fill(Color.black.opacity(0.5))
                    }
                }
                
                // 底部按钮行：拍照/录像切换（左）+ 拍照/录像按钮（中央）+ 切换摄像头按钮（右）
                HStack {
                    // 左侧：拍照/录像切换按钮
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.toggleCaptureMode()
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: viewModel.captureMode == .photo ? "camera.fill" : "video.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                            
                            Text(viewModel.captureMode.rawValue)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(width: 60, height: 60)
                        .background {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isRecording)
                    .opacity(viewModel.isRecording ? 0.5 : 1.0)
                    
                    Spacer()
                    
                    // 中间：拍照/录像按钮
                    if viewModel.captureMode == .photo {
                        // 拍照按钮（白色圆点）
                        Button {
                            viewModel.capturePhoto()
                        } label: {
                            ZStack {
                                Circle()
                                    .stroke(Color.white, lineWidth: 5)
                                    .frame(width: 76, height: 76)
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 66, height: 66)
                            }
                        }
                        .disabled(viewModel.renderedFrame == nil)
                        .opacity(viewModel.renderedFrame == nil ? 0.5 : 1.0)
                        .scaleEffect(viewModel.isSaving ? 0.9 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: viewModel.isSaving)
                    } else {
                        // 录像按钮（红色圆点，录制中变方形）
                        Button {
                            viewModel.toggleRecording()
                        } label: {
                            ZStack {
                                Circle()
                                    .stroke(Color.white, lineWidth: 5)
                                    .frame(width: 76, height: 76)
                                
                                if viewModel.isRecording {
                                    // 录制中：红色方形（停止按钮）
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.red)
                                        .frame(width: 30, height: 30)
                                } else {
                                    // 未录制：红色圆形
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 66, height: 66)
                                }
                            }
                        }
                        .disabled(viewModel.renderedFrame == nil)
                        .opacity(viewModel.renderedFrame == nil ? 0.5 : 1.0)
                    }
                    
                    Spacer()
                    
                    // 右侧：切换摄像头按钮
                    Button {
                        viewModel.switchCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isRecording)
                    .opacity(viewModel.isRecording ? 0.5 : 1.0)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .overlay(alignment: .topTrailing) {
            // 右上角高级控件切换按钮
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    toggleAdvancedControls()
                }
            } label: {
                Image(systemName: actualShowAdvancedControls ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, 60)
            .padding(.trailing, 20)
        }
    }
}

