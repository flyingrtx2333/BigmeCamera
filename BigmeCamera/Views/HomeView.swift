import SwiftUI

struct HomeView: View {
    @State private var showCamera = false
    @StateObject private var viewModel = CameraViewModel()
    @State private var appear = false

    var body: some View {
        ZStack {
            // 深色渐变背景
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.04, blue: 0.10),
                    Color(red: 0.08, green: 0.06, blue: 0.16),
                    Color(red: 0.04, green: 0.04, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // 背景光晕装饰
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.18), .clear],
                            center: .center, startRadius: 0, endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: -80, y: -160)
                    .blur(radius: 40)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.14), .clear],
                            center: .center, startRadius: 0, endRadius: 180
                        )
                    )
                    .frame(width: 360, height: 360)
                    .offset(x: 100, y: 120)
                    .blur(radius: 40)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 标题区
                VStack(spacing: 16) {
                    // 图标
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 96, height: 96)
                            .overlay {
                                Circle()
                                    .stroke(.white.opacity(0.2), lineWidth: 0.6)
                            }
                            .shadow(color: .white.opacity(0.1), radius: 24)

                        Image(systemName: "camera.aperture")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .scaleEffect(appear ? 1.0 : 0.7)
                    .opacity(appear ? 1.0 : 0)

                    Text(NSLocalizedString("BigmeCamera", comment: ""))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(appear ? 1.0 : 0)
                        .offset(y: appear ? 0 : 12)

                    Text(NSLocalizedString("Welcome Message", comment: "欢迎使用大我相机"))
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 48)
                        .opacity(appear ? 1.0 : 0)
                        .offset(y: appear ? 0 : 8)
                }

                Spacer()

                // 入口按钮
                Button {
                    showCamera = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(NSLocalizedString("Start Camera", comment: "开始拍照"))
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .liquidGlass(cornerRadius: 29)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 56)
                .opacity(appear ? 1.0 : 0)
                .offset(y: appear ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                appear = true
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            ContentView(viewModel: viewModel)
        }
    }
}
