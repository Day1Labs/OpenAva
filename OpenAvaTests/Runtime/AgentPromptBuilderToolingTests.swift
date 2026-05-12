import XCTest
@testable import OpenAva

final class AgentPromptBuilderToolingTests: XCTestCase {
    func testPromptBuilderDoesNotIncludeBashSpecificSingleLineGuidance() {
        let prompt = AgentPromptBuilder.composeSystemPrompt(
            baseSystemPrompt: nil,
            context: nil,
            skillCatalog: [],
            rootDirectory: nil
        )

        XCTAssertFalse(prompt.contains("For the `bash` tool, `command` must be a single line."))
    }

    #if os(macOS) || targetEnvironment(macCatalyst)
        func testBashToolDefinitionDescribesSingleLineCommandContract() throws {
            let definition = try XCTUnwrap(BashService().toolDefinitions().first { $0.functionName == "bash" })

            XCTAssertTrue(definition.description.contains("single-line shell command"))
            XCTAssertTrue(definition.description.contains("Do not use newline-separated commands"))

            let schema = try XCTUnwrap(definition.parametersSchema.value as? [String: Any])
            let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
            let command = try XCTUnwrap(properties["command"] as? [String: Any])
            let description = try XCTUnwrap(command["description"] as? String)

            XCTAssertTrue(description.contains("Single-line shell command"))
            XCTAssertTrue(description.contains("Do not include newline-separated commands"))
            XCTAssertTrue(description.contains("use `&&`"))
            XCTAssertTrue(description.contains("`;`"))
        }
    #endif
}
