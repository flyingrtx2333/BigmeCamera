import CoreImage
import MetalKit
import SwiftUI
import UIKit

/// MTKView 直接渲染 CIImage，绕过 CGImage → SwiftUI Image 的 CPU 拷贝路径。
/// 每次 `frame` 更新时触发 `setNeedsDisplay()`，由 Metal 在 GPU 内完成
/// CIImage 滤镜链评估 → drawable texture，无 CPU 读回。
struct MetalCameraView: UIViewRepresentable {
    let frame: CIImage?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.device)
        view.isPaused = true            // 手动驱动，避免空转 60fps
        view.enableSetNeedsDisplay = true
        view.framebufferOnly = false    // 允许 CIContext 写入 drawable texture
        view.colorPixelFormat = .bgra8Unorm
        view.backgroundColor = .black
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.latestFrame = frame
        if frame != nil {
            uiView.setNeedsDisplay()
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MTKViewDelegate {
        let device: MTLDevice? = MTLCreateSystemDefaultDevice()

        private(set) lazy var commandQueue: MTLCommandQueue? = device?.makeCommandQueue()

        private(set) lazy var ciContext: CIContext = {
            if let d = device {
                return CIContext(mtlDevice: d, options: [
                    .cacheIntermediates: false,
                    .highQualityDownsample: false
                ])
            }
            return CIContext(options: [.useSoftwareRenderer: false])
        }()

        var latestFrame: CIImage?

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard
                let ciImage = latestFrame,
                let drawable = view.currentDrawable,
                let commandBuffer = commandQueue?.makeCommandBuffer()
            else { return }

            let drawableSize = view.drawableSize
            let viewBounds = CGRect(origin: .zero, size: drawableSize)

            // Scale-to-fill：保持宽高比，居中裁剪，与 SwiftUI .scaledToFill 行为一致
            let imageSize = ciImage.extent.size
            let scaleX = drawableSize.width / imageSize.width
            let scaleY = drawableSize.height / imageSize.height
            let scale = max(scaleX, scaleY)

            let scaledW = imageSize.width * scale
            let scaledH = imageSize.height * scale
            let tx = (drawableSize.width - scaledW) / 2.0
            let ty = (drawableSize.height - scaledH) / 2.0

            let transform = CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: tx / scale, y: ty / scale)
            let scaledImage = ciImage.transformed(by: transform)

            ciContext.render(
                scaledImage,
                to: drawable.texture,
                commandBuffer: commandBuffer,
                bounds: viewBounds,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
