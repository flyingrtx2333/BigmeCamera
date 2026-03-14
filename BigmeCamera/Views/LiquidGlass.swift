import SwiftUI

// MARK: - 设计令牌

extension Color {
    /// 琥珀金高光
    static let accentAmber = Color(red: 1.0, green: 0.78, blue: 0.35)
    /// 深炭黑背景
    static let surfaceDark = Color(red: 0.06, green: 0.06, blue: 0.09)
    /// 中层面板背景
    static let surfaceMid = Color(red: 0.10, green: 0.10, blue: 0.14)
}

// MARK: - 液态玻璃 ViewModifier

struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var tintOpacity: CGFloat  // 0 = 纯透明, 0.15 = 轻微着色
    var accentTint: Bool = false  // 琥珀金边框变体

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
                                        .white.opacity(0.10),
                                        .white.opacity(0.02)
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
                                    colors: accentTint
                                        ? [Color.accentAmber.opacity(0.55), Color.accentAmber.opacity(0.12)]
                                        : [.white.opacity(0.38), .white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.7
                            )
                    }
                    .shadow(color: .black.opacity(0.40), radius: 32, x: 0, y: 12)
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - 胶囊形液态玻璃

struct LiquidGlassCapsuleModifier: ViewModifier {
    var accentTint: Bool = false

    func body(content: Content) -> some View {
        content
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.10), .white.opacity(0.02)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: accentTint
                                        ? [Color.accentAmber.opacity(0.55), Color.accentAmber.opacity(0.12)]
                                        : [.white.opacity(0.38), .white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.7
                            )
                    }
                    .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 8)
            }
            .clipShape(Capsule(style: .continuous))
    }
}

// MARK: - 圆形液态玻璃按钮背景

struct LiquidGlassCircleModifier: ViewModifier {
    var diameter: CGFloat
    var accentTint: Bool = false

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
                                    colors: [.white.opacity(0.12), .white.opacity(0.03)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: accentTint
                                        ? [Color.accentAmber.opacity(0.6), Color.accentAmber.opacity(0.15)]
                                        : [.white.opacity(0.45), .white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.7
                            )
                    }
                    .shadow(color: .black.opacity(0.30), radius: 16, x: 0, y: 5)
            }
    }
}

// MARK: - View 扩展

extension View {
    func liquidGlass(cornerRadius: CGFloat = 20, tintOpacity: CGFloat = 0, accentTint: Bool = false) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, tintOpacity: tintOpacity, accentTint: accentTint))
    }

    func liquidGlassCapsule(accentTint: Bool = false) -> some View {
        modifier(LiquidGlassCapsuleModifier(accentTint: accentTint))
    }

    func liquidGlassCircle(diameter: CGFloat, accentTint: Bool = false) -> some View {
        modifier(LiquidGlassCircleModifier(diameter: diameter, accentTint: accentTint))
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
                    .stroke(Color.red.opacity(pulse ? 0 : 0.55), lineWidth: 2.5)
                    .scaleEffect(pulse ? 1.7 : 1.0)
                    .animation(
                        .easeOut(duration: 1.1).repeatForever(autoreverses: false),
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
