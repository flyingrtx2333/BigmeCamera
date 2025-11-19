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
    @Published var config = SegmentationConfig()
    @Published var cameraPosition: AVCaptureDevice.Position = .front
    @Published var currentFPS: Double = 0.0
    @Published var personCenter: CGPoint?
    
    // 手动质心管理
    @Published var isManualCenterMode: Bool = false
    private var manualPersonCenter: CGPoint?
    
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
                self.handle(sampleBuffer: sampleBuffer, config: currentConfig, customCenter: isManual ? manualCenter : nil)
            }
        }
    }

    func onAppear() {
        authorizationStatus = cameraService.currentAuthorizationStatus()
        cameraPosition = cameraService.currentCameraPosition()
        if authorizationStatus == .authorized {
            cameraService.startSession()
            isSessionRunning = true
        }
    }

    func onDisappear() {
        cameraService.stopSession()
        isSessionRunning = false
    }

    func requestPermission() {
        cameraService.requestAccess { [weak self] granted in
            DispatchQueue.main.async {
                self?.authorizationStatus = self?.cameraService.currentAuthorizationStatus() ?? .notDetermined
                if granted {
                    self?.cameraService.startSession()
                    self?.isSessionRunning = true
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
            self?.cameraPosition = newPosition
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

    func capturePhoto() {
        guard let frame = renderedFrame else { return }
        isSaving = true
        lastSaveSuccess = nil
        
        let uiImage = UIImage(cgImage: frame)
        
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self?.isSaving = false
                    self?.lastSaveSuccess = false
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
            }) { success, error in
                DispatchQueue.main.async {
                    self?.isSaving = false
                    self?.lastSaveSuccess = success && error == nil
                }
            }
        }
    }

    nonisolated private func handle(sampleBuffer: CMSampleBuffer, config: SegmentationConfig, customCenter: CGPoint?) {
        let renderer = self.renderer
        let currentTime = CFAbsoluteTimeGetCurrent()
        renderQueue.async {
            guard let result = renderer.render(
                sampleBuffer: sampleBuffer,
                config: config,
                customCenter: customCenter
            ) else {
                return
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

