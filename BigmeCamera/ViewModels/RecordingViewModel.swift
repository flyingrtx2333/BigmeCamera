import AVFoundation
import SwiftUI

@MainActor
final class RecordingViewModel: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var duration: TimeInterval = 0
    @Published var showSaveCelebration: Bool = false
    @Published var lastSaveSuccess: Bool?

    private let service = VideoRecordingService()

    init() {
        service.onRecordingStateChanged = { [weak self] recording in
            Task { @MainActor in
                self?.isRecording = recording
                if !recording { self?.duration = 0 }
            }
        }
        service.onDurationUpdated = { [weak self] d in
            Task { @MainActor in self?.duration = d }
        }
        service.onRecordingFinished = { [weak self] success, error in
            Task { @MainActor in
                self?.lastSaveSuccess = success
                self?.showSaveCelebration = true
                if let error { print("❌ 录像保存失败: \(error.localizedDescription)") }
            }
        }
    }

    func start(videoSize: CGSize) {
        service.startRecording(videoSize: videoSize)
    }

    func stop() {
        service.stopRecording()
    }

    func toggle(videoSize: CGSize) {
        isRecording ? stop() : start(videoSize: videoSize)
    }

    func appendFrame(_ image: CGImage, at time: CMTime) {
        service.appendFrame(image, at: time)
    }

    func dismissCelebration() {
        showSaveCelebration = false
        lastSaveSuccess = nil
    }

    var formattedDuration: String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
