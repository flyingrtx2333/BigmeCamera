中文名：大我相机
英文名：BigmeCamera

标语
让人物更加突出、展现最好的自己。
Put YOU in the center — real-time human focus & enlargement.


副标题
1.让你成为画面的主角
2.实时放大你的精彩
3.主角视角，从现在开始
4.AI 让人物更突出
5.Bigger You. Better Shot.

应用商店关键词
AI相机,人物放大,背景分离,人像模式,实时相机,虚化背景,视频拍摄
portrait camera,background removal,live segmentation,real-time AI camera,portrait enhancer,selfie camera,body zoom

# 应用描述
大我相机 · BigmeCamera 是一款搭载轻量级 AI 人体分割技术的实时相机应用。
通过手机端 CPU/GPU 运行，不依赖云服务，实现 实时人物识别、背景分离与人物放大，让你在任何场景都能成为画面的唯一焦点。

无论你在拍 vlog、自拍、直播或录制室内教学，大我相机都能提供自然流畅的人物突出效果，让每一帧都充满表现力。
主要功能

实时 AI 人物分割
基于轻量化人体分割模型，毫秒级运行，无网络依赖。

一键人物放大
无需绿幕，让你在画面中更靠前、更突出。

背景虚化 / 虚化强度可调
模拟单反级景深效果。

背景替换（可选）
可替换成纯色、模糊背景或用户自选图片。

视频录制 & 拍照全支持
支持1080p实时保存。

超轻量运行
iPhone 上即可流畅运行，实现稳定 30~60fps。

# 核心价值
让普通的视频拍摄瞬间充满高级感
不依赖云端，在本地安全运行
无需绿幕与专业设备
实现比原生相机更强的“人物突出感”
轻量化 + 低延迟，满足实时相机需求

目标用户
Vlog 创作者
TikTok/小红书达人
线上课程教师
直播主、带货主播
喜欢自拍或日常记录的人
需要背景分离的商务视频创建者

技术优势
采用NSLocalizedString实现中英双语本地化

## 架构设计

采用 **MVVM (Model-View-ViewModel)** 架构模式，确保代码结构清晰、易于维护和测试。

```
BigmeCamera/
│
├── BigmeCameraApp.swift          # 应用入口
│
├── Models/
│   └── SegmentationConfig.swift  # 分割配置模型（人物缩放比例、背景虚化强度、质量等级）
│
├── ViewModels/
│   └── CameraViewModel.swift      # 相机视图模型（管理相机状态、权限、渲染流程）
│
├── Views/
│   ├── ContentView.swift          # 主视图容器
│   ├── CameraPreviewView.swift    # 相机预览视图
│   ├── ControlPanelView.swift     # 控制面板（参数调节、拍照按钮）
│   ├── PermissionView.swift       # 权限请求视图
│   └── SaveStatusBadge.swift      # 保存状态提示
│
└── Services/
    ├── CameraService.swift        # 相机服务（AVFoundation 封装）
    └── PersonSegmentationRenderer.swift  # 人物分割渲染器（Vision + CoreImage）
```

## 核心技术栈

### Apple Vision Framework
- **VNGeneratePersonSegmentationRequest**: 使用 Apple Vision 框架进行实时人物分割
- 支持三种质量等级：快速（Fast）、平衡（Balanced）、精确（Accurate）
- 完全在设备端运行，无需网络连接

### AVFoundation
- **AVCaptureSession**: 管理相机输入输出
- **AVCaptureVideoDataOutput**: 实时获取视频帧
- 支持前置/后置摄像头切换

### CoreImage
- **CIGaussianBlur**: 背景虚化效果
- **CIBlendWithMask**: 人物与背景合成
- **CIContext**: 高性能图像渲染

### SwiftUI
- 声明式 UI 框架
- 响应式数据绑定
- 现代化界面设计

### Photos Framework
- 照片保存到系统相册
- 权限管理

## 文件结构

### Models
- `SegmentationConfig.swift`: 定义分割配置参数（人物缩放、背景虚化、质量等级）

### ViewModels
- `CameraViewModel.swift`: 管理相机状态、权限请求、图像处理流程

### Views
- `ContentView.swift`: 主视图，协调各子视图
- `CameraPreviewView.swift`: 显示实时相机预览
- `ControlPanelView.swift`: 参数调节面板
- `PermissionView.swift`: 相机权限请求界面
- `SaveStatusBadge.swift`: 保存状态提示组件

### Services
- `CameraService.swift`: 封装 AVFoundation 相机操作
- `PersonSegmentationRenderer.swift`: 实现 Vision 人物分割和 CoreImage 图像处理

## MVP 功能清单

✅ **已完成**
- [x] MVVM 架构搭建
- [x] Apple Vision 人物分割集成
- [x] 实时相机预览
- [x] 人物缩放功能（1.0x - 1.8x）
- [x] 背景虚化功能（0-20 强度可调）
- [x] 三种分割质量模式（快速/平衡/精确）
- [x] 拍照保存到相册
- [x] 中英双语本地化
- [x] 相机权限管理

🚧 **待实现（后续版本）**
- [ ] 视频录制功能
- [ ] 背景替换功能
- [ ] 前后摄像头切换
- [ ] 实时性能优化
- [ ] 更多滤镜效果

## 使用说明

1. **首次启动**: 应用会请求相机权限，点击"授权相机访问"按钮
2. **实时预览**: 授权后自动开始实时人物分割和放大效果
3. **参数调节**:
   - 拖动"人物放大比例"滑块调整人物大小（1.0x - 1.8x）
   - 拖动"背景虚化强度"滑块调整背景模糊程度（0-20）
   - 选择分割质量模式（快速/平衡/精确）
4. **拍照保存**: 点击"立即拍照"按钮，照片将保存到系统相册

## 系统要求

- iOS 15.0+
- 支持 Apple Vision Framework 的设备
- 相机权限

## 开发环境

- Xcode 14.0+
- Swift 5.7+
- iOS 15.0+ SDK