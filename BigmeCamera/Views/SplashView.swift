import SwiftUI

struct SplashView: View {
    @State private var isActive = false
    @State private var logoScale: CGFloat = 0.55
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var glowRadius: CGFloat = 0
    @State private var ringScale: CGFloat = 0.4
    @State private var ringOpacity: Double = 0
    @State private var grainOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0

    var body: some View {
        ZStack {
            // 深炭黑底色
            Color.surfaceDark.ignoresSafeArea()

            // 胶片颗粒纹理（Canvas 噪点模拟）
            Canvas { context, size in
                for _ in 0..<1800 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let r = CGFloat.random(in: 0.4...1.2)
                    let alpha = Double.random(in: 0.03...0.10)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                        with: .color(.white.opacity(alpha))
                    )
                }
            }
            .ignoresSafeArea()
            .opacity(grainOpacity)
            .allowsHitTesting(false)

            // 琥珀金径向光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.accentAmber.opacity(0.18), .clear],
                        center: .center, startRadius: 0, endRadius: 220
                    )
                )
                .frame(width: 440, height: 440)
                .blur(radius: 70)
                .opacity(logoOpacity)

            // 扩散环 — 琥珀金
            Circle()
                .stroke(Color.accentAmber.opacity(0.12), lineWidth: 1)
                .frame(width: 200, height: 200)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            Circle()
                .stroke(Color.accentAmber.opacity(0.06), lineWidth: 0.8)
                .frame(width: 200, height: 200)
                .scaleEffect(ringScale * 1.6)
                .opacity(ringOpacity * 0.5)

            VStack(spacing: 24) {
                // Logo 容器
                ZStack {
                    // 外层光晕圆
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.accentAmber.opacity(0.14), .clear],
                                center: .center, startRadius: 0, endRadius: 70
                            )
                        )
                        .frame(width: 140, height: 140)
                        .blur(radius: 20)
                        .shadow(color: Color.accentAmber.opacity(0.25), radius: glowRadius)

                    // 玻璃圆底
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 112, height: 112)
                        .overlay {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.accentAmber.opacity(0.45), Color.white.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.8
                                )
                        }

                    Image(systemName: "camera.aperture")
                        .font(.system(size: 52, weight: .ultraLight))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.accentAmber.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                VStack(spacing: 6) {
                    Text(NSLocalizedString("BigmeCamera", comment: ""))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(2)
                        .opacity(textOpacity)

                    // 装饰分隔线
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(Color.accentAmber.opacity(0.5))
                            .frame(width: 24, height: 0.6)
                        Circle()
                            .fill(Color.accentAmber.opacity(0.7))
                            .frame(width: 3, height: 3)
                        Rectangle()
                            .fill(Color.accentAmber.opacity(0.5))
                            .frame(width: 24, height: 0.6)
                    }
                    .opacity(subtitleOpacity)

                    Text("AI · PORTRAIT · CAMERA")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.accentAmber.opacity(0.7))
                        .tracking(3)
                        .opacity(subtitleOpacity)
                }
            }
        }
        .onAppear { startAnimation() }
        .fullScreenCover(isPresented: $isActive) { HomeView() }
    }

    private func startAnimation() {
        // 颗粒纹理淡入
        withAnimation(.easeOut(duration: 0.6)) {
            grainOpacity = 1.0
        }
        // Logo 弹入
        withAnimation(.spring(response: 0.72, dampingFraction: 0.62)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        // 扩散环
        withAnimation(.easeOut(duration: 1.3)) {
            ringScale = 2.2
            ringOpacity = 1.0
        }
        withAnimation(.easeIn(duration: 0.9).delay(0.45)) {
            ringOpacity = 0
        }
        // 光晕增强
        withAnimation(.easeOut(duration: 1.1).delay(0.2)) {
            glowRadius = 48
        }
        // 文字淡入
        withAnimation(.easeOut(duration: 0.5).delay(0.38)) {
            textOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.55)) {
            subtitleOpacity = 1.0
        }
        // 跳转
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeIn(duration: 0.28)) {
                isActive = true
            }
        }
    }
}
