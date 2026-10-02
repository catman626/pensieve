import Foundation

struct NoteCard: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let relativePath: String
    let content: String
    let modifiedAt: Date?
}

enum CardClassification: String, Codable, Sendable {
    case unseen
    case reviewed
    case important
    case skipped
}

struct ReflectionEntry: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var text: String
    var createdAt = Date()
    var isIntegrated = false
    var integratedAt: Date?
}

struct CardMetadata: Codable, Hashable, Sendable {
    var classification: CardClassification = .unseen
    var tags: Set<String> = []
    var reflections: [ReflectionEntry] = []
    var lastViewedAt: Date?
    var extraAppearances = 0
}

struct PersistedAppState: Codable, Sendable {
    var metadata: [String: CardMetadata] = [:]
    var customTags: [String] = []
    var lastCardID: String?
    var newCardsSinceReplay = 0
}

enum BrowseFilter: Equatable, Sendable {
    case discovery
    case important
    case skipped
    case tag(String)

    var title: String {
        switch self {
        case .discovery: "发现"
        case .important: "重要"
        case .skipped: "已跳过"
        case .tag(let name): name
        }
    }
}

struct ReflectionRecord: Identifiable, Sendable {
    let cardID: String
    let noteTitle: String
    let relativePath: String
    let reflection: ReflectionEntry

    var id: UUID { reflection.id }
}
