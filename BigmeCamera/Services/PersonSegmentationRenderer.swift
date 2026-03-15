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
    // Vision 节流：每 visionInterval 帧才跑一次推理，其余帧复用上次 mask
    private var visionFrameCount = 0
    private let visionInterval = 3
    private var lastMaskPixelBuffer: CVPixelBuffer?  // 持有强引用，防止 Vision 提前释放

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

        // --- Vision 节流 ---
        // 每 visionInterval 帧才跑一次推理；其余帧复用 lastMaskPixelBuffer。
        // CVPixelBuffer 强引用保证 Vision 下次运行前数据不会被释放。
        visionFrameCount += 1
        let shouldRunVision = lastMaskPixelBuffer == nil || (visionFrameCount % visionInterval == 0)

        if shouldRunVision {
            do {
                try sequenceHandler.perform([request], on: pixelBuffer, orientation: .up)
            } catch {
                #if DEBUG
                print("⚠️ Segmentation error: \(error)")
                #endif
                return nil
            }
            // 有结果则更新，无结果（画面中无人）则继续沿用上一帧 mask
            if let result = request.results?.first {
                lastMaskPixelBuffer = result.pixelBuffer
            }
        }

        guard let maskBuffer = lastMaskPixelBuffer else { return nil }

        // --- mask 清洗（先在 Vision 小尺寸上做 Morphology，再 resize，减少运算量）---
        let maskCIImage = CIImage(cvPixelBuffer: maskBuffer)
        let maskImage = maskCIImage
            .applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": 1])
            .resize(to: cameraImage.extent.size)

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

        // --- 液态玻璃背景填充（始终启用，消除人物原始位置残影）---
        //
        // 原理：下采样到 1/16 再模糊，像素级别的人物轮廓被彻底抹除，
        // 只剩场景环境色调；叠加半透明冷白光层形成液态玻璃质感；
        // 最后用软化后的人物 mask 将玻璃填充混合进背景。
        //
        // 步骤 1：极度模糊 → 彻底消除人物轮廓，保留环境色调
        let ambientFill = cameraImage
            .applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: 0.0625]) // 1/16
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 6])
            .applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: 16.0])
            .cropped(to: cameraImage.extent)

        // 步骤 2：叠加冷白玻璃光（alpha 0.22，营造液态玻璃质感）
        let glassTint = CIImage(color: CIColor(red: 0.93, green: 0.96, blue: 1.0, alpha: 0.22))
            .cropped(to: cameraImage.extent)
        let liquidGlassFill = glassTint.composited(over: ambientFill)

        // 步骤 3：softPersonMask（人物≈1，背景≈0）= softInvertedMask 取反
        // 用它把液态玻璃填充混入人物区域，背景保持原始画面
        let softPersonMask = softInvertedMask.applyingFilter("CIColorInvert")
        let backgroundOnly = liquidGlassFill
            .applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: cameraImage,
                kCIInputMaskImageKey: softPersonMask   // 1=人物区域→玻璃填充，0=背景→原始画面
            ])
            .cropped(to: cameraImage.extent)

        // --- 背景确定，后续直接使用 backgroundOnly ---
        let baseBackground = backgroundOnly

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

