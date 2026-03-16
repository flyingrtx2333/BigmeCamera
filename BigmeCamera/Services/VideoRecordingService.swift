import AVFoundation
import CoreImage
import Photos
import UIKit

/// 视频录制服务
final class VideoRecordingService {
    
    // MARK: - 属性
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var pixelBufferPool: CVPixelBufferPool?

    private var isRecording = false
    private var startTime: CMTime?
    private var currentTime: CMTime = .zero

    private var videoSize: CGSize = CGSize(width: 1080, height: 1920)
    private var tempFileURL: URL?
    
    private let recordingQueue = DispatchQueue(label: "video.recording.queue")
    
    /// 录制状态回调
    var onRecordingStateChanged: ((Bool) -> Void)?
    
    /// 录制时长回调
    var onDurationUpdated: ((TimeInterval) -> Void)?
    
    /// 录制完成回调
    var onRecordingFinished: ((Bool, Error?) -> Void)?
    
    // MARK: - 公开方法
    
    /// 开始录制
    func startRecording(videoSize: CGSize) {
        recordingQueue.async { [weak self] in
            guard let self = self, !self.isRecording else { return }
            
            self.videoSize = videoSize
            
            // 创建临时文件
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "BigmeCamera_\(Date().timeIntervalSince1970).mp4"
            self.tempFileURL = tempDir.appendingPathComponent(fileName)
            
            guard let fileURL = self.tempFileURL else { return }
            
            // 删除可能存在的旧文件
            try? FileManager.default.removeItem(at: fileURL)
            
            do {
                // 创建 AVAssetWriter
                self.assetWriter = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)
                
                // 配置视频输入
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: Int(videoSize.width),
                    AVVideoHeightKey: Int(videoSize.height),
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: 6_000_000,  // 6 Mbps
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                    ]
                ]
                
                self.videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                self.videoInput?.expectsMediaDataInRealTime = true
                
                // 创建 PixelBuffer 适配器（含 pool，避免每帧 malloc）
                let sourcePixelBufferAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: Int(videoSize.width),
                    kCVPixelBufferHeightKey as String: Int(videoSize.height),
                    kCVPixelBufferIOSurfacePropertiesKey as String: [:]
                ]

                self.pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: self.videoInput!,
                    sourcePixelBufferAttributes: sourcePixelBufferAttributes
                )
                self.pixelBufferPool = self.pixelBufferAdaptor?.pixelBufferPool
                
                if self.assetWriter!.canAdd(self.videoInput!) {
                    self.assetWriter!.add(self.videoInput!)
                }
                
                // 开始写入
                self.assetWriter!.startWriting()
                self.isRecording = true
                self.startTime = nil
                
                DispatchQueue.main.async {
                    self.onRecordingStateChanged?(true)
                }
                
            } catch {
                print("❌ 创建 AVAssetWriter 失败: \(error)")
                DispatchQueue.main.async {
                    self.onRecordingFinished?(false, error)
                }
            }
        }
    }
    
    /// 添加帧（CIImage → CVPixelBuffer via CIContext，无 CPU 读回）
    func appendFrame(_ ciImage: CIImage, context: CIContext, at time: CMTime) {
        recordingQueue.async { [weak self] in
            guard let self = self,
                  self.isRecording,
                  let videoInput = self.videoInput,
                  let adaptor = self.pixelBufferAdaptor,
                  videoInput.isReadyForMoreMediaData else {
                return
            }

            // 设置开始时间
            if self.startTime == nil {
                self.startTime = time
                self.assetWriter?.startSession(atSourceTime: .zero)
            }

            // 计算相对时间
            let presentationTime = CMTimeSubtract(time, self.startTime!)
            self.currentTime = presentationTime

            // 从 pool 取 CVPixelBuffer
            var pixelBuffer: CVPixelBuffer?
            if let pool = self.pixelBufferPool {
                CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            }
            guard let buffer = pixelBuffer else { return }

            // GPU → CVPixelBuffer（IOSurface 支持），无 CPU 拷贝
            context.render(ciImage, to: buffer, bounds: ciImage.extent,
                           colorSpace: CGColorSpaceCreateDeviceRGB())

            // 添加到写入器
            if adaptor.append(buffer, withPresentationTime: presentationTime) {
                let duration = CMTimeGetSeconds(presentationTime)
                DispatchQueue.main.async {
                    self.onDurationUpdated?(duration)
                }
            }
        }
    }
    
    /// 停止录制
    func stopRecording() {
        recordingQueue.async { [weak self] in
            guard let self = self, self.isRecording else { return }
            
            self.isRecording = false
            
            self.videoInput?.markAsFinished()
            
            self.assetWriter?.finishWriting { [weak self] in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.onRecordingStateChanged?(false)
                }
                
                if self.assetWriter?.status == .completed {
                    // 保存到相册
                    self.saveToPhotoLibrary()
                } else {
                    let error = self.assetWriter?.error
                    DispatchQueue.main.async {
                        self.onRecordingFinished?(false, error)
                    }
                }
                
                // 清理
                self.assetWriter = nil
                self.videoInput = nil
                self.pixelBufferAdaptor = nil
                self.pixelBufferPool = nil
                self.startTime = nil
            }
        }
    }
    
    /// 获取当前录制状态
    var recordingState: Bool {
        isRecording
    }
    
    // MARK: - 私有方法
    
    private func saveToPhotoLibrary() {
        guard let fileURL = tempFileURL else {
            DispatchQueue.main.async {
                self.onRecordingFinished?(false, nil)
            }
            return
        }
        
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self?.onRecordingFinished?(false, nil)
                }
                // 清理临时文件
                try? FileManager.default.removeItem(at: fileURL)
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            }) { [weak self] success, error in
                // 清理临时文件
                try? FileManager.default.removeItem(at: fileURL)
                
                DispatchQueue.main.async {
                    self?.onRecordingFinished?(success, error)
                }
            }
        }
    }
}

