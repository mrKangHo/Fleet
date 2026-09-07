import Foundation

/// 로컬 파일 시스템 기반 메모 영속성 스토리지 (Thread-safe Actor)
public actor LocalMemoStorage {
    private let fileURL: URL
    private var cache: [UUID: MemoItem] = [:]
    private var isLoaded = false

    public init(customDirectory: URL? = nil) {
        if let customDir = customDirectory {
            self.fileURL = customDir.appendingPathComponent("memos.json")
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("WorkManager", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("memos.json")
        }
    }

    private func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true

        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            let items = try JSONDecoder().decode([MemoItem].self, from: data)
            self.cache = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        } catch {
            print("[LocalMemoStorage] Failed to load memos: \(error)")
        }
    }

    private func persist() throws {
        let items = Array(cache.values)
        let data = try JSONEncoder().encode(items)
        try data.write(to: fileURL, options: .atomic)
    }

    public func getAllMemos() -> [MemoItem] {
        loadIfNeeded()
        return Array(cache.values)
    }

    public func getMemos(for repositoryId: Int) -> [MemoItem] {
        loadIfNeeded()
        return cache.values.filter { $0.repositoryId == repositoryId }
    }

    public func saveMemo(_ memo: MemoItem) throws {
        loadIfNeeded()
        cache[memo.id] = memo
        try persist()
    }

    public func deleteMemo(id: UUID) throws {
        loadIfNeeded()
        cache.removeValue(forKey: id)
        try persist()
    }

    public func getMemoCount(for repositoryId: Int) -> Int {
        loadIfNeeded()
        return cache.values.filter { $0.repositoryId == repositoryId }.count
    }

    public func getMemoCounts() -> [Int: Int] {
        loadIfNeeded()
        var counts: [Int: Int] = [:]
        for item in cache.values {
            counts[item.repositoryId, default: 0] += 1
        }
        return counts
    }
}
