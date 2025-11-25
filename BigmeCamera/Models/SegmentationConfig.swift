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

