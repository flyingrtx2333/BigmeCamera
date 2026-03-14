import SwiftUI

@MainActor
final class CloneViewModel: ObservableObject {
    @Published var clones: [CloneInstance] = []
    @Published var selectedCloneId: UUID?

    var count: Int { clones.count }

    func add(near center: CGPoint, scale: CGFloat) {
        let newCenter = CGPoint(x: center.x + 200, y: center.y)
        let clone = CloneInstance(center: newCenter, scale: scale)
        clones.append(clone)
        selectedCloneId = clone.id
    }

    func remove(id: UUID) {
        clones.removeAll { $0.id == id }
        if selectedCloneId == id { selectedCloneId = clones.last?.id }
    }

    func removeAll() {
        clones.removeAll()
        selectedCloneId = nil
    }

    func select(id: UUID?) { selectedCloneId = id }

    func updateCenter(id: UUID, center: CGPoint, imageSize: CGSize) {
        guard let i = clones.firstIndex(where: { $0.id == id }) else { return }
        clones[i].center = CGPoint(
            x: max(0, min(center.x, imageSize.width)),
            y: max(0, min(center.y, imageSize.height))
        )
    }

    func updateScale(id: UUID, scale: CGFloat) {
        guard let i = clones.firstIndex(where: { $0.id == id }) else { return }
        clones[i].scale = scale
    }

    func toggleFrozen(id: UUID) {
        guard let i = clones.firstIndex(where: { $0.id == id }) else { return }
        clones[i].isFrozen.toggle()
    }
}
