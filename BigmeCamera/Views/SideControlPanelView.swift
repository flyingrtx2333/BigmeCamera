import SwiftUI

struct SideControlPanelView: View {
    @ObservedObject var viewModel: CameraViewModel
    @State private var selectedCategory: ControlCategory? = nil
    @State private var showCloneControls = false
    @State private var showStickerControls = false
    @State private var showFilterControls = false
    
    enum ControlCategory: String, CaseIterable {
        case clone = "分身"
        case sticker = "贴纸"
        case filter = "滤镜"
        
        var icon: String {
            switch self {
            case .clone: return "person.2.fill"
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
                                ZStack {
                                    Image(systemName: category.icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(selectedCategory == category ? .white : .white.opacity(0.6))
                                    
                                    // 分身数量角标
                                    if category == .clone && viewModel.cloneCount > 0 {
                                        Text("\(viewModel.cloneCount)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 16, height: 16)
                                            .background(Circle().fill(Color.red))
                                            .offset(x: 14, y: -14)
                                    }
                                }
                                
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
                                // 分身控制
                                if showCloneControls {
                                    cloneControlsView
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
                            .frame(width: 220)
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
    
    // MARK: - 分身控制视图
    
    private var cloneControlsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题和添加按钮
            HStack {
                Text("分身管理")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    viewModel.addClone()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("添加")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
                }
            }
            
            // 分身列表
            if viewModel.clones.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text("点击「添加」创建分身")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("拖动红点移动分身位置")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.clones) { clone in
                        cloneItemView(clone: clone)
                    }
                }
                
                // 清除所有按钮
                Button {
                    viewModel.removeAllClones()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("清除所有分身")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                    }
                }
            }
        }
    }
    
    // 单个分身项视图
    private func cloneItemView(clone: CloneInstance) -> some View {
        let isSelected = viewModel.selectedCloneId == clone.id
        
        return HStack(spacing: 8) {
            // 选中指示器
            Circle()
                .fill(isSelected ? Color.blue : Color.white.opacity(0.3))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("分身 #\(viewModel.clones.firstIndex(where: { $0.id == clone.id })! + 1)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                
                Text("缩放: \(String(format: "%.0f", clone.scale * 100))%")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // 删除按钮
            Button {
                viewModel.removeClone(id: clone.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectClone(id: clone.id)
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
        case .clone:
            showCloneControls = true
        case .sticker:
            showStickerControls = true
        case .filter:
            showFilterControls = true
        }
    }
    
    private func hideAllControls() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showCloneControls = false
            showStickerControls = false
            showFilterControls = false
        }
    }
}
