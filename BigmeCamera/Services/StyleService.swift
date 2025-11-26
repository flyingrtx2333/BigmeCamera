import CoreML
import CoreImage
import CoreVideo
import UIKit
import Metal

/// 滤镜风格类型枚举
enum FilterStyle: String, CaseIterable, Identifiable {
    case none = "原图"
    case sketch = "手绘"
    // 预留更多风格
    // case watercolor = "水彩"
    // case oilPainting = "油画"
    // case cartoon = "卡通"
    // case anime = "动漫"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .none: return "photo"
        case .sketch: return "pencil.and.outline"
        // case .watercolor: return "drop.fill"
        // case .oilPainting: return "paintbrush.fill"
        // case .cartoon: return "face.smiling"
        // case .anime: return "sparkles"
        }
    }
    
    var displayName: String { rawValue }
    
    /// 模型文件名（不含扩展名）
    var modelName: String? {
        switch self {
        case .none: return nil
        case .sketch: return "CameraStyleTransfer 2"
        // 预留更多模型
        // case .watercolor: return "WatercolorStyle"
        // case .oilPainting: return "OilPaintingStyle"
        // case .cartoon: return "CartoonStyle"
        // case .anime: return "AnimeStyle"
        }
    }
}

/// 风格转换服务（性能优化版）
final class StyleService {
    
    // MARK: - 单例
    static let shared = StyleService()
    
    // MARK: - 属性
    
    /// 模型缓存
    private var modelCache: [FilterStyle: MLModel] = [:]
    
    /// 模型加载状态
    private var loadingStyles: Set<FilterStyle> = []
    
    /// Metal 设备（用于高性能渲染）
    private let metalDevice: MTLDevice?
    
    /// CIContext 用于图像转换（Metal 加速）
    private let ciContext: CIContext
    
    /// 模型输入尺寸
    private let modelInputSize = CGSize(width: 512, height: 512)
    
    // MARK: - 性能优化：缓存和跳帧
    
    /// 缓存的风格化结果
    private var cachedStyledImage: CIImage?
    private var cachedOriginalExtent: CGRect = .zero
    private var cachedStyle: FilterStyle = .none
    
    /// 帧计数器（用于跳帧）
    private var frameCounter: Int = 0
    
    /// 跳帧间隔（每 N 帧处理一次）
    private let frameSkipInterval: Int = 2
    
    /// 复用的输入 PixelBuffer
    private var reusableInputBuffer: CVPixelBuffer?
    
    /// PixelBuffer 池
    private var bufferPool: CVPixelBufferPool?
    
    /// 线程安全锁
    private let lock = NSLock()
    
    // MARK: - 初始化
    
    private init() {
        // 获取 Metal 设备
        metalDevice = MTLCreateSystemDefaultDevice()
        
        // 创建 Metal 加速的 CIContext
        if let device = metalDevice {
            ciContext = CIContext(mtlDevice: device, options: [
                .cacheIntermediates: false,  // 减少内存使用
                .priorityRequestLow: false,   // 高优先级
                .highQualityDownsample: false // 快速下采样
            ])
        } else {
            ciContext = CIContext(options: [
                .useSoftwareRenderer: false
            ])
        }
        
        // 初始化 PixelBuffer 池
        setupBufferPool()
        
        // 预加载常用模型
        preloadModel(for: .sketch)
    }
    
    // MARK: - 缓冲池设置
    
    private func setupBufferPool() {
        let poolAttrs: [CFString: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey: 2
        ]
        
        let bufferAttrs: [CFString: Any] = [
            kCVPixelBufferWidthKey: Int(modelInputSize.width),
            kCVPixelBufferHeightKey: Int(modelInputSize.height),
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]
        
        CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttrs as CFDictionary,
            bufferAttrs as CFDictionary,
            &bufferPool
        )
    }
    
    // MARK: - 公开方法
    
    /// 预加载指定风格的模型
    func preloadModel(for style: FilterStyle) {
        guard style != .none, modelCache[style] == nil, !loadingStyles.contains(style) else { return }
        
        loadingStyles.insert(style)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if let model = self.loadModel(for: style) {
                DispatchQueue.main.async {
                    self.modelCache[style] = model
                    self.loadingStyles.remove(style)
                    print("✅ 模型加载成功: \(style.displayName)")
                }
            } else {
                DispatchQueue.main.async {
                    self.loadingStyles.remove(style)
                    print("❌ 模型加载失败: \(style.displayName)")
                }
            }
        }
    }
    
    /// 检查模型是否已加载
    func isModelLoaded(for style: FilterStyle) -> Bool {
        return style == .none || modelCache[style] != nil
    }
    
    /// 检查模型是否正在加载
    func isModelLoading(for style: FilterStyle) -> Bool {
        return loadingStyles.contains(style)
    }
    
    /// 应用风格转换（带跳帧优化）
    /// - Parameters:
    ///   - image: 输入的 CIImage
    ///   - style: 目标风格
    /// - Returns: 风格化后的 CIImage，如果转换失败则返回原图
    func applyStyle(to image: CIImage, style: FilterStyle) -> CIImage {
        guard style != .none else {
            clearCache()
            return image
        }
        
        guard let model = modelCache[style] else {
            preloadModel(for: style)
            return image
        }
        
        lock.lock()
        defer { lock.unlock() }
        
        let originalExtent = image.extent
        
        // 检查是否可以使用缓存
        if let cached = cachedStyledImage,
           cachedStyle == style,
           cachedOriginalExtent.size == originalExtent.size {
            
            frameCounter += 1
            
            // 跳帧：不是每帧都进行风格转换
            if frameCounter % frameSkipInterval != 0 {
                // 使用缓存的结果，但需要调整位置
                return cached.transformed(by: CGAffineTransform(
                    translationX: originalExtent.origin.x - cachedOriginalExtent.origin.x,
                    y: originalExtent.origin.y - cachedOriginalExtent.origin.y
                ))
            }
        } else {
            // 风格或尺寸变化，重置计数器
            frameCounter = 0
        }
        
        // 执行风格转换
        guard let styledImage = performStyleTransfer(image: image, model: model) else {
            return image
        }
        
        // 更新缓存
        cachedStyledImage = styledImage
        cachedOriginalExtent = originalExtent
        cachedStyle = style
        
        return styledImage
    }
    
    /// 清除缓存
    func clearCache() {
        lock.lock()
        cachedStyledImage = nil
        cachedOriginalExtent = .zero
        cachedStyle = .none
        frameCounter = 0
        lock.unlock()
    }
    
    // MARK: - 私有方法
    
    /// 加载 ML 模型
    private func loadModel(for style: FilterStyle) -> MLModel? {
        guard let modelName = style.modelName else { return nil }
        
        // 配置模型使用 GPU（优先）和 Neural Engine
        let config = MLModelConfiguration()
        config.computeUnits = .all
        
        // 允许低精度计算以提升性能
        if #available(iOS 16.0, *) {
            config.setValue(true, forKey: "allowLowPrecisionAccumulationOnGPU")
        }
        
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            print("❌ 找不到模型文件: \(modelName).mlmodelc")
            return nil
        }
        
        do {
            let model = try MLModel(contentsOf: modelURL, configuration: config)
            return model
        } catch {
            print("❌ 模型加载错误: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 执行风格转换（优化版）
    private func performStyleTransfer(image: CIImage, model: MLModel) -> CIImage? {
        let originalExtent = image.extent
        
        // 1. 缩放到模型输入尺寸（使用更快的滤镜）
        let scaleX = modelInputSize.width / originalExtent.width
        let scaleY = modelInputSize.height / originalExtent.height
        
        // 使用 Lanczos 缩放（质量和速度的平衡）
        let scaledImage = image.applyingFilter("CILanczosScaleTransform", parameters: [
            kCIInputScaleKey: min(scaleX, scaleY),
            kCIInputAspectRatioKey: scaleX / scaleY
        ]).cropped(to: CGRect(origin: .zero, size: modelInputSize))
        
        // 2. 获取或创建输入 PixelBuffer
        guard let inputBuffer = getOrCreateInputBuffer(from: scaledImage) else {
            print("❌ 创建输入 PixelBuffer 失败")
            return nil
        }
        
        // 3. 执行模型预测
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "image": MLFeatureValue(pixelBuffer: inputBuffer)
            ])
            
            // 使用同步预测（在渲染线程上已经是后台）
            let output = try model.prediction(from: input)
            
            guard let outputBuffer = output.featureValue(for: "stylizedImage")?.imageBufferValue else {
                print("❌ 获取模型输出失败")
                return nil
            }
            
            // 4. 转换输出并缩放回原始尺寸
            var outputImage = CIImage(cvPixelBuffer: outputBuffer)
            
            // 使用快速缩放
            let restoreScaleX = originalExtent.width / modelInputSize.width
            let restoreScaleY = originalExtent.height / modelInputSize.height
            
            outputImage = outputImage.applyingFilter("CILanczosScaleTransform", parameters: [
                kCIInputScaleKey: max(restoreScaleX, restoreScaleY),
                kCIInputAspectRatioKey: restoreScaleX / restoreScaleY
            ]).cropped(to: CGRect(origin: originalExtent.origin, size: originalExtent.size))
            
            return outputImage
            
        } catch {
            print("❌ 模型预测错误: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 从缓冲池获取或创建输入 PixelBuffer
    private func getOrCreateInputBuffer(from image: CIImage) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        
        // 尝试从池中获取
        if let pool = bufferPool {
            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            if status == kCVReturnSuccess, let buffer = pixelBuffer {
                ciContext.render(image, to: buffer)
                return buffer
            }
        }
        
        // 回退：创建新的 buffer
        return createPixelBuffer(from: image)
    }
    
    /// 从 CIImage 创建 CVPixelBuffer（回退方法）
    private func createPixelBuffer(from image: CIImage) -> CVPixelBuffer? {
        let width = Int(modelInputSize.width)
        let height = Int(modelInputSize.height)
        
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        ciContext.render(image, to: buffer)
        return buffer
    }
}
