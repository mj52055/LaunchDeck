import AppKit
import SwiftUI

struct LauncherView: View {
    @Bindable var store: ApplicationStore
    @AppStorage(WindowMode.storageKey) private var windowModeRaw = WindowMode.launcher.rawValue
    @FocusState private var searchIsFocused: Bool
    @State private var showsHiddenApplications = false
    @State private var pageAnimationOffset: CGFloat = 0
    @State private var pageAnimationOpacity = 1.0
    @State private var pageAnimationTask: Task<Void, Never>?

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 96, maximum: 144), spacing: 18),
        count: ApplicationStore.gridColumnCount
    )

    var body: some View {
        ZStack {
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.blue.opacity(0.06),
                    Color.black.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.white.opacity(0.13), .clear],
                center: .topLeading,
                startRadius: 30,
                endRadius: 720
            )

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    if WindowMode(rawValue: windowModeRaw) != .standard {
                        closeLauncher()
                    }
                }

            VStack(spacing: 22) {
                header
                content
                pageControls
            }
            .padding(32)
        }
        .overlay {
            Rectangle()
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        }
        .onAppear { searchIsFocused = true }
        .onExitCommand {
            if store.query.isEmpty {
                closeLauncher()
            } else {
                store.query = ""
            }
        }
        .alert("LaunchDeck", isPresented: errorIsPresented) {
            Button("好", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "未知错误")
        }
        .sheet(isPresented: $showsHiddenApplications) {
            HiddenApplicationsView(store: store)
        }
        .onDisappear {
            pageAnimationTask?.cancel()
            pageAnimationTask = nil
        }
    }

    private var header: some View {
        ZStack {
            HStack(spacing: 14) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索应用", text: $store.query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($searchIsFocused)

                if !store.query.isEmpty {
                    Button {
                        store.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清除搜索")
                }
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: 520, minHeight: 48)
            .glassSurface(in: Capsule())

            HStack {
                Spacer()
                Button {
                    showsHiddenApplications = true
                } label: {
                    Label(
                        store.hiddenApplications.isEmpty
                            ? "隐藏的应用"
                            : "隐藏的应用（\(store.hiddenApplications.count)）",
                        systemImage: "eye.slash"
                    )
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .padding(10)
                }
                .buttonStyle(.plain)
                .glassSurface(in: Circle())
                .help("管理隐藏的应用")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.applications.isEmpty {
            VStack(spacing: 14) {
                ProgressView()
                Text("正在查找应用…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.filteredApplications.isEmpty {
            ContentUnavailableView(
                store.query.isEmpty ? "没有找到应用" : "没有匹配结果",
                systemImage: "square.grid.3x3",
                description: Text(store.query.isEmpty ? "请尝试重新扫描应用目录。" : "请尝试其他关键词。")
            )
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(store.pageApplications) { application in
                        ApplicationTile(
                            application: application,
                            isSelected: store.selectedApplicationID == application.id,
                            select: { store.select(application) },
                            launch: { store.launch(application, completion: closeLauncher) },
                            hide: { store.hide(application) },
                            moveBefore: { sourceID in
                                store.moveApplication(sourceID, before: application.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 24)
            }
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if WindowMode(rawValue: windowModeRaw) != .standard {
                            closeLauncher()
                        }
                    }
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    if WindowMode(rawValue: windowModeRaw) != .standard {
                        closeLauncher()
                    }
                }
            )
            .offset(x: pageAnimationOffset)
            .opacity(pageAnimationOpacity)
            .onChange(of: store.currentPage) {
                animatePageEntrance()
            }
            .scrollIndicators(.hidden)
        }
    }

    private func animatePageEntrance() {
        pageAnimationTask?.cancel()

        let direction = CGFloat(store.pageTransitionDirection)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            pageAnimationOffset = direction * 48
            pageAnimationOpacity = 0.68
        }

        pageAnimationTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.20)) {
                pageAnimationOffset = 0
                pageAnimationOpacity = 1
            }
        }
    }

    @ViewBuilder
    private var pageControls: some View {
        if store.pageCount > 1 && store.query.isEmpty {
            HStack(spacing: 9) {
                ForEach(0..<store.pageCount, id: \.self) { page in
                    Button {
                        store.setPage(page)
                    } label: {
                        Circle()
                            .fill(
                                page == store.currentPage
                                    ? Color.white
                                    : Color.white.opacity(0.34)
                            )
                            .frame(width: 7, height: 7)
                            .scaleEffect(page == store.currentPage ? 1.28 : 1)
                            .animation(.easeOut(duration: 0.16), value: store.currentPage)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("第 \(page + 1) 页")
                    .accessibilityValue(page == store.currentPage ? "当前页" : "")
                    .dropDestination(for: String.self) { items, _ in
                        guard let sourceID = items.first else { return false }
                        store.moveApplication(sourceID, toPage: page)
                        return true
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassSurface(in: Capsule())
            .accessibilityElement(children: .contain)
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }

    private func closeLauncher() {
        NotificationCenter.default.post(name: .launchDeckRequestClose, object: nil)
    }
}

private struct ApplicationTile: View {
    let application: ApplicationItem
    let isSelected: Bool
    let select: () -> Void
    let launch: () -> Void
    let hide: () -> Void
    let moveBefore: (String) -> Void
    @State private var isHovering = false
    @State private var isDropTarget = false

    var body: some View {
        Button(action: launch) {
            VStack(spacing: 10) {
                Image(nsImage: ApplicationIconCache.shared.icon(for: application.url))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 72, height: 72)
                    .shadow(color: .black.opacity(0.22), radius: 5, y: 3)

                Text(application.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 112)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(isSelected || isHovering || isDropTarget ? 0.20 : 0.09),
                                .white.opacity(0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(isSelected ? 0.85 : 0.34),
                                .white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .shadow(color: .black.opacity(0.09), radius: 6, y: 3)
            .scaleEffect(isHovering ? 1.04 : 1)
            .animation(.easeOut(duration: 0.14), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .simultaneousGesture(TapGesture().onEnded(select))
        .draggable(application.id)
        .dropDestination(for: String.self) { items, _ in
            guard let sourceID = items.first else { return false }
            moveBefore(sourceID)
            return true
        } isTargeted: {
            isDropTarget = $0
        }
        .help(application.name)
        .accessibilityLabel(application.name)
        .contextMenu {
            Button("打开", action: launch)
            Button("在 Finder 中显示") {
                NSWorkspace.shared.activateFileViewerSelecting([application.url])
            }
            Divider()
            Button("隐藏应用", action: hide)
        }
    }
}

private extension View {
    func glassSurface<S: InsettableShape>(in shape: S) -> some View {
        background(.ultraThinMaterial, in: shape)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.50), .white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
    }
}

private struct HiddenApplicationsView: View {
    @Bindable var store: ApplicationStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("隐藏的应用")
                    .font(.title2.bold())
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            if store.hiddenApplications.isEmpty {
                ContentUnavailableView(
                    "没有隐藏的应用",
                    systemImage: "eye",
                    description: Text("在应用图标的右键菜单中选择“隐藏应用”。")
                )
            } else {
                List(store.hiddenApplications) { application in
                    HStack(spacing: 12) {
                        Image(nsImage: ApplicationIconCache.shared.icon(for: application.url))
                            .resizable()
                            .frame(width: 32, height: 32)
                        Text(application.name)
                        Spacer()
                        Button("恢复") { store.restore(application) }
                    }
                }

                HStack {
                    Spacer()
                    Button("全部恢复") { store.restoreAllHiddenApplications() }
                }
                .padding()
            }
        }
        .frame(width: 520, height: 460)
    }
}

private struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

@MainActor
private final class ApplicationIconCache {
    static let shared = ApplicationIconCache()
    private let cache = NSCache<NSURL, NSImage>()

    func icon(for url: URL) -> NSImage {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache.setObject(icon, forKey: key)
        return icon
    }
}
