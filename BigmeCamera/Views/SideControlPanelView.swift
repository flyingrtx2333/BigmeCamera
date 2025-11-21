import SwiftUI

struct SideControlPanelView: View {
    @ObservedObject var viewModel: CameraViewModel
    @State private var selectedCategory: ControlCategory? = nil
    @State private var showBeautyControls = false
    @State private var showStickerControls = false
    @State private var showFilterControls = false
    
    enum ControlCategory: String, CaseIterable {
        case beauty = "美颜"
        case sticker = "贴纸"
        case filter = "滤镜"
        
        var icon: String {
            switch self {
            case .beauty: return "sparkles"
            case .sticker: return "face.smiling"
            case .filter: return "camera.filters"
            }
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧按钮列
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(ControlCategory.allCases.enumerated()), id: \.element) { index, category in
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                // 如果点击的是已选中的按钮，则收起
                                if selectedCategory == category {
                                    selectedCategory = nil
                                    hideAllControls()
                                } else {
                                    selectedCategory = category
                                    updateControlsVisibility(for: category)
                                }
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(selectedCategory == category ? .white : .white.opacity(0.6))
                                
                                Text(category.rawValue)
                                    .font(.system(size: 10))
                                    .foregroundColor(selectedCategory == category ? .white : .white.opacity(0.6))
                            }
                            .frame(width: 60, height: 60)
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedCategory == category ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
                            }
                        }
                        .buttonStyle(.plain)
                        
                        // 右侧控制面板（展开时显示，与对应按钮对齐）
                        if selectedCategory == category {
                            VStack(alignment: .leading, spacing: 16) {
                                // 美颜控制
                                if showBeautyControls {
                                    beautyControlsView
                                }
                                
                                // 贴纸控制（占位）
                                if showStickerControls {
                                    stickerControlsView
                                }
                                
                                // 滤镜控制（占位）
                                if showFilterControls {
                                    filterControlsView
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(width: 200)
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                            }
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.leading, 12)
            
            Spacer()
        }
    }
    
    // MARK: - 美颜控制视图
    
    private var beautyControlsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 美颜开关
            Toggle(isOn: Binding(
                get: { viewModel.beautyConfig.isEnabled },
                set: { _ in viewModel.toggleBeauty() }
            )) {
                Text("美颜")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            
            if viewModel.beautyConfig.isEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    // 磨皮
                    VStack(alignment: .leading, spacing: 4) {
                        Text("磨皮: \(Int(viewModel.beautyConfig.smoothness * 100))%")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                        Slider(value: Binding(
                            get: { viewModel.beautyConfig.smoothness },
                            set: { viewModel.updateBeautySmoothness($0) }
                        ), in: 0...1, step: 0.01)
                        .tint(.white)
                    }
                    
                    // 美白
                    VStack(alignment: .leading, spacing: 4) {
                        Text("美白: \(Int(viewModel.beautyConfig.whitening * 100))%")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                        Slider(value: Binding(
                            get: { viewModel.beautyConfig.whitening },
                            set: { viewModel.updateBeautyWhitening($0) }
                        ), in: 0...1, step: 0.01)
                        .tint(.white)
                    }
                    
                    // 锐化
                    VStack(alignment: .leading, spacing: 4) {
                        Text("锐化: \(Int(viewModel.beautyConfig.sharpness * 100))%")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                        Slider(value: Binding(
                            get: { viewModel.beautyConfig.sharpness },
                            set: { viewModel.updateBeautySharpness($0) }
                        ), in: 0...1, step: 0.01)
                        .tint(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - 贴纸控制视图（占位）
    
    private var stickerControlsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("贴纸功能")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Text("即将推出")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    // MARK: - 滤镜控制视图（占位）
    
    private var filterControlsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("滤镜功能")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Text("即将推出")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    // MARK: - 辅助方法
    
    private func updateControlsVisibility(for category: ControlCategory) {
        // 先隐藏所有控制面板
        hideAllControls()
        
        // 根据选中的类别显示对应的控制面板
        switch category {
        case .beauty:
            showBeautyControls = true
        case .sticker:
            showStickerControls = true
        case .filter:
            showFilterControls = true
        }
    }
    
    private func hideAllControls() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showBeautyControls = false
            showStickerControls = false
            showFilterControls = false
        }
    }
}


