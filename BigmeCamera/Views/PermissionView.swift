import SwiftUI

struct PermissionView: View {
    let requestAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
                .foregroundStyle(.white)
                .padding(16)
                .background(.thinMaterial, in: Circle())

            Text(NSLocalizedString("Camera Permission Required", comment: ""))
                .font(.title2)
                .bold()
                .foregroundStyle(.white)

            Text(NSLocalizedString("Camera Permission Description", comment: ""))
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.7))

            Button(action: requestAction) {
                Text(NSLocalizedString("Grant Camera Access", comment: ""))
                    .bold()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

