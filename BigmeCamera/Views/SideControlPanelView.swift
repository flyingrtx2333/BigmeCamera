import SwiftUI

struct SideControlPanelView: View {
    @ObservedObject var cloneVM: CloneViewModel
    @ObservedObject var stickerVM: StickerViewModel
    @ObservedObject var filterVM: FilterViewModel
    var personCenter: CGPoint?
    var personScale: CGFloat = 1.0

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

        var accentColor: Color {
            switch self {
            case .clone: return Color(red: 0.35, green: 0.65, blue: 1.0)
            case .sticker: return Color(red: 1.0, green: 0.65, blue: 0.25)
            case .filter: return Color(red: 0.55, green: 0.90, blue: 0.65)
            }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(ControlCategory.allCases, id: \.self) { category in
                    HStack(spacing: 10) {
                        categoryButton(category)

                        if selectedCategory == category {
                            panelContent(for: category)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .frame(width: 228)
                                .liquidGlass(cornerRadius: 20)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .leading).combined(with: .opacity).combined(with: .scale(scale: 0.96, anchor: .leading)),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    )
                                )
                        }
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.leading, 10)

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

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                selectedCategory = selectedCategory == category ? nil : category
            }
        } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: category.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(
                            isSelected
                                ? LinearGradient(colors: [.white, category.accentColor.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 28, height: 28)

                    if let badge {
                        Text("\(badge)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 15, height: 15)
                            .background(Circle().fill(category.accentColor))
                            .offset(x: 7, y: -7)
                    }
                }

                Text(category.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.50))
                    .tracking(0.3)
            }
            .frame(width: 56, height: 56)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected
                          ? category.accentColor.opacity(0.18)
                          : Color.white.opacity(0.07))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: isSelected
                                        ? [category.accentColor.opacity(0.60), category.accentColor.opacity(0.15)]
                                        : [.white.opacity(0.18), .white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.7
                            )
                    }
                    .shadow(color: .black.opacity(isSelected ? 0.35 : 0.18), radius: isSelected ? 14 : 7, y: 4)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.06 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.70), value: isSelected)
    }

    // MARK: - 面板内容

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
        VStack(alignment: .leading, spacing: 14) {
            panelHeader(title: "分身管理") {
                Button {
                    if let center = personCenter {
                        cloneVM.add(near: center, scale: personScale)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("添加")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ControlCategory.clone.accentColor)
                }
            }

            if cloneVM.clones.isEmpty {
                emptyState(icon: "person.2.slash", message: "点击「添加」创建分身", hint: "拖动蓝点移动分身位置")
            } else {
                VStack(spacing: 6) {
                    ForEach(cloneVM.clones) { clone in
                        cloneItem(clone)
                    }
                }
                Button {
                    cloneVM.removeAll()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("清除所有分身")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background { RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.08)) }
                }
            }
        }
    }

    private func cloneItem(_ clone: CloneInstance) -> some View {
        let isSelected = cloneVM.selectedCloneId == clone.id
        let index = cloneVM.clones.firstIndex(where: { $0.id == clone.id }) ?? 0

        return HStack(spacing: 8) {
            ZStack {
                if clone.isFrozen {
                    Image(systemName: "snowflake")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.cyan)
                } else {
                    Circle()
                        .fill(isSelected ? ControlCategory.clone.accentColor : Color.white.opacity(0.35))
                        .frame(width: 7, height: 7)
                }
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("分身 #\(index + 1)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    if clone.isFrozen {
                        Text("快照")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background { Capsule().fill(Color.cyan.opacity(0.18)) }
                    }
                }
                Text("缩放 \(String(format: "%.0f", clone.scale * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.50))
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
                    .foregroundColor(.white.opacity(0.40))
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 9)
                .fill(clone.isFrozen ? Color.cyan.opacity(0.12) : (isSelected ? ControlCategory.clone.accentColor.opacity(0.15) : Color.white.opacity(0.05)))
                .overlay {
                    if clone.isFrozen {
                        RoundedRectangle(cornerRadius: 9).stroke(Color.cyan.opacity(0.35), lineWidth: 0.7)
                    } else if isSelected {
                        RoundedRectangle(cornerRadius: 9).stroke(ControlCategory.clone.accentColor.opacity(0.40), lineWidth: 0.7)
                    }
                }
        }
        .contentShape(Rectangle())
        .onTapGesture { cloneVM.select(id: clone.id) }
    }

    // MARK: - 贴纸面板

    private var stickerPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelHeader(title: "贴纸") {
                if !stickerVM.stickers.isEmpty {
                    Button { stickerVM.removeAll() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("清除")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red.opacity(0.75))
                    }
                }
            }

            // 分类标签
            HStack(spacing: 6) {
                ForEach(StickerCategory.allCases, id: \.rawValue) { cat in
                    Button { selectedStickerCategory = cat } label: {
                        Text(cat.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(selectedStickerCategory == cat ? .white : .white.opacity(0.45))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(selectedStickerCategory == cat
                                          ? ControlCategory.sticker.accentColor.opacity(0.22)
                                          : Color.clear)
                                    .overlay {
                                        if selectedStickerCategory == cat {
                                            RoundedRectangle(cornerRadius: 7)
                                                .stroke(ControlCategory.sticker.accentColor.opacity(0.45), lineWidth: 0.7)
                                        }
                                    }
                            }
                    }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 7) {
                ForEach(selectedStickerCategory.stickers) { sticker in
                    Button {
                        if let center = personCenter {
                            stickerVM.add(type: sticker, near: center)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: sticker.rawValue)
                                .font(.system(size: 22))
                                .foregroundColor(Color(red: sticker.color.r, green: sticker.color.g, blue: sticker.color.b))
                            Text(sticker.displayName)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.white.opacity(0.65))
                        }
                        .frame(width: 50, height: 50)
                        .background {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(Color.white.opacity(0.07))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 9)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 0.6)
                                }
                        }
                    }
                }
            }

            if !stickerVM.stickers.isEmpty {
                Divider().background(Color.white.opacity(0.12))
                Text("已添加 (\(stickerVM.stickers.count))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.50))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
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
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isSelected ? ControlCategory.sticker.accentColor.opacity(0.22) : Color.white.opacity(0.08))
                        .overlay {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(ControlCategory.sticker.accentColor.opacity(0.55), lineWidth: 1)
                            }
                        }
                }
                .onTapGesture { stickerVM.select(id: sticker.id) }

            Button { stickerVM.remove(id: sticker.id) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.65))
                    .background(Circle().fill(Color.black.opacity(0.45)))
            }
            .offset(x: 5, y: -5)
        }
    }

    // MARK: - 滤镜面板

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelHeader(title: "滤镜风格") {
                if filterVM.isModelLoading {
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.55).tint(ControlCategory.filter.accentColor)
                        Text("加载中")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(FilterStyle.allCases) { filter in
                    filterButton(filter)
                }
            }

            Text("选择风格后将应用到整个画面")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.40))
                .padding(.top, 2)
        }
    }

    private func filterButton(_ filter: FilterStyle) -> some View {
        let isSelected = filterVM.currentFilter == filter
        let isLoading = filter != .none && filterVM.isModelLoading && filterVM.currentFilter == filter

        return Button { filterVM.setFilter(filter) } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected
                              ? ControlCategory.filter.accentColor.opacity(0.20)
                              : Color.white.opacity(0.07))
                        .frame(height: 48)
                        .overlay {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(ControlCategory.filter.accentColor.opacity(0.55), lineWidth: 1)
                            }
                        }
                    if isLoading {
                        ProgressView().scaleEffect(0.75).tint(ControlCategory.filter.accentColor)
                    } else {
                        Image(systemName: filter.icon)
                            .font(.system(size: 20))
                            .foregroundColor(isSelected ? ControlCategory.filter.accentColor : .white.opacity(0.65))
                    }
                }
                Text(filter.displayName)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.65))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 共用子组件

    private func panelHeader(title: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            trailing()
        }
    }

    private func emptyState(icon: String, message: String, hint: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.white.opacity(0.30))
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
            Text(hint)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}
