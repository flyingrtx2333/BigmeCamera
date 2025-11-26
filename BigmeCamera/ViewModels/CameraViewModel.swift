import AVFoundation
import Photos
import SwiftUI
import UIKit

@MainActor
final class CameraViewModel: ObservableObject {
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
    
    // 分身相关
    @Published var clones: [CloneInstance] = []
    @Published var selectedCloneId: UUID?  // 当前选中的分身 ID
    
    // 贴纸相关
    @Published var stickers: [StickerInstance] = []
    @Published var selectedStickerId: UUID?  // 当前选中的贴纸 ID
    
    // 滤镜相关
    @Published var currentFilter: FilterStyle = .none
    @Published var isFilterModelLoading: Bool = false
    
    // 拍照/录像模式
    enum CaptureMode: String {
        case photo = "拍照"
        case video = "录像"
    }
    @Published var captureMode: CaptureMode = .photo
    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    
    private let videoRecordingService = VideoRecordingService()
    
    // 手动质心管理（主人物）
    @Published var isManualCenterMode: Bool = false
    private var manualPersonCenter: CGPoint?
    
    // 相机缩放相关
    @Published var currentZoom: CGFloat = 1.0
    @Published var zoomRange: (min: CGFloat, max: CGFloat) = (1.0, 1.0)
    
    private let cameraService = CameraService()
    nonisolated(unsafe) private let renderer = PersonSegmentationRenderer()
    private let renderQueue = DispatchQueue(label: "bigme.segmentation.queue")
    
    // 帧率计算相关
    private var frameTimestamps: [CFAbsoluteTime] = []
    private let fpsUpdateInterval: CFAbsoluteTime = 0.5 // 每0.5秒更新一次帧率
    private var lastFPSUpdateTime: CFAbsoluteTime = 0

    init() {
        authorizationStatus = cameraService.currentAuthorizationStatus()
        cameraService.sampleBufferHandler = { [weak self] sampleBuffer in
            guard let self else { return }
            Task { @MainActor in
                let currentConfig = self.config
                let manualCenter = self.manualPersonCenter
                let isManual = self.isManualCenterMode
                let currentClones = self.clones
                let currentStickers = self.stickers
                let filter = self.currentFilter
                self.handle(sampleBuffer: sampleBuffer, config: currentConfig, customCenter: isManual ? manualCenter : nil, clones: currentClones, stickers: currentStickers, filterStyle: filter)
            }
        }
        
        // 设置录像服务回调
        setupVideoRecordingCallbacks()
    }
    
    private func setupVideoRecordingCallbacks() {
        videoRecordingService.onRecordingStateChanged = { [weak self] isRecording in
            Task { @MainActor in
                self?.isRecording = isRecording
                if !isRecording {
                    self?.recordingDuration = 0
                }
            }
        }
        
        videoRecordingService.onDurationUpdated = { [weak self] duration in
            Task { @MainActor in
                self?.recordingDuration = duration
            }
        }
        
        videoRecordingService.onRecordingFinished = { [weak self] success, error in
            Task { @MainActor in
                self?.lastSaveSuccess = success
                self?.showSaveCelebration = true
                if let error = error {
                    print("❌ 录像保存失败: \(error.localizedDescription)")
                }
            }
        }
    }

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

    func requestPermission() {
        cameraService.requestAccess { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                self.authorizationStatus = self.cameraService.currentAuthorizationStatus()
                if granted {
                    self.cameraService.startSession()
                    self.isSessionRunning = true
                    // 延迟一点时间确保设备已配置完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.updateZoomRange()
                        self.currentZoom = self.cameraService.getCurrentZoom()
                    }
                }
            }
        }
    }

    func toggleSession() {
        if isSessionRunning {
            cameraService.stopSession()
            isSessionRunning = false
        } else {
            cameraService.startSession()
            isSessionRunning = true
        }
    }

    func updateScale(_ value: CGFloat) {
        config.personScale = value
    }

    func updateBlur(_ value: CGFloat) {
        config.blurRadius = value
    }

    func updateQuality(_ quality: SegmentationConfig.Quality) {
        config.quality = quality
    }
    
    func switchCamera() {
        cameraService.switchCamera { [weak self] newPosition in
            guard let self else { return }
            self.cameraPosition = newPosition
            // 切换摄像头后延迟更新缩放范围，确保新设备已配置完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateZoomRange()
                self.currentZoom = self.cameraService.getCurrentZoom()
            }
        }
    }
    
    func updateManualPersonCenter(_ center: CGPoint, imageSize: CGSize) {
        // 确保质心在图像范围内
        let clampedX = max(0, min(center.x, imageSize.width))
        let clampedY = max(0, min(center.y, imageSize.height))
        manualPersonCenter = CGPoint(x: clampedX, y: clampedY)
        isManualCenterMode = true
        personCenter = manualPersonCenter
    }
    
    func resetToAutoCenter() {
        isManualCenterMode = false
        manualPersonCenter = nil
    }
    
    // 更新缩放范围
    func updateZoomRange() {
        zoomRange = cameraService.getZoomRange()
    }
    
    // 设置缩放值
    func setZoom(_ zoomFactor: CGFloat) {
        cameraService.setZoom(zoomFactor) { [weak self] actualZoom in
            self?.currentZoom = actualZoom
        }
    }
    
    // 根据手势增量更新缩放
    func updateZoomByScale(_ scale: CGFloat, initialZoom: CGFloat) {
        let newZoom = initialZoom * scale
        setZoom(newZoom)
    }

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
    
    /// 关闭保存庆祝动画
    func dismissSaveCelebration() {
        showSaveCelebration = false
        lastSaveSuccess = nil
    }

    nonisolated private func handle(sampleBuffer: CMSampleBuffer, config: SegmentationConfig, customCenter: CGPoint?, clones: [CloneInstance], stickers: [StickerInstance], filterStyle: FilterStyle) {
        let renderer = self.renderer
        let videoService = self.videoRecordingService
        let currentTime = CFAbsoluteTimeGetCurrent()
        
        // 获取时间戳用于录像
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        renderQueue.async {
            guard let result = renderer.render(
                sampleBuffer: sampleBuffer,
                config: config,
                customCenter: customCenter,
                clones: clones,
                stickers: stickers,
                filterStyle: filterStyle
            ) else {
                return
            }
            
            // 如果正在录像，添加帧
            if videoService.recordingState {
                videoService.appendFrame(result.image, at: presentationTime)
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.renderedFrame = result.image
                // 只有在非手动模式时才更新质心（避免覆盖用户设置）
                if !self.isManualCenterMode {
                    self.personCenter = result.personCenter
                }
                self.updateFPS(currentTime: currentTime)
            }
        }
    }
    
    // MARK: - 分身管理方法
    
    /// 添加一个新分身
    func addClone() {
        guard let currentCenter = personCenter else { return }
        // 新分身默认在主人物右侧偏移一定距离
        let offset: CGFloat = 200
        let newCenter = CGPoint(x: currentCenter.x + offset, y: currentCenter.y)
        let newClone = CloneInstance(center: newCenter, scale: config.personScale)
        clones.append(newClone)
        selectedCloneId = newClone.id
    }
    
    /// 移除指定分身
    func removeClone(id: UUID) {
        clones.removeAll { $0.id == id }
        if selectedCloneId == id {
            selectedCloneId = clones.last?.id
        }
    }
    
    /// 移除所有分身
    func removeAllClones() {
        clones.removeAll()
        selectedCloneId = nil
    }
    
    /// 更新分身位置
    func updateCloneCenter(id: UUID, center: CGPoint, imageSize: CGSize) {
        guard let index = clones.firstIndex(where: { $0.id == id }) else { return }
        // 确保质心在图像范围内
        let clampedX = max(0, min(center.x, imageSize.width))
        let clampedY = max(0, min(center.y, imageSize.height))
        clones[index].center = CGPoint(x: clampedX, y: clampedY)
    }
    
    /// 更新分身缩放
    func updateCloneScale(id: UUID, scale: CGFloat) {
        guard let index = clones.firstIndex(where: { $0.id == id }) else { return }
        clones[index].scale = scale
    }
    
    /// 选中分身
    func selectClone(id: UUID?) {
        selectedCloneId = id
    }
    
    /// 获取分身数量
    var cloneCount: Int {
        clones.count
    }
    
    // MARK: - 贴纸管理方法
    
    /// 添加贴纸
    func addSticker(type: StickerType) {
        guard let currentCenter = personCenter else { return }
        // 新贴纸默认在人物上方
        let newCenter = CGPoint(x: currentCenter.x, y: currentCenter.y + 150)
        let newSticker = StickerInstance(type: type, center: newCenter, scale: 1.0)
        stickers.append(newSticker)
        selectedStickerId = newSticker.id
    }
    
    /// 移除指定贴纸
    func removeSticker(id: UUID) {
        stickers.removeAll { $0.id == id }
        if selectedStickerId == id {
            selectedStickerId = stickers.last?.id
        }
    }
    
    /// 移除所有贴纸
    func removeAllStickers() {
        stickers.removeAll()
        selectedStickerId = nil
    }
    
    /// 更新贴纸位置
    func updateStickerCenter(id: UUID, center: CGPoint, imageSize: CGSize) {
        guard let index = stickers.firstIndex(where: { $0.id == id }) else { return }
        let clampedX = max(0, min(center.x, imageSize.width))
        let clampedY = max(0, min(center.y, imageSize.height))
        stickers[index].center = CGPoint(x: clampedX, y: clampedY)
    }
    
    /// 更新贴纸缩放
    func updateStickerScale(id: UUID, scale: CGFloat) {
        guard let index = stickers.firstIndex(where: { $0.id == id }) else { return }
        stickers[index].scale = max(0.3, min(scale, 3.0))  // 限制缩放范围
    }
    
    /// 更新贴纸旋转
    func updateStickerRotation(id: UUID, rotation: CGFloat) {
        guard let index = stickers.firstIndex(where: { $0.id == id }) else { return }
        stickers[index].rotation = rotation
    }
    
    /// 选中贴纸
    func selectSticker(id: UUID?) {
        selectedStickerId = id
    }
    
    /// 获取贴纸数量
    var stickerCount: Int {
        stickers.count
    }
    
    // MARK: - 滤镜管理方法
    
    /// 设置滤镜风格
    func setFilter(_ style: FilterStyle) {
        // 如果模型未加载，先预加载
        if style != .none && !StyleService.shared.isModelLoaded(for: style) {
            isFilterModelLoading = true
            StyleService.shared.preloadModel(for: style)
            
            // 检查加载状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.checkFilterModelLoaded(style: style)
            }
        }
        currentFilter = style
    }
    
    /// 检查滤镜模型是否加载完成
    private func checkFilterModelLoaded(style: FilterStyle) {
        if StyleService.shared.isModelLoaded(for: style) {
            isFilterModelLoading = false
        } else if StyleService.shared.isModelLoading(for: style) {
            // 继续等待
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.checkFilterModelLoaded(style: style)
            }
        } else {
            // 加载失败
            isFilterModelLoading = false
        }
    }
    
    /// 获取当前滤镜是否可用
    var isCurrentFilterReady: Bool {
        currentFilter == .none || StyleService.shared.isModelLoaded(for: currentFilter)
    }
    
    // MARK: - 拍照/录像模式切换
    
    /// 切换拍照/录像模式
    func toggleCaptureMode() {
        // 如果正在录像，先停止
        if isRecording {
            stopRecording()
        }
        captureMode = captureMode == .photo ? .video : .photo
    }
    
    /// 设置拍照模式
    func setPhotoMode() {
        if isRecording {
            stopRecording()
        }
        captureMode = .photo
    }
    
    /// 设置录像模式
    func setVideoMode() {
        captureMode = .video
    }
    
    // MARK: - 录像控制
    
    /// 开始录像
    func startRecording() {
        guard let frame = renderedFrame else { return }
        let videoSize = CGSize(width: frame.width, height: frame.height)
        videoRecordingService.startRecording(videoSize: videoSize)
    }
    
    /// 停止录像
    func stopRecording() {
        videoRecordingService.stopRecording()
    }
    
    /// 切换录像状态
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    /// 格式化录像时长
    var formattedRecordingDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func updateFPS(currentTime: CFAbsoluteTime) {
        // 添加当前时间戳
        frameTimestamps.append(currentTime)
        
        // 只保留最近1秒内的帧
        let oneSecondAgo = currentTime - 1.0
        frameTimestamps.removeAll { $0 < oneSecondAgo }
        
        // 每0.5秒更新一次显示的帧率
        if currentTime - lastFPSUpdateTime >= fpsUpdateInterval {
            currentFPS = Double(frameTimestamps.count)
            lastFPSUpdateTime = currentTime
        }
    }
}

