import SwiftUI

// MARK: - 液态玻璃 ViewModifier

struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var tintOpacity: CGFloat  // 0 = 纯透明, 0.15 = 轻微着色

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    // 内层高光渐变
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.12),
                                        .white.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    // 边框高光
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.45),
                                        .white.opacity(0.10)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.6
                            )
                    }
                    .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - 胶囊形液态玻璃

struct LiquidGlassCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.12), .white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.45), .white.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.6
                            )
                    }
                    .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 6)
            }
            .clipShape(Capsule(style: .continuous))
    }
}

// MARK: - 圆形液态玻璃按钮背景

struct LiquidGlassCircleModifier: ViewModifier {
    var diameter: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(width: diameter, height: diameter)
            .background {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.14), .white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.6
                            )
                    }
                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
            }
    }
}

// MARK: - View 扩展

extension View {
    func liquidGlass(cornerRadius: CGFloat = 20, tintOpacity: CGFloat = 0) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, tintOpacity: tintOpacity))
    }

    func liquidGlassCapsule() -> some View {
        modifier(LiquidGlassCapsuleModifier())
    }

    func liquidGlassCircle(diameter: CGFloat) -> some View {
        modifier(LiquidGlassCircleModifier(diameter: diameter))
    }
}

// MARK: - 录制脉冲动画修饰符

struct RecordingPulse: ViewModifier {
    let isRecording: Bool
    @State private var pulse = false

    func body(content: Content) -> some View {
        content.overlay {
            if isRecording {
                Circle()
                    .stroke(Color.red.opacity(pulse ? 0 : 0.6), lineWidth: 3)
                    .scaleEffect(pulse ? 1.6 : 1.0)
                    .animation(
                        .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                        value: pulse
                    )
                    .onAppear { pulse = true }
                    .onDisappear { pulse = false }
            }
        }
    }
}

extension View {
    func recordingPulse(isRecording: Bool) -> some View {
        modifier(RecordingPulse(isRecording: isRecording))
    }
}
