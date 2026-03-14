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

    @State private var showStep1 = false
    @State private var showStep2 = false
    @State private var pinchScale: CGFloat = 1.0
    @State private var showStep3 = false

    var body: some View {
        ZStack {
            // 半透明遮罩
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            // 步骤1：质心点提示
            if currentStep == 1, let center = personCenter {
                let uiKitY = imageSize.height - center.y
                let screenX = center.x * scale - offsetX
                let screenY = uiKitY * scale - offsetY

                ZStack {
                    stepBubble(
                        step: 1,
                        message: NSLocalizedString("Onboarding Step 1", comment: "点击拖动可以移动人像位置"),
                        buttonLabel: NSLocalizedString("Next", comment: "下一步"),
                        action: { withAnimation { currentStep = 2 } }
                    )
                    .position(
                        x: min(max(120, screenX), viewSize.width - 120),
                        y: max(160, screenY - 90)
                    )

                    // 指向线
                    Path { path in
                        let bubbleX = min(max(120, screenX), viewSize.width - 120)
                        let bubbleY = max(160, screenY - 90)
                        path.move(to: CGPoint(x: bubbleX, y: bubbleY + 64))
                        path.addLine(to: CGPoint(x: screenX, y: screenY))
                    }
                    .stroke(
                        LinearGradient(
                            colors: [Color.accentAmber.opacity(0.80), Color.accentAmber.opacity(0.20)],
                            startPoint: .init(x: 0, y: 0),
                            endPoint: .init(x: 0, y: 1)
                        ),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                    )

                    // 目标点光晕
                    Circle()
                        .stroke(Color.accentAmber.opacity(0.55), lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                        .position(x: screenX, y: screenY)
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
                VStack(spacing: 24) {
                    Spacer().frame(height: viewSize.height * 0.28)

                    ZStack {
                        Circle()
                            .stroke(Color.accentAmber.opacity(0.35), lineWidth: 1)
                            .frame(width: 110, height: 110)
                            .scaleEffect(pinchScale * 1.1)

                        Circle()
                            .stroke(Color.white.opacity(0.70), lineWidth: 2)
                            .frame(width: 90, height: 90)
                            .scaleEffect(pinchScale)

                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color.accentAmber.opacity(0.85)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .scaleEffect(pinchScale)
                    }

                    stepBubble(
                        step: 2,
                        message: NSLocalizedString("Onboarding Step 2", comment: "缩放摄像机倍数"),
                        buttonLabel: NSLocalizedString("Next", comment: "下一步"),
                        action: { withAnimation { currentStep = 3 } }
                    )

                    Spacer()
                }
                .opacity(showStep2 ? 1 : 0)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showStep2 = true
                    }
                    withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                        pinchScale = 1.28
                    }
                }
            }

            // 步骤3：scale slider 提示
            if currentStep == 3 {
                VStack {
                    Spacer().frame(height: viewSize.height * 0.14)

                    HStack {
                        Spacer().frame(width: viewSize.width * 0.08)

                        stepBubble(
                            step: 3,
                            message: NSLocalizedString("Onboarding Step 3", comment: "拖动以调整缩放倍数"),
                            buttonLabel: NSLocalizedString("Got It", comment: "知道了"),
                            isDone: true,
                            action: {
                                withAnimation {
                                    isCompleted = true
                                    currentStep = 0
                                }
                            }
                        )
                        .frame(width: 228)

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

    // MARK: - 步骤气泡

    private func stepBubble(
        step: Int,
        message: String,
        buttonLabel: String,
        isDone: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                // 步骤编号徽章
                ZStack {
                    Circle()
                        .fill(Color.accentAmber)
                        .frame(width: 22, height: 22)
                    Text("\(step)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                }

                Text("步骤 \(step) / 3")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.accentAmber.opacity(0.80))
                    .tracking(0.5)

                Spacer()
            }

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                HStack(spacing: 6) {
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                    }
                    Text(buttonLabel)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentAmber)
                        .shadow(color: Color.accentAmber.opacity(0.40), radius: 8)
                )
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.accentAmber.opacity(0.45), Color.white.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                }
                .shadow(color: .black.opacity(0.40), radius: 24, y: 10)
        }
    }
}
