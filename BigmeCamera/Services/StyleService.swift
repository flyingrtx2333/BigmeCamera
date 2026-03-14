import CoreML
import CoreImage
import CoreVideo
import UIKit
import Metal

/// 模型配置结构体
struct ModelConfig {
    let modelName: String           // 模型文件名（不含扩展名）
    let inputSize: CGSize           // 输入尺寸
    let inputName: String           // 输入层名称
    let outputName: String          // 输出层名称
    
    /// 默认配置（512x512，标准输入输出名称）
    static func standard(modelName: String) -> ModelConfig {
        return ModelConfig(
            modelName: modelName,
            inputSize: CGSize(width: 512, height: 512),
            inputName: "image",
            outputName: "stylizedImage"
        )
    }
}

/// 滤镜风格类型枚举
enum FilterStyle: String, CaseIterable, Identifiable {
    case none = "原图"
    case sketch = "手绘"
    case sketch2 = "手绘2"
    case cartoon = "漫画"
    // 预留更多风格
    // case watercolor = "水彩"
    // case oilPainting = "油画"
    // case anime = "动漫"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .none: return "photo"
        case .sketch: return "pencil.and.outline"
        case .sketch2: return "pencil.tip"
        case .cartoon: return "book.pages"
        // case .watercolor: return "drop.fill"
        // case .oilPainting: return "paintbrush.fill"
        // case .anime: return "sparkles"
        }
    }
    
    var displayName: String { rawValue }
    
    /// 模型配置
    var modelConfig: ModelConfig? {
        switch self {
        case .none: return nil
        case .sketch: return .standard(modelName: "CameraStyleTransfer 2")
        case .sketch2: return .standard(modelName: "CameraStyleTransferXianGao2")
        case .cartoon: return ModelConfig(
            modelName: "whiteboxcartoonization",
            inputSize: CGSize(width: 1536, height: 1536),
            inputName: "Placeholder",
            outputName: "activation_out"
        )
        // 预留更多模型
        // case .watercolor: return .standard(modelName: "WatercolorStyle")
        // case .oilPainting: return .standard(modelName: "OilPaintingStyle")
        // case .anime: return .standard(modelName: "AnimeStyle")
        }
    }
    
    /// 模型文件名（不含扩展名）- 保留兼容性
    var modelName: String? {
        return modelConfig?.modelName
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
    
    /// 默认模型输入尺寸（用于缓冲池）
    private let defaultModelInputSize = CGSize(width: 512, height: 512)
    
    /// 不同尺寸的 PixelBuffer 池
    private var bufferPools: [CGSize: CVPixelBufferPool] = [:]
    
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
    
    
    /// 缓存锁（保护 cachedStyledImage / frameCounter 等渲染缓存）
    private let lock = NSLock()
    /// 模型字典锁（modelCache 从 renderQueue 读、从 main 写，需独立保护）
    private let modelLock = NSLock()
    
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
        // 为默认尺寸创建缓冲池
        _ = getOrCreateBufferPool(for: defaultModelInputSize)
    }
    
    /// 获取或创建指定尺寸的缓冲池
    private func getOrCreateBufferPool(for size: CGSize) -> CVPixelBufferPool? {
        // 检查是否已存在
        if let pool = bufferPools[size] {
            return pool
        }
        
        // 创建新的缓冲池
        let poolAttrs: [CFString: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey: 2
        ]
        
        let bufferAttrs: [CFString: Any] = [
            kCVPixelBufferWidthKey: Int(size.width),
            kCVPixelBufferHeightKey: Int(size.height),
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]
        
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttrs as CFDictionary,
            bufferAttrs as CFDictionary,
            &pool
        )
        
        if let pool = pool {
            bufferPools[size] = pool
        }
        
        return pool
    }
    
    // MARK: - 公开方法
    
    /// 预加载指定风格的模型
    func preloadModel(for style: FilterStyle) {
        modelLock.lock()
        let alreadyLoaded = modelCache[style] != nil
        let alreadyLoading = loadingStyles.contains(style)
        modelLock.unlock()

        guard style != .none, !alreadyLoaded, !alreadyLoading else { return }

        modelLock.lock()
        loadingStyles.insert(style)
        modelLock.unlock()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            if let model = self.loadModel(for: style) {
                self.modelLock.lock()
                self.modelCache[style] = model
                self.loadingStyles.remove(style)
                self.modelLock.unlock()
                print("✅ 模型加载成功: \(style.displayName)")
            } else {
                self.modelLock.lock()
                self.loadingStyles.remove(style)
                self.modelLock.unlock()
                print("❌ 模型加载失败: \(style.displayName)")
            }
        }
    }

    /// 检查模型是否已加载
    func isModelLoaded(for style: FilterStyle) -> Bool {
        modelLock.lock()
        defer { modelLock.unlock() }
        return style == .none || modelCache[style] != nil
    }
    
    /// 检查模型是否正在加载
    func isModelLoading(for style: FilterStyle) -> Bool {
        modelLock.lock()
        defer { modelLock.unlock() }
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

        modelLock.lock()
        let model = modelCache[style]
        modelLock.unlock()

        guard let model else {
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
        guard let styledImage = performStyleTransfer(image: image, model: model, style: style) else {
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
        
        // 允许低精度计算以提升性能（私有 KVC key，iOS 16+ 有效，未来版本可能失效）
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
    private func performStyleTransfer(image: CIImage, model: MLModel, style: FilterStyle) -> CIImage? {
        guard let config = style.modelConfig else { return nil }
        
        let originalExtent = image.extent
        let inputSize = config.inputSize
        
        // 1. 缩放到模型输入尺寸（使用更快的滤镜）
        let scaleX = inputSize.width / originalExtent.width
        let scaleY = inputSize.height / originalExtent.height
        
        // 使用 Lanczos 缩放（质量和速度的平衡）
        let scaledImage = image.applyingFilter("CILanczosScaleTransform", parameters: [
            kCIInputScaleKey: min(scaleX, scaleY),
            kCIInputAspectRatioKey: scaleX / scaleY
        ]).cropped(to: CGRect(origin: .zero, size: inputSize))
        
        // 2. 获取或创建输入 PixelBuffer
        guard let inputBuffer = getOrCreateInputBuffer(from: scaledImage, size: inputSize) else {
            print("❌ 创建输入 PixelBuffer 失败")
            return nil
        }
        
        // 3. 执行模型预测
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: [
                config.inputName: MLFeatureValue(pixelBuffer: inputBuffer)
            ])
            
            // 使用同步预测（在渲染线程上已经是后台）
            let output = try model.prediction(from: input)
            
            guard let outputBuffer = output.featureValue(for: config.outputName)?.imageBufferValue else {
                print("❌ 获取模型输出失败，输出名称: \(config.outputName)")
                return nil
            }
            
            // 4. 转换输出并缩放回原始尺寸
            var outputImage = CIImage(cvPixelBuffer: outputBuffer)
            
            // 使用快速缩放
            let restoreScaleX = originalExtent.width / inputSize.width
            let restoreScaleY = originalExtent.height / inputSize.height
            
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
    private func getOrCreateInputBuffer(from image: CIImage, size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        
        // 尝试从池中获取
        if let pool = getOrCreateBufferPool(for: size) {
            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            if status == kCVReturnSuccess, let buffer = pixelBuffer {
                ciContext.render(image, to: buffer)
                return buffer
            }
        }
        
        // 回退：创建新的 buffer
        return createPixelBuffer(from: image, size: size)
    }
    
    /// 从 CIImage 创建 CVPixelBuffer（回退方法）
    private func createPixelBuffer(from image: CIImage, size: CGSize) -> CVPixelBuffer? {
        let width = Int(size.width)
        let height = Int(size.height)
        
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
