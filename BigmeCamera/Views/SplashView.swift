import SwiftUI

struct SplashView: View {
    @State private var isActive = false
    @State private var opacity = 0.0
    @State private var scale = 0.8
    
    var body: some View {
        ZStack {
            // 背景色
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Logo 或应用图标
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .scaleEffect(scale)
                    .opacity(opacity)
                
                // 应用名称
                Text(NSLocalizedString("BigmeCamera", comment: ""))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(opacity)
            }
        }
        .onAppear {
            // 启动动画
            withAnimation(.easeOut(duration: 1.0)) {
                opacity = 1.0
                scale = 1.0
            }
            
            // 2秒后跳转到主页面
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeIn(duration: 0.3)) {
                    isActive = true
                }
            }
        }
        .fullScreenCover(isPresented: $isActive) {
            HomeView()
        }
    }
}

