import SwiftUI

struct CameraPreviewView: View {
    let frame: CIImage?

    var body: some View {
        GeometryReader { proxy in
            if frame != nil {
                MetalCameraView(frame: frame)
                    .frame(width: proxy.size.width, height: proxy.size.height)
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
