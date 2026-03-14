import SwiftUI

struct SideControlPanelView: View {
    @ObservedObject var cloneVM: CloneViewModel
    @ObservedObject var stickerVM: StickerViewModel
    @ObservedObject var filterVM: FilterViewModel
    var personCenter: CGPoint?
    var personScale: CGFloat = 1.0  // 新分身继承当前人物缩放比例

    @State private var selectedCategory: ControlCategory? = nil
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
            VStack(alignment: .leading, spacing: 16) {
                ForEach(ControlCategory.allCases, id: \.self) { category in
                    HStack(spacing: 12) {
                        categoryButton(category)

                        if selectedCategory == category {
                            panelContent(for: category)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .frame(width: 224)
                                .liquidGlass(cornerRadius: 20)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .leading).combined(with: .opacity).combined(with: .scale(scale: 0.95, anchor: .leading)),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    )
                                )
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.leading, 12)

            Spacer()
        }
    }

    // MARK: - 分类按钮

    private func categoryButton(_ category: ControlCategory) -> some View {
        let isSelected = selectedCategory == category
        let badge: Int? = {
            switch category {
            case .clone: return cloneVM.count > 0 ? cloneVM.count : nil
            case .sticker: return stickerVM.count > 0 ? stickerVM.count : nil
            case .filter: return nil
            }
        }()
        let badgeColor: Color = category == .clone ? .red : .orange

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedCategory = selectedCategory == category ? nil : category
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: category.icon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                        .frame(width: 32, height: 32)

                    if let badge {
                        Text("\(badge)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(badgeColor))
                            .offset(x: 8, y: -8)
                    }
                }

                Text(category.rawValue)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            }
            .frame(width: 60, height: 60)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected
                          ? Color.white.opacity(0.22)
                          : Color.white.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: isSelected
                                        ? [.white.opacity(0.55), .white.opacity(0.15)]
                                        : [.white.opacity(0.2), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.6
                            )
                    }
                    .shadow(color: .black.opacity(isSelected ? 0.3 : 0.15), radius: isSelected ? 12 : 6, y: 4)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    // MARK: - 面板内容（用 selectedCategory 直接驱动，无冗余 Bool）

    @ViewBuilder
    private func panelContent(for category: ControlCategory) -> some View {
        switch category {
        case .clone: clonePanel
        case .sticker: stickerPanel
        case .filter: filterPanel
        }
    }

    // MARK: - 分身面板

    private var clonePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("分身管理")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    if let center = personCenter {
                        cloneVM.add(near: center, scale: personScale)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("添加")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
                }
            }

            if cloneVM.clones.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.4))
                    Text("点击「添加」创建分身")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    VStack(spacing: 2) {
                        Text("拖动红点移动分身位置")
                        Text("点击📷可冻结快照")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 8) {
                    ForEach(cloneVM.clones) { clone in
                        cloneItem(clone)
                    }
                }
                Button {
                    cloneVM.removeAll()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("清除所有分身")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background { RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.1)) }
                }
            }
        }
    }

    private func cloneItem(_ clone: CloneInstance) -> some View {
        let isSelected = cloneVM.selectedCloneId == clone.id
        let index = cloneVM.clones.firstIndex(where: { $0.id == clone.id }) ?? 0

        return HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .opacity(clone.isFrozen ? 0 : 1)
                if clone.isFrozen {
                    Image(systemName: "snowflake")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.cyan)
                }
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("分身 #\(index + 1)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    if clone.isFrozen {
                        Text("已快照")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background { Capsule().fill(Color.cyan.opacity(0.2)) }
                    }
                }
                Text("缩放: \(String(format: "%.0f", clone.scale * 100))%")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Button { cloneVM.toggleFrozen(id: clone.id) } label: {
                Image(systemName: clone.isFrozen ? "play.circle.fill" : "camera.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(clone.isFrozen ? .green : .cyan)
            }
            .buttonStyle(.plain)

            Button { cloneVM.remove(id: clone.id) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(clone.isFrozen ? Color.cyan.opacity(0.15) : (isSelected ? Color.blue.opacity(0.2) : Color.white.opacity(0.05)))
                .overlay {
                    if clone.isFrozen {
                        RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                    }
                }
        }
        .contentShape(Rectangle())
        .onTapGesture { cloneVM.select(id: clone.id) }
    }

    // MARK: - 贴纸面板

    private var stickerPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("贴纸")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                if !stickerVM.stickers.isEmpty {
                    Button { stickerVM.removeAll() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("清除")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                    }
                }
            }

            HStack(spacing: 8) {
                ForEach(StickerCategory.allCases, id: \.rawValue) { cat in
                    Button { selectedStickerCategory = cat } label: {
                        Text(cat.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(selectedStickerCategory == cat ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedStickerCategory == cat ? Color.white.opacity(0.2) : Color.clear)
                            }
                    }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(selectedStickerCategory.stickers) { sticker in
                    Button {
                        if let center = personCenter {
                            stickerVM.add(type: sticker, near: center)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: sticker.rawValue)
                                .font(.system(size: 24))
                                .foregroundColor(Color(red: sticker.color.r, green: sticker.color.g, blue: sticker.color.b))
                            Text(sticker.displayName)
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .frame(width: 50, height: 50)
                        .background { RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1)) }
                    }
                }
            }

            if !stickerVM.stickers.isEmpty {
                Divider().background(Color.white.opacity(0.2))
                Text("已添加 (\(stickerVM.stickers.count))")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(stickerVM.stickers) { sticker in
                            addedStickerItem(sticker)
                        }
                    }
                }
            }
        }
    }

    private func addedStickerItem(_ sticker: StickerInstance) -> some View {
        let isSelected = stickerVM.selectedStickerId == sticker.id
        return ZStack(alignment: .topTrailing) {
            Image(systemName: sticker.type.rawValue)
                .font(.system(size: 20))
                .foregroundColor(Color(red: sticker.type.color.r, green: sticker.type.color.g, blue: sticker.type.color.b))
                .frame(width: 40, height: 40)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.orange.opacity(0.3) : Color.white.opacity(0.1))
                        .overlay {
                            if isSelected { RoundedRectangle(cornerRadius: 6).stroke(Color.orange, lineWidth: 2) }
                        }
                }
                .onTapGesture { stickerVM.select(id: sticker.id) }

            Button { stickerVM.remove(id: sticker.id) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .offset(x: 6, y: -6)
        }
    }

    // MARK: - 滤镜面板

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("滤镜风格")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                if filterVM.isModelLoading {
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.6).tint(.white)
                        Text("加载中...")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                ForEach(FilterStyle.allCases) { filter in
                    filterButton(filter)
                }
            }

            Text("选择风格后将应用到整个画面")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 4)
        }
    }

    private func filterButton(_ filter: FilterStyle) -> some View {
        let isSelected = filterVM.currentFilter == filter
        let isLoading = filter != .none && filterVM.isModelLoading && filterVM.currentFilter == filter

        return Button { filterVM.setFilter(filter) } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.1))
                        .frame(height: 50)
                    if isLoading {
                        ProgressView().scaleEffect(0.8).tint(.white)
                    } else {
                        Image(systemName: filter.icon)
                            .font(.system(size: 22))
                            .foregroundColor(isSelected ? .blue : .white.opacity(0.7))
                    }
                }
                .overlay {
                    if isSelected { RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 2) }
                }
                Text(filter.displayName)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            }
        }
        .buttonStyle(.plain)
    }
}
