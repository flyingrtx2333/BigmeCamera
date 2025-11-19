import SwiftUI

struct SaveStatusBadge: View {
    let isSuccess: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.octagon.fill")
            Text(isSuccess ? NSLocalizedString("Saved", comment: "") : NSLocalizedString("Save Failed", comment: ""))
                .font(.caption)
                .bold()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSuccess ? Color.green.opacity(0.8) : Color.red.opacity(0.8),
                    in: Capsule(style: .continuous))
        .shadow(radius: 4)
    }
}

