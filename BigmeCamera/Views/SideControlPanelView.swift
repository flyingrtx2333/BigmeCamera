import SwiftUI

struct SideControlPanelView: View {
    @ObservedObject var viewModel: CameraViewModel
    @State private var selectedCategory: ControlCategory? = nil
    @State private var showCloneControls = false
    @State private var showStickerControls = false
    @State private var showFilterControls = false
    @State private var selectedStickerCategory: StickerCategory = .emotion
    
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
                                    
                                    // 贴纸数量角标
                                    if category == .sticker && viewModel.stickerCount > 0 {
                                        Text("\(viewModel.stickerCount)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 16, height: 16)
                                            .background(Circle().fill(Color.orange))
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
    
    // MARK: - 贴纸控制视图
    
    private var stickerControlsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Text("贴纸")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                if !viewModel.stickers.isEmpty {
                    Button {
                        viewModel.removeAllStickers()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("清除")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                    }
                }
            }
            
            // 分类选择
            HStack(spacing: 8) {
                ForEach(StickerCategory.allCases, id: \.rawValue) { category in
                    Button {
                        selectedStickerCategory = category
                    } label: {
                        Text(category.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(selectedStickerCategory == category ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedStickerCategory == category ? Color.white.opacity(0.2) : Color.clear)
                            }
                    }
                }
            }
            
            // 贴纸网格
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(selectedStickerCategory.stickers) { sticker in
                    stickerButton(sticker: sticker)
                }
            }
            
            // 已添加的贴纸列表
            if !viewModel.stickers.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.2))
                
                Text("已添加 (\(viewModel.stickers.count))")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.stickers) { sticker in
                            addedStickerItem(sticker: sticker)
                        }
                    }
                }
            }
        }
    }
    
    private func stickerButton(sticker: StickerType) -> some View {
        Button {
            viewModel.addSticker(type: sticker)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: sticker.rawValue)
                    .font(.system(size: 24))
                    .foregroundColor(Color(
                        red: sticker.color.r,
                        green: sticker.color.g,
                        blue: sticker.color.b
                    ))
                
                Text(sticker.displayName)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(width: 50, height: 50)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
            }
        }
    }
    
    private func addedStickerItem(sticker: StickerInstance) -> some View {
        let isSelected = viewModel.selectedStickerId == sticker.id
        
        return ZStack(alignment: .topTrailing) {
            VStack(spacing: 2) {
                Image(systemName: sticker.type.rawValue)
                    .font(.system(size: 20))
                    .foregroundColor(Color(
                        red: sticker.type.color.r,
                        green: sticker.type.color.g,
                        blue: sticker.type.color.b
                    ))
            }
            .frame(width: 40, height: 40)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.orange.opacity(0.3) : Color.white.opacity(0.1))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.orange, lineWidth: 2)
                        }
                    }
            }
            .onTapGesture {
                viewModel.selectSticker(id: sticker.id)
            }
            
            // 删除按钮
            Button {
                viewModel.removeSticker(id: sticker.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .offset(x: 6, y: -6)
        }
    }
    
    // MARK: - 滤镜控制视图
    
    private var filterControlsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Text("滤镜风格")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                // 加载指示器
                if viewModel.isFilterModelLoading {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(.white)
                        Text("加载中...")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            
            // 滤镜网格
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(FilterStyle.allCases) { filter in
                    filterButton(filter: filter)
                }
            }
            
            // 提示文字
            Text("选择风格后将应用到整个画面")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 4)
        }
    }
    
    private func filterButton(filter: FilterStyle) -> some View {
        let isSelected = viewModel.currentFilter == filter
        let isLoading = filter != .none && viewModel.isFilterModelLoading && viewModel.currentFilter == filter
        
        return Button {
            viewModel.setFilter(filter)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.1))
                        .frame(height: 50)
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: filter.icon)
                            .font(.system(size: 22))
                            .foregroundColor(isSelected ? .blue : .white.opacity(0.7))
                    }
                }
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue, lineWidth: 2)
                    }
                }
                
                Text(filter.displayName)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            }
        }
        .buttonStyle(.plain)
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
