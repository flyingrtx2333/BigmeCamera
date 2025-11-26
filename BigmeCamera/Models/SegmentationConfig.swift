import Foundation
import CoreGraphics
import Vision

/// 分身数据模型
struct CloneInstance: Identifiable, Equatable {
    let id: UUID
    var center: CGPoint  // 分身质心位置（CIImage 坐标系）
    var scale: CGFloat   // 分身缩放比例
    
    init(id: UUID = UUID(), center: CGPoint, scale: CGFloat = 1.0) {
        self.id = id
        self.center = center
        self.scale = scale
    }
}

/// 贴纸类型枚举
enum StickerType: String, CaseIterable, Identifiable {
    // 表情类
    case heart = "heart.fill"
    case star = "star.fill"
    case sparkles = "sparkles"
    case flame = "flame.fill"
    case bolt = "bolt.fill"
    
    // 可爱类
    case pawprint = "pawprint.fill"
    case leaf = "leaf.fill"
    case snowflake = "snowflake"
    case sun = "sun.max.fill"
    case moon = "moon.fill"
    
    // 社交类
    case thumbsUp = "hand.thumbsup.fill"
    case peace = "hand.raised.fill"
    case crown = "crown.fill"
    case gift = "gift.fill"
    case balloon = "balloon.fill"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .heart: return "爱心"
        case .star: return "星星"
        case .sparkles: return "闪光"
        case .flame: return "火焰"
        case .bolt: return "闪电"
        case .pawprint: return "爪印"
        case .leaf: return "树叶"
        case .snowflake: return "雪花"
        case .sun: return "太阳"
        case .moon: return "月亮"
        case .thumbsUp: return "点赞"
        case .peace: return "举手"
        case .crown: return "皇冠"
        case .gift: return "礼物"
        case .balloon: return "气球"
        }
    }
    
    /// 贴纸颜色
    var color: (r: CGFloat, g: CGFloat, b: CGFloat) {
        switch self {
        case .heart: return (1.0, 0.3, 0.4)        // 红色
        case .star: return (1.0, 0.85, 0.0)        // 金色
        case .sparkles: return (1.0, 0.8, 0.2)     // 闪金色
        case .flame: return (1.0, 0.5, 0.0)        // 橙色
        case .bolt: return (1.0, 0.9, 0.0)         // 黄色
        case .pawprint: return (0.6, 0.4, 0.2)     // 棕色
        case .leaf: return (0.2, 0.8, 0.4)         // 绿色
        case .snowflake: return (0.6, 0.85, 1.0)   // 冰蓝色
        case .sun: return (1.0, 0.7, 0.0)          // 橙黄色
        case .moon: return (0.9, 0.9, 0.6)         // 淡黄色
        case .thumbsUp: return (0.3, 0.6, 1.0)     // 蓝色
        case .peace: return (1.0, 0.8, 0.6)        // 肤色
        case .crown: return (1.0, 0.84, 0.0)       // 金色
        case .gift: return (0.8, 0.2, 0.5)         // 粉紫色
        case .balloon: return (1.0, 0.4, 0.4)      // 红色
        }
    }
    
    /// 贴纸分类
    var category: StickerCategory {
        switch self {
        case .heart, .star, .sparkles, .flame, .bolt:
            return .emotion
        case .pawprint, .leaf, .snowflake, .sun, .moon:
            return .nature
        case .thumbsUp, .peace, .crown, .gift, .balloon:
            return .social
        }
    }
}

/// 贴纸分类
enum StickerCategory: String, CaseIterable {
    case emotion = "表情"
    case nature = "自然"
    case social = "社交"
    
    var stickers: [StickerType] {
        StickerType.allCases.filter { $0.category == self }
    }
}

/// 贴纸实例数据模型
struct StickerInstance: Identifiable, Equatable {
    let id: UUID
    let type: StickerType
    var center: CGPoint      // 贴纸中心位置（CIImage 坐标系）
    var scale: CGFloat       // 贴纸缩放比例
    var rotation: CGFloat    // 贴纸旋转角度（弧度）
    
    init(id: UUID = UUID(), type: StickerType, center: CGPoint, scale: CGFloat = 1.0, rotation: CGFloat = 0) {
        self.id = id
        self.type = type
        self.center = center
        self.scale = scale
        self.rotation = rotation
    }
}

struct SegmentationConfig: Equatable {
    enum Quality: String, CaseIterable, Identifiable {
        case fast
        case balanced
        case accurate

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .fast: return NSLocalizedString("Fast", comment: "")
            case .balanced: return NSLocalizedString("Balanced", comment: "")
            case .accurate: return NSLocalizedString("Accurate", comment: "")
            }
        }

        var requestLevel: VNGeneratePersonSegmentationRequest.QualityLevel {
            switch self {
            case .fast: return .fast
            case .balanced: return .balanced
            case .accurate: return .accurate
            }
        }
    }

    var personScale: CGFloat
    var blurRadius: CGFloat
    var quality: Quality

    init(personScale: CGFloat = 1.25,
         blurRadius: CGFloat = 12,
         quality: Quality = .balanced) {
        self.personScale = personScale
        self.blurRadius = blurRadius
        self.quality = quality
    }
}

