import CoreGraphics

/// 将 CoreImage 图像坐标（左下原点）映射到 SwiftUI scaledToFill 屏幕坐标（左上原点）
struct ImageCoordinateSpace {
    let imageSize: CGSize
    let viewSize: CGSize

    /// scaledToFill 缩放比例
    let scale: CGFloat
    /// 水平裁剪偏移
    let offsetX: CGFloat
    /// 垂直裁剪偏移
    let offsetY: CGFloat

    init(imageSize: CGSize, viewSize: CGSize) {
        self.imageSize = imageSize
        self.viewSize = viewSize
        scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let scaledW = imageSize.width * scale
        let scaledH = imageSize.height * scale
        offsetX = (scaledW - viewSize.width) / 2
        offsetY = (scaledH - viewSize.height) / 2
    }

    /// 图像坐标（CoreImage，Y 轴朝上）→ 屏幕坐标（SwiftUI，Y 轴朝下）
    func toScreen(_ imagePoint: CGPoint) -> CGPoint {
        let flippedY = imageSize.height - imagePoint.y
        return CGPoint(
            x: imagePoint.x * scale - offsetX,
            y: flippedY * scale - offsetY
        )
    }

    /// 屏幕坐标 → 图像坐标（CoreImage，Y 轴朝上）
    func toImage(_ screenPoint: CGPoint) -> CGPoint {
        let imageX = (screenPoint.x + offsetX) / scale
        let imageY = (screenPoint.y + offsetY) / scale
        return CGPoint(x: imageX, y: imageSize.height - imageY)
    }
}
