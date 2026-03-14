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
        if selectedCloneId == id {
            // 选中相邻项：优先选后一个，没有则选前一个
            if let idx = clones.firstIndex(where: { $0.id == id }) {
                let next = clones.indices.contains(idx + 1) ? clones[idx + 1].id
                         : idx > 0 ? clones[idx - 1].id
                         : nil
                selectedCloneId = next
            }
        }
        clones.removeAll { $0.id == id }
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
