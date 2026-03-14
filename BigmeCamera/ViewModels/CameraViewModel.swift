import AVFoundation
import Photos
import SwiftUI
import UIKit

@MainActor
final class CameraViewModel: ObservableObject {
    // MARK: - 相机核心状态
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var renderedFrame: CGImage?
    @Published var isSessionRunning = false
    @Published var isSaving = false
    @Published var lastSaveSuccess: Bool?
    @Published var showSaveCelebration = false
    @Published var config = SegmentationConfig()
    @Published var cameraPosition: AVCaptureDevice.Position = .front
    @Published var currentFPS: Double = 0.0
    @Published var personCenter: CGPoint?
    @Published var currentZoom: CGFloat = 1.0
    @Published var zoomRange: (min: CGFloat, max: CGFloat) = (1.0, 1.0)

    // 手动质心
    @Published var isManualCenterMode: Bool = false
    private var manualPersonCenter: CGPoint?

    // 拍照/录像模式
    enum CaptureMode: String { case photo = "拍照"; case video = "录像" }
    @Published var captureMode: CaptureMode = .photo

    // MARK: - 子 ViewModel
    let cloneVM = CloneViewModel()
    let stickerVM = StickerViewModel()
    let filterVM = FilterViewModel()
    let recordingVM = RecordingViewModel()

    // MARK: - 私有
    private let cameraService = CameraService()
    nonisolated(unsafe) private let renderer = PersonSegmentationRenderer()
    private let renderQueue = DispatchQueue(label: "bigme.segmentation.queue")

    private var frameTimestamps = RingBuffer<CFAbsoluteTime>(capacity: 120)
    private let fpsUpdateInterval: CFAbsoluteTime = 0.5
    private var lastFPSUpdateTime: CFAbsoluteTime = 0

    // MARK: - Init
    init() {
        authorizationStatus = cameraService.currentAuthorizationStatus()
        cameraService.sampleBufferHandler = { [weak self] sampleBuffer in
            guard let self else { return }
            // 在 videoOutputQueue 上直接 dispatch 到 main 读取状态快照，
            // 避免每帧创建 Swift Task（有分配开销）
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.handle(
                    sampleBuffer: sampleBuffer,
                    config: self.config,
                    customCenter: self.isManualCenterMode ? self.manualPersonCenter : nil,
                    clones: self.cloneVM.clones,
                    stickers: self.stickerVM.stickers,
                    filterStyle: self.filterVM.currentFilter
                )
            }
        }
    }

    // MARK: - 生命周期
    func onAppear() {
        authorizationStatus = cameraService.currentAuthorizationStatus()
        cameraPosition = cameraService.currentCameraPosition()
        if authorizationStatus == .authorized {
            cameraService.startSession()
            isSessionRunning = true
            updateZoomRange()
            currentZoom = cameraService.getCurrentZoom()
        }
    }

    func onDisappear() {
        cameraService.stopSession()
        isSessionRunning = false
    }

    // MARK: - 权限
    func requestPermission() {
        cameraService.requestAccess { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                self.authorizationStatus = self.cameraService.currentAuthorizationStatus()
                if granted {
                    self.cameraService.startSession()
                    self.isSessionRunning = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.updateZoomRange()
                        self.currentZoom = self.cameraService.getCurrentZoom()
                    }
                }
            }
        }
    }

    // MARK: - 相机控制
    func updateScale(_ value: CGFloat) { config.personScale = value }
    func updateBlur(_ value: CGFloat) { config.blurRadius = value }
    func updateQuality(_ quality: SegmentationConfig.Quality) { config.quality = quality }

    func switchCamera() {
        cameraService.switchCamera { [weak self] newPosition in
            guard let self else { return }
            self.cameraPosition = newPosition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateZoomRange()
                self.currentZoom = self.cameraService.getCurrentZoom()
            }
        }
    }

    func updateZoomRange() { zoomRange = cameraService.getZoomRange() }

    func setZoom(_ zoomFactor: CGFloat) {
        cameraService.setZoom(zoomFactor) { [weak self] actual in
            self?.currentZoom = actual
        }
    }

    func updateZoomByScale(_ scale: CGFloat, initialZoom: CGFloat) {
        setZoom(initialZoom * scale)
    }

    // MARK: - 手动质心
    func updateManualPersonCenter(_ center: CGPoint, imageSize: CGSize) {
        manualPersonCenter = CGPoint(
            x: max(0, min(center.x, imageSize.width)),
            y: max(0, min(center.y, imageSize.height))
        )
        isManualCenterMode = true
        personCenter = manualPersonCenter
    }

    func resetToAutoCenter() {
        isManualCenterMode = false
        manualPersonCenter = nil
    }

    // MARK: - 拍照
    func capturePhoto() {
        guard let frame = renderedFrame else { return }
        isSaving = true
        lastSaveSuccess = nil
        showSaveCelebration = false

        let uiImage = UIImage(cgImage: frame)
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self?.isSaving = false
                    self?.lastSaveSuccess = false
                    self?.showSaveCelebration = true
                }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
            }) { success, error in
                DispatchQueue.main.async {
                    self?.isSaving = false
                    self?.lastSaveSuccess = success && error == nil
                    self?.showSaveCelebration = true
                }
            }
        }
    }

    func dismissSaveCelebration() {
        showSaveCelebration = false
        lastSaveSuccess = nil
    }

    // MARK: - 录像模式切换
    func toggleCaptureMode() {
        if recordingVM.isRecording { recordingVM.stop() }
        captureMode = captureMode == .photo ? .video : .photo
    }

    // MARK: - 帧处理
    private func handle(sampleBuffer: CMSampleBuffer, config: SegmentationConfig, customCenter: CGPoint?, clones: [CloneInstance], stickers: [StickerInstance], filterStyle: FilterStyle) {
        let renderer = self.renderer
        let recordingVM = self.recordingVM
        let currentTime = CFAbsoluteTimeGetCurrent()
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        renderQueue.async {
            guard let result = renderer.render(
                sampleBuffer: sampleBuffer,
                config: config,
                customCenter: customCenter,
                clones: clones,
                stickers: stickers,
                filterStyle: filterStyle
            ) else { return }

            if recordingVM.isRecording {
                recordingVM.appendFrame(result.image, at: presentationTime)
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.renderedFrame = result.image
                if !self.isManualCenterMode {
                    self.personCenter = result.personCenter
                }
                self.updateFPS(currentTime: currentTime)
            }
        }
    }

    private func updateFPS(currentTime: CFAbsoluteTime) {
        frameTimestamps.append(currentTime)
        if currentTime - lastFPSUpdateTime >= fpsUpdateInterval {
            let oneSecondAgo = currentTime - 1.0
            currentFPS = Double(frameTimestamps.count(where: { $0 >= oneSecondAgo }))
            lastFPSUpdateTime = currentTime
        }
    }
}
