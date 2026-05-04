//
//  MermaidMarkdownParser.swift
//  ChatUI
//
//  Splits markdown into plain markdown segments and Mermaid diagram segments.
//

import Foundation

enum MermaidMarkdownParser {
    private static let mermaidCodeBlockRegex: NSRegularExpression = {
        // Match fenced code blocks like ```mermaid ... ``` or ~~~mermaid ... ~~~.
        // Supports optional indentation and both LF/CRLF line endings.
        let pattern = "(?ism)^[ \\t]*(```|~~~)mermaid(?:[ \\t]+[^\\r\\n]*)?\\r?\\n(.*?)(?:\\r?\\n)?[ \\t]*\\1[ \\t]*(?=\\r?\\n|$)"
        return try! NSRegularExpression(pattern: pattern)
    }()

    static func parseSegments(from markdown: String) -> [ParsedMessageSegment] {
        let nsRange = NSRange(markdown.startIndex ..< markdown.endIndex, in: markdown)
        let matches = mermaidCodeBlockRegex.matches(in: markdown, options: [], range: nsRange)
        guard !matches.isEmpty else {
            return [.markdown(markdown)]
        }

        var segments: [ParsedMessageSegment] = []
        var cursor = markdown.startIndex

        for match in matches {
            guard let fullRange = Range(match.range, in: markdown),
                  let payloadRange = Range(match.range(at: 2), in: markdown)
            else {
                continue
            }

            if cursor < fullRange.lowerBound {
                segments.append(.markdown(String(markdown[cursor ..< fullRange.lowerBound])))
            }

            let rawBlock = String(markdown[fullRange])
            let source = String(markdown[payloadRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if source.isEmpty {
                segments.append(.markdown(rawBlock))
            } else {
                segments.append(.mermaid(source: source, rawBlock: rawBlock))
            }

            cursor = fullRange.upperBound
        }

        if cursor < markdown.endIndex {
            segments.append(.markdown(String(markdown[cursor...])))
        }

        return segments
    }
}
