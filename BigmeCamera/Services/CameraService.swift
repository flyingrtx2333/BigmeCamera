import AVFoundation
import CoreGraphics

final class CameraService: NSObject {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoOutputQueue = DispatchQueue(label: "camera.sampleBuffer.queue")
    private var isConfigured = false
    private var currentInput: AVCaptureDeviceInput?
    private var currentPosition: AVCaptureDevice.Position = .front

    var sampleBufferHandler: ((CMSampleBuffer) -> Void)?

    func currentAuthorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            completion(granted)
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                self.configureSession()
            }
            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: currentPosition) ?? AVCaptureDevice.default(.builtInWideAngleCamera,
                                                                                                for: .video,
                                                                                                position: currentPosition == .front ? .back : .front) else {
            session.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                if let currentInput = currentInput {
                    session.removeInput(currentInput)
                }
                session.addInput(input)
                currentInput = input
            }
        } catch {
            session.commitConfiguration()
            return
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if let connection = videoOutput.connection(with: .video) {
            if #available(iOS 17, *) {
                let portraitAngle: CGFloat = 90
                if connection.isVideoRotationAngleSupported(portraitAngle) {
                    connection.videoRotationAngle = portraitAngle
                }
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }

        session.commitConfiguration()
        isConfigured = true
    }
    
    func switchCamera(completion: ((AVCaptureDevice.Position) -> Void)? = nil) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else { return }
            
            self.session.beginConfiguration()
            
            // 移除当前输入
            if let currentInput = self.currentInput {
                self.session.removeInput(currentInput)
            }
            
            // 切换摄像头位置
            self.currentPosition = self.currentPosition == .front ? .back : .front
            
            // 获取新摄像头
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                          for: .video,
                                                          position: self.currentPosition) else {
                self.session.commitConfiguration()
                return
            }
            
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.currentInput = newInput
                }
            } catch {
                self.session.commitConfiguration()
                return
            }
            
            // 更新视频方向
            if let connection = self.videoOutput.connection(with: .video) {
                if #available(iOS 17, *) {
                    let portraitAngle: CGFloat = 90
                    if connection.isVideoRotationAngleSupported(portraitAngle) {
                        connection.videoRotationAngle = portraitAngle
                    }
                } else if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            
            self.session.commitConfiguration()
            
            // 通知完成
            DispatchQueue.main.async {
                completion?(self.currentPosition)
            }
        }
    }
    
    func currentCameraPosition() -> AVCaptureDevice.Position {
        currentPosition
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        sampleBufferHandler?(sampleBuffer)
    }
}

