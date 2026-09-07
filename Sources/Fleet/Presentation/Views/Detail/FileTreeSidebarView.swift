import SwiftUI
import AppKit

// MARK: - File Tree Node Model
public struct FileTreeNode: Identifiable, Hashable {
    public let id: String // absolute path
    public let name: String
    public let url: URL
    public let isDirectory: Bool
    public let fileExtension: String
    public let size: Int64
    public let modificationDate: Date?
    public var children: [FileTreeNode]?

    public init(url: URL, isDirectory: Bool, children: [FileTreeNode]? = nil) {
        self.id = url.path
        self.name = url.lastPathComponent
        self.url = url
        self.isDirectory = isDirectory
        self.fileExtension = url.pathExtension.lowercased()
        self.children = children

        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        self.size = Int64(values?.fileSize ?? 0)
        self.modificationDate = values?.contentModificationDate
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: FileTreeNode, rhs: FileTreeNode) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - File Type Icon Helper
public enum FileTypeIcon {
    case folder(isOpen: Bool)
    case swift
    case markdown
    case json
    case code
    case shell
    case image
    case config
    case git
    case document
    case generic

    public var systemName: String {
        switch self {
        case .folder(let isOpen): return isOpen ? "folder.fill" : "folder.fill"
        case .swift: return "swift"
        case .markdown: return "doc.text.fill"
        case .json: return "curlybraces"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .shell: return "terminal.fill"
        case .image: return "photo.fill"
        case .config: return "gearshape.fill"
        case .git: return "arrow.triangle.branch"
        case .document: return "doc.text"
        case .generic: return "doc.fill"
        }
    }

    public var color: Color {
        switch self {
        case .folder: return Color.accentColor
        case .swift: return Color.orange
        case .markdown: return Color.blue
        case .json: return Color.yellow
        case .code: return Color.purple
        case .shell: return Color.green
        case .image: return Color.pink
        case .config: return Color.gray
        case .git: return Color.red.opacity(0.8)
        case .document: return Color.secondary
        case .generic: return Color.secondary.opacity(0.7)
        }
    }

    public static func forFile(name: String, isDirectory: Bool, isOpen: Bool = false) -> FileTypeIcon {
        if isDirectory {
            return .folder(isOpen: isOpen)
        }
        let lower = name.lowercased()
        if lower.hasPrefix(".git") { return .git }
        if lower == "package.swift" { return .swift }
        if lower.hasSuffix(".swift") { return .swift }
        if lower.hasSuffix(".md") || lower.hasSuffix(".markdown") { return .markdown }
        if lower.hasSuffix(".json") { return .json }
        if lower.hasSuffix(".sh") || lower.hasSuffix(".zsh") || lower.hasSuffix(".bash") { return .shell }
        if lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".svg") || lower.hasSuffix(".ico") || lower.hasSuffix(".webp") { return .image }
        if lower.hasSuffix(".yml") || lower.hasSuffix(".yaml") || lower.hasSuffix(".toml") || lower.hasSuffix(".xml") || lower.hasSuffix(".plist") || lower.hasSuffix(".env") { return .config }
        if lower.hasSuffix(".js") || lower.hasSuffix(".ts") || lower.hasSuffix(".py") || lower.hasSuffix(".rb") || lower.hasSuffix(".go") || lower.hasSuffix(".rs") || lower.hasSuffix(".c") || lower.hasSuffix(".cpp") || lower.hasSuffix(".h") { return .code }
        if lower.hasSuffix(".txt") || lower.hasSuffix(".log") || lower.hasSuffix(".pdf") { return .document }
        return .generic
    }
}

// MARK: - File Tree ViewModel
@MainActor
public final class FileTreeViewModel: ObservableObject {
    @Published public var rootNodes: [FileTreeNode] = []
    @Published public var expandedPaths: Set<String> = []
    @Published public var selectedPath: String? = nil
    @Published public var searchQuery: String = ""
    @Published public var isSearchActive: Bool = false
    @Published public var showHiddenFiles: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var currentRootPath: String? = nil

    private let ignoredFolderNames: Set<String> = [
        ".git", ".build", ".swiftpm", "DerivedData", "node_modules", "Pods", ".DS_Store", "xcuserdata", ".trash"
    ]

    public var totalItemCount: Int {
        countNodes(rootNodes)
    }

    private func countNodes(_ nodes: [FileTreeNode]) -> Int {
        var count = nodes.count
        for node in nodes {
            if let children = node.children {
                count += countNodes(children)
            }
        }
        return count
    }

    public func loadDirectory(path: String?) {
        guard let path = path, !path.isEmpty else {
            self.rootNodes = []
            self.currentRootPath = nil
            return
        }

        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            self.rootNodes = []
            self.currentRootPath = nil
            return
        }

        self.currentRootPath = path
        self.isLoading = true

        let showHidden = self.showHiddenFiles
        let ignored = self.ignoredFolderNames
        let rootUrl = URL(fileURLWithPath: path)

        Task.detached(priority: .userInitiated) {
            let nodes = Self.scanDirectory(
                at: rootUrl,
                showHidden: showHidden,
                ignoredNames: ignored,
                maxDepth: 4,
                currentDepth: 0
            )

            await MainActor.run {
                self.rootNodes = nodes
                self.isLoading = false
                // 루트 직하위 폴더 중 1단계는 기본으로 펼침
                if self.expandedPaths.isEmpty {
                    for node in nodes where node.isDirectory {
                        self.expandedPaths.insert(node.id)
                    }
                }
            }
        }
    }

    nonisolated public static func scanDirectory(
        at url: URL,
        showHidden: Bool,
        ignoredNames: Set<String>,
        maxDepth: Int,
        currentDepth: Int
    ) -> [FileTreeNode] {
        let fileManager = FileManager.default
        var options: FileManager.DirectoryEnumerationOptions = []
        if !showHidden {
            options.insert(.skipsHiddenFiles)
        }

        guard let urls = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: options
        ) else {
            return []
        }

        var nodes: [FileTreeNode] = []

        for itemUrl in urls {
            let name = itemUrl.lastPathComponent

            // 불필요하거나 대용량 캐시 디렉토리 스킵
            if ignoredNames.contains(name) && (!showHidden || name == ".build" || name == "node_modules" || name == "DerivedData" || name == ".DS_Store") {
                continue
            }

            let isDir = (try? itemUrl.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            var childNodes: [FileTreeNode]? = nil
            if isDir {
                if currentDepth < maxDepth {
                    childNodes = scanDirectory(
                        at: itemUrl,
                        showHidden: showHidden,
                        ignoredNames: ignoredNames,
                        maxDepth: maxDepth,
                        currentDepth: currentDepth + 1
                    )
                } else {
                    childNodes = []
                }
            }

            let node = FileTreeNode(url: itemUrl, isDirectory: isDir, children: childNodes)
            nodes.append(node)
        }

        return nodes.sorted { a, b in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory && !b.isDirectory
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    public func toggleFolder(_ node: FileTreeNode) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if expandedPaths.contains(node.id) {
                expandedPaths.remove(node.id)
            } else {
                expandedPaths.insert(node.id)
            }
        }
    }

    public func expandAll() {
        var allDirs = Set<String>()
        collectDirectoryPaths(from: rootNodes, into: &allDirs)
        withAnimation(.easeInOut(duration: 0.2)) {
            self.expandedPaths = allDirs
        }
    }

    private func collectDirectoryPaths(from nodes: [FileTreeNode], into paths: inout Set<String>) {
        for node in nodes where node.isDirectory {
            paths.insert(node.id)
            if let children = node.children {
                collectDirectoryPaths(from: children, into: &paths)
            }
        }
    }

    public func collapseAll() {
        withAnimation(.easeInOut(duration: 0.2)) {
            self.expandedPaths.removeAll()
        }
    }

    public func refresh() {
        loadDirectory(path: currentRootPath)
    }

    public func toggleHiddenFiles() {
        self.showHiddenFiles.toggle()
        refresh()
    }
}

// MARK: - File Tree Sidebar View
public struct FileTreeSidebarView: View {
    public let rootPath: String?
    public let onChooseFolder: () -> Void
    public let onOpenFile: (URL) -> Void
    public let onRevealInFinder: (URL) -> Void
    public let onOpenInTerminal: (String) -> Void
    public let onClose: () -> Void

    @StateObject private var treeViewModel = FileTreeViewModel()
    @Binding public var sidebarWidth: Double
    @State private var isDraggingResize = false

    public init(
        rootPath: String?,
        sidebarWidth: Binding<Double>,
        onChooseFolder: @escaping () -> Void,
        onOpenFile: @escaping (URL) -> Void,
        onRevealInFinder: @escaping (URL) -> Void,
        onOpenInTerminal: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.rootPath = rootPath
        self._sidebarWidth = sidebarWidth
        self.onChooseFolder = onChooseFolder
        self.onOpenFile = onOpenFile
        self.onRevealInFinder = onRevealInFinder
        self.onOpenInTerminal = onOpenInTerminal
        self.onClose = onClose
    }

    public var body: some View {
        HStack(spacing: 0) {
            // MARK: - 좌측 리사이즈 드래그 핸들러
            resizeHandle

            // MARK: - 사이드바 본체
            VStack(spacing: 0) {
                // 상단 헤더 툴바
                sidebarHeader

                // 검색 바 (토글 시)
                if treeViewModel.isSearchActive {
                    searchBarView
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Divider()

                // 트리 컨텐츠 영역
                if rootPath == nil || rootPath?.isEmpty == true {
                    emptyFolderView
                } else if treeViewModel.isLoading && treeViewModel.rootNodes.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("디렉토리 탐색 중...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredNodes.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(treeViewModel.searchQuery.isEmpty ? "디렉토리가 비어 있습니다" : "검색 결과가 없습니다")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    fileTreeView
                }

                Divider()

                // 하단 정보 풋터
                sidebarFooter
            }
            .background(AppTheme.stitchContainerLowest)
        }
        .frame(width: max(220, min(sidebarWidth, 550)))
        .onAppear {
            treeViewModel.loadDirectory(path: rootPath)
        }
        .onChange(of: rootPath) { _, newPath in
            treeViewModel.loadDirectory(path: newPath)
        }
    }

    // MARK: - Resize Handle
    private var resizeHandle: some View {
        Rectangle()
            .fill(isDraggingResize ? Color.accentColor : Color.primary.opacity(0.08))
            .frame(width: 4)
            .overlay(
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 10)
                    .contentShape(Rectangle())
            )
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { val in
                        isDraggingResize = true
                        let delta = -val.translation.width
                        let target = sidebarWidth + Double(delta)
                        sidebarWidth = max(220, min(target, 550))
                    }
                    .onEnded { _ in
                        isDraggingResize = false
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    // MARK: - Sidebar Header
    private var sidebarHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundColor(.accentColor)

            let folderName = rootPath.flatMap { URL(fileURLWithPath: $0).lastPathComponent } ?? "로컬 작업 디렉토리"
            Text(folderName)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // 검색 토글
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    treeViewModel.isSearchActive.toggle()
                    if !treeViewModel.isSearchActive {
                        treeViewModel.searchQuery = ""
                    }
                }
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(treeViewModel.isSearchActive ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("파일 검색")

            // 숨김 파일 토글
            Button(action: { treeViewModel.toggleHiddenFiles() }) {
                Image(systemName: treeViewModel.showHiddenFiles ? "eye.fill" : "eye.slash")
                    .font(.system(size: 11))
                    .foregroundColor(treeViewModel.showHiddenFiles ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(treeViewModel.showHiddenFiles ? "숨김 파일 감추기" : "숨김 파일 표시")

            // 모두 접기
            Button(action: { treeViewModel.collapseAll() }) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("모든 폴더 접기")

            // 새로고침
            Button(action: { treeViewModel.refresh() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("디렉토리 새로고침")

            // 사이드바 닫기
            Button(action: onClose) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("파일 탐색기 닫기")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.stitchElevated)
    }

    // MARK: - Search Bar
    private var searchBarView: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            TextField("파일명 검색...", text: $treeViewModel.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 11))

            if !treeViewModel.searchQuery.isEmpty {
                Button(action: { treeViewModel.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.stitchContainer)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(AppTheme.stitchBorder, lineWidth: 1)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - Filtered Nodes
    private var filteredNodes: [FileTreeNode] {
        let query = treeViewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return treeViewModel.rootNodes
        }
        return filterNodes(treeViewModel.rootNodes, matching: query)
    }

    private func filterNodes(_ nodes: [FileTreeNode], matching query: String) -> [FileTreeNode] {
        var results: [FileTreeNode] = []
        for node in nodes {
            if node.isDirectory {
                let matchedChildren = node.children.map { filterNodes($0, matching: query) } ?? []
                let nameMatches = node.name.localizedCaseInsensitiveContains(query)
                if nameMatches || !matchedChildren.isEmpty {
                    var copy = node
                    copy.children = matchedChildren
                    results.append(copy)
                }
            } else {
                if node.name.localizedCaseInsensitiveContains(query) {
                    results.append(node)
                }
            }
        }
        return results
    }

    // MARK: - File Tree View
    private var fileTreeView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(filteredNodes) { node in
                    FileTreeNodeRow(
                        node: node,
                        level: 0,
                        viewModel: treeViewModel,
                        onOpenFile: onOpenFile,
                        onRevealInFinder: onRevealInFinder,
                        onOpenInTerminal: onOpenInTerminal
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Empty Folder View
    private var emptyFolderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 36))
                .foregroundColor(AppTheme.warningAmber)

            Text("로컬 폴더 미연결")
                .font(.system(size: 12, weight: .bold))

            Text("저장소의 로컬 디렉토리를 연결하면\n소스 코드 및 파일 트리를 탐색할 수 있습니다.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button("로컬 폴더 연결...") {
                onChooseFolder()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }

    // MARK: - Sidebar Footer
    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let path = rootPath {
                HStack(spacing: 5) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.accentColor)
                    Text(path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
            }

            HStack(spacing: 8) {
                if let path = rootPath {
                    Button(action: { onRevealInFinder(URL(fileURLWithPath: path)) }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 9))
                            Text("Finder")
                                .font(.system(size: 10))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .help("Finder에서 로컬 폴더 열기")

                    Button(action: { onOpenInTerminal(path) }) {
                        HStack(spacing: 3) {
                            Image(systemName: "terminal")
                                .font(.system(size: 9))
                            Text("터미널")
                                .font(.system(size: 10))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .help("내장 터미널에서 이 폴더로 이동")
                }

                Spacer()

                Button(rootPath == nil ? "로컬 폴더 연결..." : "폴더 변경") {
                    onChooseFolder()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppTheme.stitchElevated)
    }
}

// MARK: - Recursive File Tree Node Row
private struct FileTreeNodeRow: View {
    let node: FileTreeNode
    let level: Int
    @ObservedObject var viewModel: FileTreeViewModel
    let onOpenFile: (URL) -> Void
    let onRevealInFinder: (URL) -> Void
    let onOpenInTerminal: (String) -> Void

    @State private var isHovered: Bool = false

    private var isExpanded: Bool {
        // 검색 중일 때는 검색 결과 매칭된 디렉토리를 자동으로 펼쳐 보여줌
        if !viewModel.searchQuery.isEmpty {
            return true
        }
        return viewModel.expandedPaths.contains(node.id)
    }

    private var isSelected: Bool {
        viewModel.selectedPath == node.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // 현재 노드 행
            HStack(spacing: 4) {
                // 들여쓰기
                Spacer()
                    .frame(width: CGFloat(level) * 13)

                // 폴더 화살표 or 파일 공백
                if node.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 12, height: 12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.toggleFolder(node)
                        }
                } else {
                    Spacer()
                        .frame(width: 12)
                }

                // 파일/폴더 아이콘
                let icon = FileTypeIcon.forFile(name: node.name, isDirectory: node.isDirectory, isOpen: isExpanded)
                Image(systemName: icon.systemName)
                    .font(.system(size: 11))
                    .foregroundColor(icon.color)
                    .frame(width: 14)

                // 파일/폴더 이름
                Text(node.name)
                    .font(.system(size: 11, design: .default))
                    .foregroundColor(isSelected ? .white : (node.isDirectory ? .primary : .primary.opacity(0.85)))
                    .fontWeight(node.isDirectory ? .medium : .regular)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // 파일 크기 뱃지 (마우스 호버 시 또는 파일일 때 은은하게)
                if !node.isDirectory && isHovered {
                    Text(formatFileSize(node.size))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .padding(.vertical, 3)
            .padding(.trailing, 8)
            .padding(.leading, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                self.isHovered = hovering
            }
            .onTapGesture {
                viewModel.selectedPath = node.id
                if node.isDirectory {
                    viewModel.toggleFolder(node)
                }
            }
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    if node.isDirectory {
                        viewModel.toggleFolder(node)
                    } else {
                        onOpenFile(node.url)
                    }
                }
            )
            .contextMenu {
                Button("기본 앱으로 열기") {
                    onOpenFile(node.url)
                }

                Button("Finder에서 보기") {
                    onRevealInFinder(node.url)
                }

                Divider()

                Button("터미널에서 열기") {
                    onOpenInTerminal(node.url.path)
                }

                Button("경로 복사") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(node.url.path, forType: .string)
                }
            }

            // 하위 노드 (폴더가 펼쳐져 있고 자식이 있는 경우)
            if node.isDirectory && isExpanded, let children = node.children {
                ForEach(children) { child in
                    FileTreeNodeRow(
                        node: child,
                        level: level + 1,
                        viewModel: viewModel,
                        onOpenFile: onOpenFile,
                        onRevealInFinder: onRevealInFinder,
                        onOpenInTerminal: onOpenInTerminal
                    )
                }
            }
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes)B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.0fK", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1fM", Double(bytes) / (1024.0 * 1024.0))
        }
    }
}
