import CoreImage
import MetalPetal
import Metal

struct BeautyConfig {
    var smoothness: CGFloat = 0.0
    var whitening: CGFloat = 0.0
    var sharpness: CGFloat = 0.0
    var isEnabled: Bool = false
}

final class BeautyService {
    private let mtiContext: MTIContext
    private let ciContext = CIContext(options: nil)

    init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let context = try? MTIContext(device: device) else {
            fatalError("无法创建 MTIContext")
        }
        self.mtiContext = context
    }

    // MARK: - 主处理入口
    func applyBeauty(to image: CIImage, config: BeautyConfig) -> CIImage {
        guard config.isEnabled else { return image }

        var ciImage = image

        // 1️⃣ 磨皮
        if config.smoothness > 0 {
            ciImage = applySmoothness(ciImage, intensity: config.smoothness)
        }

        // 2️⃣ 锐化
        if config.sharpness > 0 {
            ciImage = applySharpness(ciImage, intensity: config.sharpness)
        }

        // 3️⃣ 美白
        if config.whitening > 0 {
            ciImage = applyWhitening(ciImage, intensity: config.whitening)
        }

        return ciImage
    }

    // MARK: - 基于 CoreImage 的美颜组件（最稳定可靠）
    private func applySmoothness(_ image: CIImage, intensity: CGFloat) -> CIImage {
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(5.0 * intensity, forKey: kCIInputRadiusKey)
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }

    private func applySharpness(_ image: CIImage, intensity: CGFloat) -> CIImage {
        guard let filter = CIFilter(name: "CIUnsharpMask") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(2.0, forKey: kCIInputRadiusKey)
        filter.setValue(0.15 * intensity, forKey: kCIInputIntensityKey)
        return filter.outputImage ?? image
    }

    private func applyWhitening(_ image: CIImage, intensity: CGFloat) -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.05 * intensity, forKey: kCIInputBrightnessKey)
        filter.setValue(1.0 - 0.05 * intensity, forKey: kCIInputContrastKey)
        filter.setValue(1.05, forKey: kCIInputSaturationKey)
        return filter.outputImage ?? image
    }
}
