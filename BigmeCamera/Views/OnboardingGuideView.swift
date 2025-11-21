import SwiftUI

struct OnboardingGuideView: View {
    @Binding var currentStep: Int
    @Binding var isCompleted: Bool
    let personCenter: CGPoint?
    let viewSize: CGSize
    let imageSize: CGSize
    let scale: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat
    
    // 步骤1：质心点提示
    @State private var showStep1 = false
    // 步骤2：缩放手势动画
    @State private var showStep2 = false
    @State private var pinchScale: CGFloat = 1.0
    // 步骤3：scale slider 提示
    @State private var showStep3 = false
    
    var body: some View {
        ZStack {
            // 半透明遮罩
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            // 步骤1：质心点提示
            if currentStep == 1, let center = personCenter {
                let uiKitY = imageSize.height - center.y
                let screenX = center.x * scale - offsetX
                let screenY = uiKitY * scale - offsetY
                
                ZStack {
                    // 气泡提示 - 定位在质心点附近
                    VStack(spacing: 8) {
                        Text(NSLocalizedString("Onboarding Step 1", comment: "点击拖动可以移动人像位置"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Button {
                            withAnimation {
                                currentStep = 2
                            }
                        } label: {
                            Text(NSLocalizedString("Next", comment: "下一步"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .frame(width: 220)
                    .position(x: min(max(110, screenX), viewSize.width - 110), 
                             y: max(150, screenY - 80))
                    
                    // 指向质心点的箭头线
                    Path { path in
                        let bubbleX = min(max(110, screenX), viewSize.width - 110)
                        let bubbleY = max(150, screenY - 80)
                        let arrowEndX = screenX
                        let arrowEndY = screenY
                        
                        path.move(to: CGPoint(x: bubbleX, y: bubbleY + 60))
                        path.addLine(to: CGPoint(x: arrowEndX, y: arrowEndY))
                    }
                    .stroke(Color.white, lineWidth: 2)
                }
                .opacity(showStep1 ? 1 : 0)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showStep1 = true
                    }
                }
            }
            
            // 步骤2：缩放手势动画提示
            if currentStep == 2 {
                VStack(spacing: 20) {
                    Spacer()
                        .frame(height: viewSize.height * 0.3)
                    
                    // 缩放手势动画
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 100, height: 100)
                            .scaleEffect(pinchScale)
                        
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .scaleEffect(pinchScale)
                    }
                    
                    Text(NSLocalizedString("Onboarding Step 2", comment: "缩放摄像机倍数"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    
                    Button {
                        withAnimation {
                            currentStep = 3
                        }
                    } label: {
                        Text(NSLocalizedString("Next", comment: "下一步"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(width: 200)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                    
                    Spacer()
                }
                .opacity(showStep2 ? 1 : 0)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showStep2 = true
                    }
                    // 开始缩放手势动画
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        pinchScale = 1.3
                    }
                }
            }
            
            // 步骤3：scale slider 提示
            if currentStep == 3 {
                VStack {
                    Spacer()
                        .frame(height: viewSize.height * 0.15) // 定位到高级控件区域
                    
                    HStack {
                        Spacer()
                            .frame(width: viewSize.width * 0.1)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(NSLocalizedString("Onboarding Step 3", comment: "拖动以调整缩放倍数"))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                            
                            Button {
                                withAnimation {
                                    isCompleted = true
                                    currentStep = 0
                                }
                            } label: {
                                Text(NSLocalizedString("Got It", comment: "知道了"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.white)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .frame(width: 220)
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
                .opacity(showStep3 ? 1 : 0)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showStep3 = true
                    }
                }
            }
        }
    }
}

