import SwiftUI

struct SplashView: View {
    @State private var isActive = false
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var glowRadius: CGFloat = 0
    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: Double = 0

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.10)
                .ignoresSafeArea()

            // 背景光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.22), .clear],
                        center: .center, startRadius: 0, endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .opacity(logoOpacity)

            // 扩散环
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: 200, height: 200)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                .frame(width: 200, height: 200)
                .scaleEffect(ringScale * 1.5)
                .opacity(ringOpacity * 0.6)

            VStack(spacing: 20) {
                // Logo
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 120, height: 120)
                        .shadow(color: .white.opacity(0.15), radius: glowRadius)

                    Image(systemName: "camera.aperture")
                        .font(.system(size: 56, weight: .ultraLight))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                Text(NSLocalizedString("BigmeCamera", comment: ""))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(textOpacity)
            }
        }
        .onAppear { startAnimation() }
        .fullScreenCover(isPresented: $isActive) { HomeView() }
    }

    private func startAnimation() {
        // 光晕 + Logo 弹入
        withAnimation(.spring(response: 0.7, dampingFraction: 0.65)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        // 扩散环
        withAnimation(.easeOut(duration: 1.2)) {
            ringScale = 2.0
            ringOpacity = 1.0
        }
        withAnimation(.easeIn(duration: 0.8).delay(0.4)) {
            ringOpacity = 0
        }
        // 光晕增强
        withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
            glowRadius = 40
        }
        // 文字淡入
        withAnimation(.easeOut(duration: 0.5).delay(0.35)) {
            textOpacity = 1.0
        }
        // 跳转
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeIn(duration: 0.25)) {
                isActive = true
            }
        }
    }
}
