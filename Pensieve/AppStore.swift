import Foundation
import Combine

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var notes: [NoteCard] = []
    @Published private(set) var persisted = PersistedAppState()
    @Published private(set) var currentCardID: String?
    @Published private(set) var folderURL: URL?
    @Published private(set) var isScanning = false
    @Published var activeFilter: BrowseFilter = .discovery
    @Published var errorMessage: String?

    private let bookmarkKey = "pensieve.vaultBookmark"
    private var hasStarted = false

    var currentCard: NoteCard? {
        guard let currentCardID else { return nil }
        return notes.first { $0.id == currentCardID }
    }

    var folderName: String {
        folderURL?.lastPathComponent ?? "未选择"
    }

    var unseenCount: Int {
        notes.filter { metadata(for: $0.id).classification == .unseen }.count
    }

    var importantCount: Int {
        notes.filter { metadata(for: $0.id).classification == .important }.count
    }

    var skippedCount: Int {
        notes.filter { metadata(for: $0.id).classification == .skipped }.count
    }

    var customTags: [String] {
        persisted.customTags
    }

    var currentMetadata: CardMetadata {
        guard let currentCardID else { return CardMetadata() }
        return metadata(for: currentCardID)
    }

    var pendingReflectionCount: Int {
        persisted.metadata.values
            .flatMap(\.reflections)
            .filter { !$0.isIntegrated }
            .count
    }

    var reflectionRecords: [ReflectionRecord] {
        persisted.metadata.flatMap { cardID, metadata -> [ReflectionRecord] in
            guard let note = notes.first(where: { $0.id == cardID }) else { return [] }
            return metadata.reflections.map {
                ReflectionRecord(
                    cardID: cardID,
                    noteTitle: note.title,
                    relativePath: note.relativePath,
                    reflection: $0
                )
            }
        }
        .sorted { $0.reflection.createdAt > $1.reflection.createdAt }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        loadState()
        restoreFolderBookmark()
    }

    func selectFolder(_ url: URL) {
        do {
            let bookmark = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
            folderURL = url
            Task { await refresh() }
        } catch {
            errorMessage = "无法保存文件夹权限：\(error.localizedDescription)"
        }
    }

    func refresh() async {
        guard let folderURL else { return }
        isScanning = true
        defer { isScanning = false }

        do {
            notes = try await VaultScanner.scan(folderURL: folderURL)
            reconcileCurrentCard()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func classifyCurrent(as classification: CardClassification) {
        guard let card = currentCard else { return }
        var value = metadata(for: card.id)
        let wasUnseen = value.classification == .unseen
        value.classification = classification
        value.lastViewedAt = Date()
        persisted.metadata[card.id] = value

        if wasUnseen {
            persisted.newCardsSinceReplay += 1
        }

        advance(after: card.id)
        saveState()
    }

    func markCurrentViewed() {
        guard let card = currentCard else { return }
        var value = metadata(for: card.id)
        value.lastViewedAt = Date()
        persisted.metadata[card.id] = value
        persisted.lastCardID = card.id
        saveState()
    }

    func toggleTag(_ tag: String) {
        guard let card = currentCard else { return }
        var value = metadata(for: card.id)
        if value.tags.contains(tag) {
            value.tags.remove(tag)
        } else {
            value.tags.insert(tag)
        }
        persisted.metadata[card.id] = value
        saveState()
    }

    func createTag(_ rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if !persisted.customTags.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            persisted.customTags.append(name)
            persisted.customTags.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        }
        toggleTag(name)
        saveState()
    }

    func addReflection(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let card = currentCard else { return }
        var value = metadata(for: card.id)
        value.reflections.append(ReflectionEntry(text: text))
        persisted.metadata[card.id] = value
        saveState()
    }

    func setReflectionIntegrated(cardID: String, reflectionID: UUID, integrated: Bool) {
        guard var value = persisted.metadata[cardID],
              let index = value.reflections.firstIndex(where: { $0.id == reflectionID }) else {
            return
        }
        value.reflections[index].isIntegrated = integrated
        value.reflections[index].integratedAt = integrated ? Date() : nil
        persisted.metadata[cardID] = value
        saveState()
    }

    func setFilter(_ filter: BrowseFilter) {
        activeFilter = filter
        let eligible = eligibleNotes(for: filter)
        if let current = currentCard, eligible.contains(where: { $0.id == current.id }) {
            return
        }
        currentCardID = eligible.first?.id
        persisted.lastCardID = currentCardID
        saveState()
    }

    func count(for tag: String) -> Int {
        notes.filter { metadata(for: $0.id).tags.contains(tag) }.count
    }

    func metadata(for cardID: String) -> CardMetadata {
        persisted.metadata[cardID] ?? CardMetadata()
    }

    private func restoreFolderBookmark() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            folderURL = url
            if isStale {
                selectFolder(url)
            } else {
                Task { await refresh() }
            }
        } catch {
            errorMessage = "之前选择的文件夹权限已失效，请重新选择。"
        }
    }

    private func reconcileCurrentCard() {
        let availableIDs = Set(notes.map(\.id))

        if let lastCardID = persisted.lastCardID, availableIDs.contains(lastCardID) {
            currentCardID = lastCardID
        } else {
            currentCardID = eligibleNotes(for: activeFilter).first?.id
            persisted.lastCardID = currentCardID
        }
        saveState()
    }

    private func advance(after previousID: String) {
        if activeFilter != .discovery {
            let eligible = eligibleNotes(for: activeFilter)
            guard !eligible.isEmpty else {
                currentCardID = nil
                persisted.lastCardID = nil
                return
            }

            if let index = eligible.firstIndex(where: { $0.id == previousID }) {
                currentCardID = eligible[(index + 1) % eligible.count].id
            } else {
                currentCardID = eligible.first?.id
            }
            persisted.lastCardID = currentCardID
            return
        }

        let important = notes.filter {
            metadata(for: $0.id).classification == .important && $0.id != previousID
        }

        if persisted.newCardsSinceReplay >= 8, let replay = important.randomElement() {
            persisted.newCardsSinceReplay = 0
            var replayMetadata = metadata(for: replay.id)
            replayMetadata.extraAppearances += 1
            persisted.metadata[replay.id] = replayMetadata
            currentCardID = replay.id
            persisted.lastCardID = replay.id
            return
        }

        let unseen = notes.filter { metadata(for: $0.id).classification == .unseen }
        if let next = nextNote(after: previousID, in: unseen) {
            currentCardID = next.id
        } else if let replay = notes.filter({ metadata(for: $0.id).classification == .important }).randomElement() {
            var replayMetadata = metadata(for: replay.id)
            replayMetadata.extraAppearances += 1
            persisted.metadata[replay.id] = replayMetadata
            currentCardID = replay.id
        } else {
            currentCardID = nil
        }
        persisted.lastCardID = currentCardID
    }

    private func nextNote(after previousID: String, in candidates: [NoteCard]) -> NoteCard? {
        guard !candidates.isEmpty else { return nil }
        guard let previousIndex = notes.firstIndex(where: { $0.id == previousID }) else {
            return candidates.first
        }

        let candidateIDs = Set(candidates.map(\.id))
        for offset in 1...notes.count {
            let note = notes[(previousIndex + offset) % notes.count]
            if candidateIDs.contains(note.id) {
                return note
            }
        }
        return candidates.first
    }

    private func eligibleNotes(for filter: BrowseFilter) -> [NoteCard] {
        switch filter {
        case .discovery:
            let unseen = notes.filter { metadata(for: $0.id).classification == .unseen }
            if !unseen.isEmpty { return unseen }
            return notes.filter { metadata(for: $0.id).classification == .important }
        case .important:
            return notes.filter { metadata(for: $0.id).classification == .important }
        case .skipped:
            return notes.filter { metadata(for: $0.id).classification == .skipped }
        case .tag(let name):
            return notes.filter { metadata(for: $0.id).tags.contains(name) }
        }
    }

    private func loadState() {
        guard let data = try? Data(contentsOf: stateFileURL),
              let decoded = try? JSONDecoder().decode(PersistedAppState.self, from: data) else {
            return
        }
        persisted = decoded
        currentCardID = decoded.lastCardID
    }

    private func saveState() {
        do {
            let directory = stateFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(persisted)
            try data.write(to: stateFileURL, options: .atomic)
        } catch {
            errorMessage = "保存本地状态失败：\(error.localizedDescription)"
        }
    }

    private var stateFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Pensieve", isDirectory: true)
            .appendingPathComponent("state.json")
    }
}
