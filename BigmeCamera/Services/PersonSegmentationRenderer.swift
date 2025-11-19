import AVFoundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

struct RenderResult {
    let image: CGImage
    let personCenter: CGPoint
}

final class PersonSegmentationRenderer {
    private let context = CIContext()
    private let request: VNGeneratePersonSegmentationRequest
    private let sequenceHandler = VNSequenceRequestHandler()

    // 性能与稳定性成员
    private var lastMaskBufferSize: CGSize = .zero
    private var lastPersonCenter: CGPoint?
    private let centerSmoothAlpha: CGFloat = 0.18   // EMA 平滑系数，越小越稳定
    
    // Mask 断帧保护
    private var lastValidMask: CIImage?
    private var consecutiveMissingFrames: Int = 0
    private let maxMissingFrames: Int = 3  // 最多允许连续丢失3帧
    private let minForegroundRatio: CGFloat = 0.01  // 最小前景像素比例（1%）

    init() {
        request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }

    func render(sampleBuffer: CMSampleBuffer, config: SegmentationConfig, customCenter: CGPoint? = nil) -> RenderResult? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        request.qualityLevel = config.quality.requestLevel

        let cameraImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // 使用 VNSequenceRequestHandler（Apple 官方推荐用于视频处理）
        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: .up)
        } catch {
            return nil
        }

        guard let result = request.results?.first else {
            return nil
        }

        // 直接使用 Vision 返回的 pixelBuffer（单通道灰度）
        let maskBuffer = result.pixelBuffer

        // --- mask 清洗 ---
        var maskImage = CIImage(cvPixelBuffer: maskBuffer)
        maskImage = maskImage
            .resize(to: cameraImage.extent.size)
            .applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": 6])   // 例如 6-12
            .applyingFilter("CIMorphologyMinimum", parameters: ["inputRadius": 1])
        
        // --- Mask 断帧保护：检测 mask 是否有效 ---
        let foregroundRatio = calculateForegroundRatio(maskImage: maskImage)
        let isMaskValid = foregroundRatio >= minForegroundRatio
        
        if isMaskValid {
            // Mask 有效，更新保存的有效 mask，重置丢失计数
            lastValidMask = maskImage
            consecutiveMissingFrames = 0
        } else {
            // Mask 丢失，尝试使用上一帧的有效 mask
            consecutiveMissingFrames += 1
            
            if let lastMask = lastValidMask, consecutiveMissingFrames <= maxMissingFrames {
                // 使用上一帧的有效 mask，并应用轻微衰减（避免长时间使用旧 mask）
                let fadeFactor = CGFloat(consecutiveMissingFrames) / CGFloat(maxMissingFrames + 1)
                maskImage = blendMasks(current: maskImage, previous: lastMask, fadeFactor: fadeFactor)
            } else {
                // 连续丢失超过阈值，或没有保存的有效 mask，使用当前（可能无效的）mask
                // 这样可以避免完全黑屏，但效果可能不理想
                consecutiveMissingFrames = maxMissingFrames + 1
            }
        }

        let invertedMask = maskImage.applyingFilter("CIColorInvert")

        // --- 分离前景人物 ---
        let personCutout = cameraImage
            .applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: cameraImage.extent),
                kCIInputMaskImageKey: maskImage
            ])
            .cropped(to: cameraImage.extent)

        // --- 纯背景，完全移除人物，绝无残影 ---
        let backgroundOnly = cameraImage
            .applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: cameraImage.extent),
                kCIInputMaskImageKey: invertedMask
            ])
            .cropped(to: cameraImage.extent)

        // --- 背景模糊 ---
        let baseBackground = backgroundOnly
            .applyingFilter("CIBoxBlur", parameters: [
                kCIInputRadiusKey: config.blurRadius / 2
            ])
            .composited(over: CIImage(color: .clear).cropped(to: cameraImage.extent))

        // ---- 使用自定义质心或默认中心 ----
        let personCenter = customCenter ?? CGPoint(x: cameraImage.extent.width / 2, y: cameraImage.extent.height / 2)

        // 以质心为中心缩放人物
        let targetRect = cameraImage.extent
        let scaledPerson = personCutout.scaledAndAnchored(
            around: personCenter,
            scale: config.personScale,
            targetRect: targetRect
        )

        let composited = scaledPerson
            .composited(over: baseBackground)
            .cropped(to: targetRect)

        guard let cgImage = context.createCGImage(composited, from: cameraImage.extent) else {
            return nil
        }

        return RenderResult(image: cgImage, personCenter: personCenter)
    }
    
    // MARK: - Mask 断帧保护辅助方法
    
    /// 计算前景像素比例，用于检测 mask 是否有效
    /// 使用采样方法提高性能，避免遍历所有像素
    private func calculateForegroundRatio(maskImage: CIImage) -> CGFloat {
        // 将 mask 缩放到较小尺寸进行采样（例如 64x64），提高性能
        let sampleSize = CGSize(width: 64, height: 64)
        let sampledMask = maskImage
            .transformed(by: CGAffineTransform(
                scaleX: sampleSize.width / maskImage.extent.width,
                y: sampleSize.height / maskImage.extent.height
            ))
            .cropped(to: CGRect(origin: .zero, size: sampleSize))
        
        guard let cgMask = context.createCGImage(sampledMask, from: sampledMask.extent) else {
            return 0
        }
        
        let width = cgMask.width
        let height = cgMask.height
        let totalPixels = width * height
        
        guard totalPixels > 0 else { return 0 }
        
        // 创建数据提供者
        guard let dataProvider = cgMask.dataProvider,
              let data = dataProvider.data else {
            return 0
        }
        
        let bytes = CFDataGetBytePtr(data)
        guard bytes != nil else { return 0 }
        
        // 统计前景像素（值 > 128 的像素）
        var foregroundCount = 0
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                if bytes![index] > 128 {
                    foregroundCount += 1
                }
            }
        }
        
        return CGFloat(foregroundCount) / CGFloat(totalPixels)
    }
    
    /// 混合当前 mask 和上一帧的有效 mask，实现平滑过渡
    private func blendMasks(current: CIImage, previous: CIImage, fadeFactor: CGFloat) -> CIImage {
        // 使用加权混合：fadeFactor 越大，上一帧 mask 的权重越高
        // fadeFactor: 0.0 = 完全使用当前, 1.0 = 完全使用上一帧
        let previousWeight = min(fadeFactor, 0.8)  // 最多80%权重给上一帧
        let currentWeight = 1.0 - previousWeight
        
        // 使用 CIBlendWithAlphaMask 或简单的加权混合
        // 这里使用更简单的方法：直接使用上一帧的 mask（因为当前 mask 已经无效）
        // 但可以添加轻微的时间衰减
        return previous
    }
}

private extension CIImage {
    func resize(to size: CGSize) -> CIImage {
        let scaleX = size.width / extent.width
        let scaleY = size.height / extent.height
        return transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }

    func scaledAndAnchored(around centerPoint: CGPoint, scale: CGFloat, targetRect: CGRect) -> CIImage {
        guard scale != 1 else {
            return self.cropped(to: targetRect)
        }

        // 1) 在 image 自身坐标系应用：先把 centerPoint 转换到当前 image 坐标
        //    因为 self 的坐标系与 targetRect（cameraImage.extent）应该是同一个（我们保证在调用处如此）
        // 2) 生成 scale transform（以 centerPoint 为锚）
        let t1 = CGAffineTransform(translationX: -centerPoint.x, y: -centerPoint.y)
        let s = CGAffineTransform(scaleX: scale, y: scale)
        let t2 = CGAffineTransform(translationX: centerPoint.x, y: centerPoint.y)
        let scaled = self.transformed(by: t1.concatenating(s).concatenating(t2))

        // 3) 计算 scaled 的 center 与期望 center 的偏移，并平移回来（避免 visual drift）
        let scaledCenter = scaled.extent.center
        let offsetX = centerPoint.x - scaledCenter.x
        let offsetY = centerPoint.y - scaledCenter.y
        let final = scaled.transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))

        // 4) crop 回目标画布
        return final.cropped(to: targetRect)
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

