import SwiftUI

struct CameraPreviewView: View {
    let frame: CGImage?

    var body: some View {
        GeometryReader { proxy in
            if let frame {
                Image(decorative: frame, scale: 1.0, orientation: .up)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            } else {
                Color.black
                    .overlay {
                        VStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(.circular)
                            Text(NSLocalizedString("Preparing Camera", comment: ""))
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
            }
        }
        .ignoresSafeArea()
    }
}

