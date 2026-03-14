import SwiftUI

/// 保存成功庆祝动画视图
struct SaveSuccessCelebrationView: View {
    let isSuccess: Bool
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var particles: [Particle] = []
    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var backgroundOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var color: Color
        var rotation: Double
        var type: ParticleType
        var delay: Double

        enum ParticleType: CaseIterable {
            case star, sparkle, circle, diamond

            var symbol: String {
                switch self {
                case .star: return "star.fill"
                case .sparkle: return "sparkle"
                case .circle: return "circle.fill"
                case .diamond: return "diamond.fill"
                }
            }
        }
    }

    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(backgroundOpacity * 0.45)
                .ignoresSafeArea()

            // 粒子效果
            ForEach(particles) { particle in
                Image(systemName: particle.type.symbol)
                    .font(.system(size: particle.size))
                    .foregroundColor(particle.color)
                    .rotationEffect(.degrees(particle.rotation))
                    .position(x: particle.x, y: particle.y)
                    .opacity(showContent ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.4).delay(particle.delay),
                        value: showContent
                    )
            }

            // 中央内容
            VStack(spacing: 22) {
                ZStack {
                    // 扩散环
                    Circle()
                        .stroke(
                            (isSuccess ? Color.accentAmber : Color.red).opacity(ringOpacity * 0.5),
                            lineWidth: 1.5
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(ringScale)

                    // 外光晕
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: isSuccess
                                    ? [Color.accentAmber.opacity(0.45), .clear]
                                    : [Color.red.opacity(0.45), .clear],
                                center: .center,
                                startRadius: 28,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(iconScale * 1.15)
                        .opacity(iconOpacity * 0.55)

                    // 主图标背景
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isSuccess
                                    ? [Color.accentAmber, Color(red: 0.9, green: 0.55, blue: 0.1)]
                                    : [Color.red, Color(red: 0.8, green: 0.1, blue: 0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: (isSuccess ? Color.accentAmber : Color.red).opacity(0.55), radius: 24)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.25), lineWidth: 0.8)
                        }

                    Image(systemName: isSuccess ? "checkmark" : "xmark")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

                VStack(spacing: 6) {
                    Text(isSuccess ? "已保存到相册" : "保存失败")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    if isSuccess {
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(Color.accentAmber.opacity(0.55))
                                .frame(width: 20, height: 0.6)
                            Text("精彩瞬间已记录")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.accentAmber.opacity(0.80))
                                .tracking(1.5)
                            Rectangle()
                                .fill(Color.accentAmber.opacity(0.55))
                                .frame(width: 20, height: 0.6)
                        }
                    }
                }
                .opacity(textOpacity)
            }
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        generateParticles()
        triggerHapticFeedback()

        withAnimation(.easeOut(duration: 0.3)) {
            backgroundOpacity = 1
        }
        withAnimation(.spring(response: 0.48, dampingFraction: 0.58)) {
            iconScale = 1.0
            iconOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.9)) {
            ringScale = 1.8
            ringOpacity = 1.0
        }
        withAnimation(.easeIn(duration: 0.6).delay(0.3)) {
            ringOpacity = 0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
            textOpacity = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 1.0)) {
                animateParticles()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showContent = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                iconOpacity = 0
                textOpacity = 0
                backgroundOpacity = 0
                iconScale = 0.82
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onDismiss()
            }
        }
    }

    private func generateParticles() {
        let successColors: [Color] = [Color.accentAmber, .white, Color(red: 1.0, green: 0.9, blue: 0.5), .yellow, .orange]
        let failColors: [Color] = [.red, .orange, .white, Color(red: 1.0, green: 0.4, blue: 0.4)]
        let colors = isSuccess ? successColors : failColors

        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let centerX = screenWidth / 2
        let centerY = screenHeight / 2

        let particleCount = Int.random(in: 22...32)
        for i in 0..<particleCount {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 45...75)
            let particle = Particle(
                x: centerX + cos(angle) * distance,
                y: centerY + sin(angle) * distance,
                size: CGFloat.random(in: 10...20),
                color: colors.randomElement()!,
                rotation: Double.random(in: 0...360),
                type: Particle.ParticleType.allCases.randomElement()!,
                delay: Double(i) * 0.018
            )
            particles.append(particle)
        }
    }

    private func animateParticles() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let centerX = screenWidth / 2
        let centerY = screenHeight / 2

        for i in 0..<particles.count {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 140...280)
            particles[i].x = centerX + cos(angle) * distance
            particles[i].y = centerY + sin(angle) * distance
            particles[i].rotation += Double.random(in: 180...540)
        }
    }

    private func triggerHapticFeedback() {
        if isSuccess {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

#Preview {
    ZStack {
        Color.black
        SaveSuccessCelebrationView(isSuccess: true) { print("Dismissed") }
    }
}
