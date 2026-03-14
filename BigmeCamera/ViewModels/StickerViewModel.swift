import SwiftUI

@MainActor
final class StickerViewModel: ObservableObject {
    @Published var stickers: [StickerInstance] = []
    @Published var selectedStickerId: UUID?

    var count: Int { stickers.count }

    func add(type: StickerType, near center: CGPoint) {
        let newCenter = CGPoint(x: center.x, y: center.y + 150)
        let sticker = StickerInstance(type: type, center: newCenter, scale: 1.0)
        stickers.append(sticker)
        selectedStickerId = sticker.id
    }

    func remove(id: UUID) {
        stickers.removeAll { $0.id == id }
        if selectedStickerId == id { selectedStickerId = stickers.last?.id }
    }

    func removeAll() {
        stickers.removeAll()
        selectedStickerId = nil
    }

    func select(id: UUID?) { selectedStickerId = id }

    func updateCenter(id: UUID, center: CGPoint, imageSize: CGSize) {
        guard let i = stickers.firstIndex(where: { $0.id == id }) else { return }
        stickers[i].center = CGPoint(
            x: max(0, min(center.x, imageSize.width)),
            y: max(0, min(center.y, imageSize.height))
        )
    }

    func updateScale(id: UUID, scale: CGFloat) {
        guard let i = stickers.firstIndex(where: { $0.id == id }) else { return }
        stickers[i].scale = max(0.3, min(scale, 3.0))
    }

    func updateRotation(id: UUID, rotation: CGFloat) {
        guard let i = stickers.firstIndex(where: { $0.id == id }) else { return }
        stickers[i].rotation = rotation
    }
}
