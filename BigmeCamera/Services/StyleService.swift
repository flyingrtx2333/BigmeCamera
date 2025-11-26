import CoreML
import CoreImage
import CoreVideo
import UIKit

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

/// 风格转换服务
final class StyleService {
    
    // MARK: - 单例
    static let shared = StyleService()
    
    // MARK: - 属性
    
    /// 模型缓存
    private var modelCache: [FilterStyle: MLModel] = [:]
    
    /// 模型加载状态
    private var loadingStyles: Set<FilterStyle> = []
    
    /// CIContext 用于图像转换
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    /// 模型输入尺寸
    private let modelInputSize = CGSize(width: 512, height: 512)
    
    // MARK: - 初始化
    
    private init() {
        // 预加载常用模型
        preloadModel(for: .sketch)
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
    
    /// 应用风格转换
    /// - Parameters:
    ///   - image: 输入的 CIImage
    ///   - style: 目标风格
    /// - Returns: 风格化后的 CIImage，如果转换失败则返回原图
    func applyStyle(to image: CIImage, style: FilterStyle) -> CIImage {
        guard style != .none else { return image }
        
        guard let model = modelCache[style] else {
            // 模型未加载，尝试加载
            preloadModel(for: style)
            return image
        }
        
        // 执行风格转换
        guard let styledImage = performStyleTransfer(image: image, model: model) else {
            return image
        }
        
        return styledImage
    }
    
    /// 应用风格转换到 CVPixelBuffer
    /// - Parameters:
    ///   - pixelBuffer: 输入的像素缓冲
    ///   - style: 目标风格
    /// - Returns: 风格化后的 CIImage
    func applyStyle(to pixelBuffer: CVPixelBuffer, style: FilterStyle) -> CIImage? {
        let inputImage = CIImage(cvPixelBuffer: pixelBuffer)
        return applyStyle(to: inputImage, style: style)
    }
    
    // MARK: - 私有方法
    
    /// 加载 ML 模型
    private func loadModel(for style: FilterStyle) -> MLModel? {
        guard let modelName = style.modelName else { return nil }
        
        // 配置模型使用 GPU
        let config = MLModelConfiguration()
        config.computeUnits = .all
        
        // 尝试从 bundle 加载模型
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
    
    /// 执行风格转换
    private func performStyleTransfer(image: CIImage, model: MLModel) -> CIImage? {
        // 1. 将 CIImage 缩放到模型输入尺寸
        let originalExtent = image.extent
        let scaleX = modelInputSize.width / originalExtent.width
        let scaleY = modelInputSize.height / originalExtent.height
        
        let scaledImage = image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        // 2. 创建输入 PixelBuffer
        guard let inputBuffer = createPixelBuffer(from: scaledImage, size: modelInputSize) else {
            print("❌ 创建输入 PixelBuffer 失败")
            return nil
        }
        
        // 3. 执行模型预测
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: inputBuffer)])
            let output = try model.prediction(from: input)
            
            guard let outputBuffer = output.featureValue(for: "stylizedImage")?.imageBufferValue else {
                print("❌ 获取模型输出失败")
                return nil
            }
            
            // 4. 将输出转换回 CIImage 并缩放到原始尺寸
            var outputImage = CIImage(cvPixelBuffer: outputBuffer)
            
            // 缩放回原始尺寸
            let restoreScaleX = originalExtent.width / modelInputSize.width
            let restoreScaleY = originalExtent.height / modelInputSize.height
            outputImage = outputImage.transformed(by: CGAffineTransform(scaleX: restoreScaleX, y: restoreScaleY))
            
            return outputImage
            
        } catch {
            print("❌ 模型预测错误: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 从 CIImage 创建 CVPixelBuffer
    private func createPixelBuffer(from image: CIImage, size: CGSize) -> CVPixelBuffer? {
        let width = Int(size.width)
        let height = Int(size.height)
        
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferMetalCompatibilityKey: true
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
        
        // 使用 CIContext 渲染到 PixelBuffer
        ciContext.render(image, to: buffer)
        
        return buffer
    }
}

