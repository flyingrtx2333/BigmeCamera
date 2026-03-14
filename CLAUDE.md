# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**BigmeCamera (大我相机)** is a native iOS app using real-time AI person segmentation to enlarge and highlight subjects in the camera frame. Runs fully on-device with no cloud dependency.

## Build & Run

This is a pure native iOS project — no CocoaPods, SPM, or npm. Open in Xcode and run directly.

```bash
# Build from command line
xcodebuild -scheme BigmeCamera -destination 'platform=iOS Simulator,name=iPhone 15'

# Run tests
xcodebuild test -scheme BigmeCamera -destination 'platform=iOS Simulator,name=iPhone 15'
```

Requirements: Xcode 14+, Swift 5.7+, iOS 15.0+ SDK.

## Architecture

MVVM pattern. The rendering pipeline flows:

```
CameraService (AVFoundation)
  → CMSampleBuffer frames
  → PersonSegmentationRenderer (Vision + CoreImage)
  → CameraViewModel (@Published state)
  → SwiftUI Views
```

**Key files:**

- `BigmeCameraApp.swift` — entry point, launches `SplashView`
- `ViewModels/CameraViewModel.swift` — 相机核心状态（帧流、权限、缩放、拍照），持有四个子 ViewModel
- `ViewModels/CloneViewModel.swift` — 分身增删改查、冻结快照
- `ViewModels/StickerViewModel.swift` — 贴纸增删改查、位置/缩放/旋转
- `ViewModels/FilterViewModel.swift` — 滤镜选择、CoreML 模型异步加载
- `ViewModels/RecordingViewModel.swift` — 录像开始/停止/时长/保存回调
- `Services/PersonSegmentationRenderer.swift` — core rendering: `VNGeneratePersonSegmentationRequest` + `CIBlendWithMask` + `CIGaussianBlur`
- `Services/CameraService.swift` — `AVCaptureSession` wrapper
- `Services/VideoRecordingService.swift` — 1080p video recording with `CVPixelBufferPool`
- `Services/StyleService.swift` — CoreML style transfer (anime/cartoon filters)
- `Models/SegmentationConfig.swift` — config: person zoom (1.0–1.8x), blur intensity, quality level (Fast/Balanced/Accurate)
- `Models/ImageCoordinateSpace.swift` — CoreImage（左下原点）↔ SwiftUI scaledToFill 屏幕坐标互转
- `Models/RingBuffer.swift` — 固定容量循环缓冲区，用于 FPS 计算

**Views:** `ContentView` → `CameraPreviewView` + `ControlPanelView` + `SideControlPanelView`. Onboarding via `HomeView` / `OnboardingGuideView`. Permissions via `PermissionView`.

## ML Models

- `whiteboxcartoonization.mlmodel` — pre-compiled CoreML model for cartoon style transfer
- `AIModel/` — Python scripts for ONNX/TensorFlow → CoreML conversion (AnimeGANv2)

## Localization

Uses `NSLocalizedString` with `en.lproj` and `zh-Hans.lproj`. All user-facing strings must be localized in both languages.

## Permissions

`Info.plist` declares camera (`NSCameraUsageDescription`) and photo library (`NSPhotoLibraryAddUsageDescription`) permissions. These are required at runtime before any camera or save operations.
