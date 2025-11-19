import Foundation
import CoreGraphics
import Vision

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

