import Foundation

enum TeamTopologyKind: String, Codable, CaseIterable {
    case automatic
    case flat
    case tree
    case custom
}

struct TeamProfile: Codable, Equatable, Identifiable {
    private enum CodingKeys: String, CodingKey {
        case id
    }

    var id: String
    var name: String
    var emoji: String
    var description: String?
    var agentPoolIDs: [String]
    var defaultTopology: TeamTopologyKind
    var createdAt: Date
    var updatedAt: Date
    var selectedModelID: String?
    var thinkingStrength: ChatThinkingStrength
    var autoCompactEnabled: Bool
    var identityDocument: String?

    init(
        id: String = OpenAvaID.generate(.team),
        name: String,
        emoji: String = "👥",
        description: String? = nil,
        agentPoolIDs: [String],
        defaultTopology: TeamTopologyKind = .automatic,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        selectedModelID: String? = nil,
        thinkingStrength: ChatThinkingStrength = .medium,
        autoCompactEnabled: Bool = true,
        identityDocument: String? = nil
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        self.emoji = trimmedEmoji.isEmpty ? "👥" : trimmedEmoji
        self.description = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.agentPoolIDs = agentPoolIDs
        self.defaultTopology = defaultTopology
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.selectedModelID = selectedModelID
        self.thinkingStrength = thinkingStrength
        self.autoCompactEnabled = autoCompactEnabled
        self.identityDocument = identityDocument
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = ""
        emoji = "👥"
        description = nil
        agentPoolIDs = []
        defaultTopology = .automatic
        createdAt = Date()
        updatedAt = createdAt
        selectedModelID = nil
        thinkingStrength = .medium
        autoCompactEnabled = true
        identityDocument = nil
    }
}
