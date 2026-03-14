import SwiftUI

struct PermissionView: View {
    let requestAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentAmber.opacity(0.15))
                    .frame(width: 80, height: 80)
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
                Image(systemName: "camera.fill")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color.accentAmber.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            Text(NSLocalizedString("Camera Permission Required", comment: ""))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text(NSLocalizedString("Camera Permission Description", comment: ""))
                .multilineTextAlignment(.center)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.65))

            Button(action: requestAction) {
                Text(NSLocalizedString("Grant Camera Access", comment: ""))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentAmber)
                            .shadow(color: Color.accentAmber.opacity(0.40), radius: 10)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .liquidGlass(cornerRadius: 24, accentTint: true)
    }
}
