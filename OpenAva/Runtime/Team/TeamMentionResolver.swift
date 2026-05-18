import ChatClient
import Foundation
import OSLog

private let mentionLogger = Logger(subsystem: "com.day1-labs.openava", category: "team.mention-resolver")

/// Determines which agent(s) should reply in a multi-agent team room using a lightweight LLM call.
///
/// The external resolver schema intentionally stays small:
///
///     {"addressed": ["Agent A", "Agent B"]}
///
/// `addressed` means "the agents who should produce visible replies in this turn, in reply order".
/// An empty array means "broadcast to all agents in the room's default order".
enum TeamMentionResolver {
    /// Returns the names of agents that should reply, in reply order.
    /// Empty means broadcast to all participants in the room's default order.
    static func resolveAddressedAgents(
        userMessage: String,
        agentNames: [String],
        using modelConfig: AppConfig.LLMModel
    ) async -> [String] {
        // Only resolve when there are multiple agents to choose from.
        guard agentNames.count > 1 else { return [] }

        let client = LLMChatClient(modelConfig: modelConfig)
        let nameList = agentNames.joined(separator: ", ")
        let requestBody = ChatRequestBody(
            messages: [
                .system(content: .text(systemPrompt)),
                .user(content: .text("Agent names, in default room order: \(nameList)\nMessage: \(userMessage)")),
            ],
            maxCompletionTokens: 256,
            temperature: 0
        )

        do {
            let response = try await client.chat(body: requestBody)
            let addressed = parseAddressed(from: response.text, agentNames: agentNames)
            mentionLogger.notice(
                "mention resolution: addressed=\(addressed.joined(separator: ","), privacy: .public)"
            )
            return addressed
        } catch {
            mentionLogger.notice("mention resolution failed, broadcasting: \(error, privacy: .public)")
            return []
        }
    }

    // MARK: - Internal (exposed for testing)

    static func parseAddressed(from text: String, agentNames: [String]) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}")
        else {
            return []
        }
        let jsonString = String(trimmed[start ... end])
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let addressed = json["addressed"] as? [String]
        else {
            return []
        }

        return canonicalAddressedNames(addressed, agentNames: agentNames)
    }

    // MARK: - Private

    private static func canonicalAddressedNames(_ addressed: [String], agentNames: [String]) -> [String] {
        var canonicalByLowercase: [String: String] = [:]
        for name in agentNames {
            let canonical = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !canonical.isEmpty else { continue }
            canonicalByLowercase[canonical.lowercased()] = canonical
        }

        var result: [String] = []
        var seen = Set<String>()
        for name in addressed {
            let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let canonical = canonicalByLowercase[normalized], !seen.contains(normalized) else {
                continue
            }
            seen.insert(normalized)
            result.append(canonical)
        }
        return result
    }

    private static let systemPrompt = """
    You are the routing resolver for a multi-agent team room.

    Your job: decide which agents should produce visible replies for THIS user turn, and in what order.

    Output schema:
    {"addressed": ["Exact Agent Name"]}

    Meaning:
    - `addressed` contains exact agent names from the provided list.
    - The array order is the reply order.
    - `addressed: []` means broadcast to all agents in the default room order.

    Rules:
    - Return ONLY one JSON object. No prose, no markdown.
    - Use exact agent names from the provided list. Never invent names.
    - If the user asks one or more specific agents to answer, list only those agents in the requested order.
    - If the user asks one agent to go first and asks others/everyone/the room to react, list the first agent first, then the remaining intended agents in default room order unless the user specifies another order.
    - If the user asks everyone/all agents/the room to answer and gives no exclusions or special order, return {"addressed": []}.
    - If the user asks everyone except some agents, list every non-excluded agent in default room order.
    - If the user gives roles or categories instead of names, select the best matching agents from the provided names when the intended agents are clear; otherwise return {"addressed": []}.
    - If the message is ordinary conversation with no routing restriction, return {"addressed": []}.
    """
}
