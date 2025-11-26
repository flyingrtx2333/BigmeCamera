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
    
    // 粒子数据模型
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
            case star
            case sparkle
            case circle
            case heart
            
            var symbol: String {
                switch self {
                case .star: return "star.fill"
                case .sparkle: return "sparkle"
                case .circle: return "circle.fill"
                case .heart: return "heart.fill"
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(backgroundOpacity * 0.3)
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
                        .easeOut(duration: 1.5).delay(particle.delay),
                        value: showContent
                    )
            }
            
            // 中央内容
            VStack(spacing: 20) {
                // 图标
                ZStack {
                    // 光晕效果
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: isSuccess 
                                    ? [Color.green.opacity(0.6), Color.green.opacity(0)]
                                    : [Color.red.opacity(0.6), Color.red.opacity(0)],
                                center: .center,
                                startRadius: 30,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(iconScale * 1.2)
                        .opacity(iconOpacity * 0.5)
                    
                    // 主图标背景
                    Circle()
                        .fill(isSuccess ? Color.green : Color.red)
                        .frame(width: 100, height: 100)
                        .shadow(color: (isSuccess ? Color.green : Color.red).opacity(0.5), radius: 20)
                    
                    // 图标
                    Image(systemName: isSuccess ? "checkmark" : "xmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
                
                // 文字
                Text(isSuccess ? "已保存到相册" : "保存失败")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(textOpacity)
                
                // 副标题
                if isSuccess {
                    Text("✨ 精彩瞬间已记录 ✨")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(textOpacity)
                }
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // 生成粒子
        generateParticles()
        
        // 触发震动
        triggerHapticFeedback()
        
        // 背景淡入
        withAnimation(.easeOut(duration: 0.3)) {
            backgroundOpacity = 1
        }
        
        // 图标弹出动画
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            iconScale = 1.0
            iconOpacity = 1
        }
        
        // 文字淡入
        withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
            textOpacity = 1
        }
        
        // 粒子散开
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 1.0)) {
                animateParticles()
            }
        }
        
        // 延迟后触发消失动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showContent = true
        }
        
        // 自动消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                iconOpacity = 0
                textOpacity = 0
                backgroundOpacity = 0
                iconScale = 0.8
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onDismiss()
            }
        }
    }
    
    private func generateParticles() {
        let colors: [Color] = [
            .yellow, .orange, .pink, .purple, .cyan, .green, .red
        ]
        
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let centerX = screenWidth / 2
        let centerY = screenHeight / 2
        
        // 生成 20-30 个粒子
        let particleCount = Int.random(in: 20...30)
        
        for i in 0..<particleCount {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 50...80) // 初始距离
            
            let particle = Particle(
                x: centerX + cos(angle) * distance,
                y: centerY + sin(angle) * distance,
                size: CGFloat.random(in: 12...24),
                color: colors.randomElement()!,
                rotation: Double.random(in: 0...360),
                type: Particle.ParticleType.allCases.randomElement()!,
                delay: Double(i) * 0.02
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
            let distance = CGFloat.random(in: 150...300) // 散开距离
            
            particles[i].x = centerX + cos(angle) * distance
            particles[i].y = centerY + sin(angle) * distance
            particles[i].rotation += Double.random(in: 180...540)
        }
    }
    
    private func triggerHapticFeedback() {
        if isSuccess {
            // 成功：通知震动
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // 额外的轻微震动增强效果
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
        } else {
            // 失败：错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}

// 预览
#Preview {
    ZStack {
        Color.black
        SaveSuccessCelebrationView(isSuccess: true) {
            print("Dismissed")
        }
    }
}

