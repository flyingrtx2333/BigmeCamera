import SwiftUI

struct SaveStatusBadge: View {
    let isSuccess: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .font(.system(size: 13, weight: .semibold))
            Text(isSuccess ? NSLocalizedString("Saved", comment: "") : NSLocalizedString("Save Failed", comment: ""))
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(isSuccess ? Color.accentAmber.opacity(0.85) : Color.red.opacity(0.80))
                .shadow(color: (isSuccess ? Color.accentAmber : Color.red).opacity(0.45), radius: 8)
        )
    }
}
