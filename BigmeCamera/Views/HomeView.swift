import SwiftUI

struct HomeView: View {
    @State private var showCamera = false
    @StateObject private var viewModel = CameraViewModel()
    
    var body: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.3)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // 应用图标和标题
                VStack(spacing: 20) {
                    
                    Text(NSLocalizedString("BigmeCamera", comment: ""))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(NSLocalizedString("Welcome Message", comment: "欢迎使用大我相机"))
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // 进入相机按钮
                Button {
                    showCamera = true
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                        Text(NSLocalizedString("Start Camera", comment: "开始拍照"))
                            .font(.system(size: 20, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.white)
                    .cornerRadius(30)
                    .shadow(color: .white.opacity(0.3), radius: 20, x: 0, y: 10)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            ContentView(viewModel: viewModel)
        }
    }
}

