//
//  ParsedMessageSegment.swift
//  ChatUI
//
//  Shared segment type for markdown parsers that split message text into renderable blocks.
//

enum ParsedMessageSegment: Hashable {
    case markdown(String)
    case chart(spec: ChartSpec, rawBlock: String)
    case map(spec: MapSpec, rawBlock: String)
    case media(MarkdownMediaPayload)
    case mermaid(source: String, rawBlock: String)
}
