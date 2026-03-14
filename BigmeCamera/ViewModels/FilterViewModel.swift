import SwiftUI

@MainActor
final class FilterViewModel: ObservableObject {
    @Published var currentFilter: FilterStyle = .none
    @Published var isModelLoading: Bool = false

    var isReady: Bool {
        currentFilter == .none || StyleService.shared.isModelLoaded(for: currentFilter)
    }

    func setFilter(_ style: FilterStyle) {
        currentFilter = style
        guard style != .none, !StyleService.shared.isModelLoaded(for: style) else { return }

        isModelLoading = true
        StyleService.shared.preloadModel(for: style)

        Task { [weak self] in
            await self?.waitForModel(style)
        }
    }

    private func waitForModel(_ style: FilterStyle) async {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if StyleService.shared.isModelLoaded(for: style) {
                isModelLoading = false
                return
            }
            if !StyleService.shared.isModelLoading(for: style) {
                isModelLoading = false
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        isModelLoading = false
    }
}
