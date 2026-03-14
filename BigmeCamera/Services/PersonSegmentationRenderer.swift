import AVFoundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Metal
import Vision
import UIKit

struct RenderResult {
    let image: CGImage
    let personCenter: CGPoint
}

final class PersonSegmentationRenderer {
    // Metal 加速的 CIContext，与 StyleService 保持一致
    private let context: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device, options: [
                .cacheIntermediates: false,
                .highQualityDownsample: false
            ])
        }
        return CIContext(options: [.useSoftwareRenderer: false])
    }()
    private let request: VNGeneratePersonSegmentationRequest
    private let sequenceHandler = VNSequenceRequestHandler()

    // 性能与稳定性成员
    private var lastMaskBufferSize: CGSize = .zero
    private var lastPersonCenter: CGPoint?
    private let centerSmoothAlpha: CGFloat = 0.18   // EMA 平滑系数，越小越稳定
    
    // Mask 断帧保护
    private var lastValidMask: CIImage?
    private var consecutiveMissingFrames: Int = 0
    private let maxMissingFrames: Int = 8  // 最多允许连续丢失3帧
    private let minForegroundRatio: CGFloat = 0.01  // 最小前景像素比例（1%）
    
    // 性能优化：每 10 帧做一次 mask 健康检查
    private var frameCount: Int = 0
    private var lastMaskValidState: Bool = true

    init() {
        request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }

    // 贴纸图像缓存
    private var stickerImageCache: [StickerType: CIImage] = [:]
    
    // 滤镜服务引用
    private let styleService = StyleService.shared
    
    // 分身快照缓存：存储每个冻结分身的 personCutout 图像
    private var frozenCloneSnapshots: [UUID: CIImage] = [:]
    
    func render(sampleBuffer: CMSampleBuffer, config: SegmentationConfig, customCenter: CGPoint? = nil, clones: [CloneInstance] = [], stickers: [StickerInstance] = [], filterStyle: FilterStyle = .none) -> RenderResult? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        request.qualityLevel = config.quality.requestLevel

        let cameraImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // 使用 VNSequenceRequestHandler（Apple 官方推荐用于视频处理）
        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: .up)
        } catch {
            #if DEBUG
            print("⚠️ Segmentation error: \(error)")
            #endif
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
        
        // --- Mask 断帧保护：每 10 帧做一次健康检查 ---
        frameCount += 1
        let shouldCheckHealth = (frameCount % 10 == 0)
        
        var isMaskValid = lastMaskValidState  // 默认使用上次检查的结果
        
        if shouldCheckHealth {
            // 每 10 帧执行一次完整的健康检查
            let foregroundRatio = calculateForegroundRatio(maskImage: maskImage)
            isMaskValid = foregroundRatio >= minForegroundRatio
            lastMaskValidState = isMaskValid
        }
        
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


        // --- 软化 invertedMask ---
        // 缩小
        let smallMask = invertedMask.applyingFilter("CILanczosScaleTransform", parameters: [
            kCIInputScaleKey: 0.25
        ])

        // 模糊
        let blurredSmallMask = smallMask.applyingFilter("CIGaussianBlur", parameters:[
            kCIInputRadiusKey: 4
        ])

        // 放回
        let softInvertedMask = blurredSmallMask
            .applyingFilter("CILanczosScaleTransform", parameters: [
                kCIInputScaleKey: 4.0
            ])
            .cropped(to: cameraImage.extent)

        // --- 分离前景人物 ---
        let personCutout = cameraImage
            .applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: cameraImage.extent),
                kCIInputMaskImageKey: maskImage
            ])
            .cropped(to: cameraImage.extent)

        // --- 纯背景，完全移除人物，绝无残影 ---
        // let backgroundOnly = cameraImage
        //     .applyingFilter("CIBlendWithMask", parameters: [
        //         kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: cameraImage.extent),
        //         kCIInputMaskImageKey: invertedMask
        //     ])
        //     .cropped(to: cameraImage.extent)

        // --- 整张图生成超模糊版本（仅在有分身或贴纸时才需要，用于填补人物区域） ---
        let needsUltraBlur = !clones.isEmpty || !stickers.isEmpty
        let ultraBlurred: CIImage
        if needsUltraBlur {
            ultraBlurred = cameraImage
                .applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: 0.25])
                .applyingFilter("CIBoxBlur", parameters: [kCIInputRadiusKey: 10])
                .applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: 4.0])
                .cropped(to: cameraImage.extent)
        } else {
            ultraBlurred = cameraImage
        }


        // --- 使用 invertedMask 把超模糊图贴到“人物区域” ---
        let backgroundOnly = cameraImage
            .applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: ultraBlurred,
                kCIInputMaskImageKey: softInvertedMask   // 人物区域 = 1 → 使用 ultraBlurred
            ])
            .cropped(to: cameraImage.extent)

        // --- 背景模糊 ---
        let baseBackground = backgroundOnly
            // .applyingFilter("CIBoxBlur", parameters: [
            //     kCIInputRadiusKey: config.blurRadius / 2
            // ])
            // .composited(over: CIImage(color: .clear).cropped(to: cameraImage.extent))

        // ---- 使用自定义质心或默认中心 ----
        let personCenter = customCenter ?? CGPoint(x: cameraImage.extent.width / 2, y: cameraImage.extent.height / 2)

        // 以质心为中心缩放人物
        let targetRect = cameraImage.extent
        let scaledPerson = personCutout.scaledAndAnchored(
            around: personCenter,
            scale: config.personScale,
            targetRect: targetRect
        )

        // --- 先合成背景和主人物 ---
        var composited = scaledPerson
            .composited(over: baseBackground)
            .cropped(to: targetRect)
        
        // --- 渲染分身（叠加在主人物之上） ---
        for clone in clones {
            let cloneImage: CIImage
            
            if clone.isFrozen {
                // 分身已冻结，使用快照图像
                if let snapshot = frozenCloneSnapshots[clone.id] {
                    cloneImage = snapshot
                } else {
                    // 首次冻结，保存当前 personCutout 作为快照
                    frozenCloneSnapshots[clone.id] = personCutout
                    cloneImage = personCutout
                }
            } else {
                // 分身未冻结，使用实时人物图像
                // 同时清除可能存在的旧快照
                frozenCloneSnapshots.removeValue(forKey: clone.id)
                cloneImage = personCutout
            }
            
            let clonePerson = cloneImage.scaledAndAnchored(
                around: clone.center,
                scale: clone.scale,
                targetRect: targetRect
            )
            composited = clonePerson
                .composited(over: composited)
                .cropped(to: targetRect)
        }
        
        // 清理已删除分身的快照缓存（用 Set 避免每帧 O(n²) filter）
        let currentCloneIds = Set(clones.map { $0.id })
        for key in frozenCloneSnapshots.keys where !currentCloneIds.contains(key) {
            frozenCloneSnapshots.removeValue(forKey: key)
        }
        
        // --- 渲染贴纸（叠加在最上层，跳过离屏贴纸） ---
        for sticker in stickers {
            if let stickerImage = getStickerImage(for: sticker.type) {
                // 计算目标贴纸大小
                let targetSize: CGFloat = 120 * sticker.scale
                let originalSize = max(stickerImage.extent.width, stickerImage.extent.height)
                let stickerScale = targetSize / originalSize

                let originalCenter = CGPoint(x: stickerImage.extent.midX, y: stickerImage.extent.midY)
                let toOrigin = CGAffineTransform(translationX: -originalCenter.x, y: -originalCenter.y)
                let scale = CGAffineTransform(scaleX: stickerScale, y: stickerScale)
                let rotate = CGAffineTransform(rotationAngle: sticker.rotation)
                let toTarget = CGAffineTransform(translationX: sticker.center.x, y: sticker.center.y)
                let finalTransform = toOrigin.concatenating(scale).concatenating(rotate).concatenating(toTarget)

                let positionedSticker = stickerImage.transformed(by: finalTransform)

                // 离屏剔除：贴纸完全在画面外则跳过合成
                guard positionedSticker.extent.intersects(targetRect) else { continue }

                composited = positionedSticker
                    .composited(over: composited)
                    .cropped(to: targetRect)
            }
        }
        
        // --- 应用滤镜风格转换 ---
        if filterStyle != .none {
            composited = styleService.applyStyle(to: composited, style: filterStyle)
                .cropped(to: targetRect)
        }

        guard let cgImage = context.createCGImage(composited, from: cameraImage.extent) else {
            return nil
        }

        return RenderResult(image: cgImage, personCenter: personCenter)
    }
    
    // MARK: - 贴纸渲染辅助方法
    
    /// 获取贴纸图像（带缓存）
    private func getStickerImage(for type: StickerType) -> CIImage? {
        // 检查缓存
        if let cached = stickerImageCache[type] {
            return cached
        }
        
        // 使用 SF Symbols 生成贴纸图像
        let config = UIImage.SymbolConfiguration(pointSize: 100, weight: .bold)
        guard let symbolImage = UIImage(systemName: type.rawValue, withConfiguration: config) else {
            return nil
        }
        
        // 获取贴纸颜色
        let color = type.color
        let tintColor = UIColor(red: color.r, green: color.g, blue: color.b, alpha: 1.0)
        
        // 使用 UIGraphicsImageRenderer 正确渲染带透明背景的贴纸
        let imageSize = CGSize(width: 120, height: 120)
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        
        let renderedImage = renderer.image { ctx in
            // 计算居中位置
            let symbolSize = symbolImage.size
            let x = (imageSize.width - symbolSize.width) / 2
            let y = (imageSize.height - symbolSize.height) / 2
            
            // 设置着色
            tintColor.set()
            
            // 绘制 symbol
            symbolImage.withTintColor(tintColor, renderingMode: .alwaysTemplate)
                .draw(at: CGPoint(x: x, y: y))
        }
        
        guard let cgImage = renderedImage.cgImage else {
            return nil
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        stickerImageCache[type] = ciImage
        return ciImage
    }
    
    // MARK: - Mask 断帧保护辅助方法
    
    /// 计算前景像素比例，用于检测 mask 是否有效
    /// 【优化】使用 CIAreaAverage 在 GPU 上直接计算平均亮度，避免 CPU 遍历像素
    private func calculateForegroundRatio(maskImage: CIImage) -> CGFloat {
        // 使用 CIAreaAverage 滤镜在 GPU 上计算整个 mask 的平均亮度
        // 这比创建 CGImage 并遍历像素快得多
        let averageFilter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: maskImage,
            kCIInputExtentKey: CIVector(cgRect: maskImage.extent)
        ])
        
        guard let outputImage = averageFilter?.outputImage else {
            return 0
        }
        
        // 渲染 1x1 像素结果
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(outputImage,
                      toBitmap: &pixel,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: CGColorSpaceCreateDeviceRGB())
        
        // 返回平均亮度作为前景比例的近似值
        // 对于单通道 mask，R/G/B 值相同，取第一个即可
        return CGFloat(pixel[0]) / 255.0
    }
    
    /// 混合当前 mask 和上一帧的有效 mask，实现平滑过渡
    /// 【优化】真正实现 mask 混合，使用 CIMix 滤镜在 GPU 上完成
    private func blendMasks(current: CIImage, previous: CIImage, fadeFactor: CGFloat) -> CIImage {
        // fadeFactor: 0.0 = 完全使用当前, 1.0 = 完全使用上一帧
        let previousWeight = min(fadeFactor, 0.8)  // 最多80%权重给上一帧
        
        // 确保两个 mask 尺寸一致
        let resizedPrevious = previous.resize(to: current.extent.size)
        
        // 使用 CIMix 滤镜进行加权混合（GPU 加速）
        let blended = current.applyingFilter("CIMix", parameters: [
            kCIInputBackgroundImageKey: resizedPrevious,
            kCIInputAmountKey: previousWeight
        ])
        
        return blended.cropped(to: current.extent)
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

