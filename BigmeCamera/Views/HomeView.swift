import SwiftUI

struct HomeView: View {
    @State private var showCamera = false
    @StateObject private var viewModel = CameraViewModel()
    @State private var appear = false
    @State private var buttonGlow = false

    var body: some View {
        ZStack {
            // 深炭黑渐变背景
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.08),
                    Color(red: 0.08, green: 0.07, blue: 0.12),
                    Color(red: 0.05, green: 0.05, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // 胶片颗粒纹理
            Canvas { context, size in
                for _ in 0..<1400 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let r = CGFloat.random(in: 0.4...1.1)
                    let alpha = Double.random(in: 0.025...0.08)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                        with: .color(.white.opacity(alpha))
                    )
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // 背景光晕装饰 — 琥珀金 + 冷蓝
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.accentAmber.opacity(0.12), .clear],
                            center: .center, startRadius: 0, endRadius: 220
                        )
                    )
                    .frame(width: 440, height: 440)
                    .offset(x: -90, y: -180)
                    .blur(radius: 50)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.2, green: 0.4, blue: 0.9).opacity(0.10), .clear],
                            center: .center, startRadius: 0, endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: 110, y: 140)
                    .blur(radius: 50)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 标题区
                VStack(spacing: 20) {
                    // 图标
                    ZStack {
                        // 外层光晕
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.accentAmber.opacity(0.20), .clear],
                                    center: .center, startRadius: 0, endRadius: 70
                                )
                            )
                            .frame(width: 160, height: 160)
                            .blur(radius: 24)

                        // 玻璃底圆
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .overlay {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.accentAmber.opacity(0.50), Color.white.opacity(0.10)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.8
                                    )
                            }
                            .shadow(color: Color.accentAmber.opacity(0.18), radius: 28)

                        Image(systemName: "camera.aperture")
                            .font(.system(size: 46, weight: .ultraLight))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color.accentAmber.opacity(0.80)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .scaleEffect(appear ? 1.0 : 0.65)
                    .opacity(appear ? 1.0 : 0)

                    // 标题 + 装饰
                    VStack(spacing: 8) {
                        Text(NSLocalizedString("BigmeCamera", comment: ""))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(1.5)

                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(Color.accentAmber.opacity(0.55))
                                .frame(width: 28, height: 0.7)
                            Text("AI · PORTRAIT · CAMERA")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.accentAmber.opacity(0.75))
                                .tracking(2.5)
                            Rectangle()
                                .fill(Color.accentAmber.opacity(0.55))
                                .frame(width: 28, height: 0.7)
                        }
                    }
                    .opacity(appear ? 1.0 : 0)
                    .offset(y: appear ? 0 : 10)

                    Text(NSLocalizedString("Welcome Message", comment: "欢迎使用大我相机"))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.50))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 52)
                        .opacity(appear ? 1.0 : 0)
                        .offset(y: appear ? 0 : 8)
                }

                Spacer()

                // 入口按钮 — 琥珀金描边
                Button {
                    showCamera = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color.accentAmber.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Text(NSLocalizedString("Start Camera", comment: "开始拍照"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .tracking(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .liquidGlass(cornerRadius: 29, accentTint: true)
                    .shadow(color: Color.accentAmber.opacity(buttonGlow ? 0.30 : 0.12), radius: buttonGlow ? 24 : 12)
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 60)
                .opacity(appear ? 1.0 : 0)
                .offset(y: appear ? 0 : 22)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(1.0)) {
                        buttonGlow = true
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.72, dampingFraction: 0.78).delay(0.1)) {
                appear = true
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            ContentView(viewModel: viewModel)
        }
    }
}
