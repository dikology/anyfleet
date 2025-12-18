//
//  MarkdownParser.swift
//  anyfleet
//
//  Simple markdown parser for practice guides
//

import Foundation

// MARK: - Markdown Block

/// Represents a parsed markdown block
enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case listItem(String, level: Int)
}

// MARK: - Markdown Parser

enum MarkdownParser {
    /// Parse markdown content into structured blocks
    /// - Parameter markdown: The markdown string to parse
    /// - Returns: Array of markdown blocks
    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [MarkdownBlock] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if trimmed.isEmpty {
                continue
            }
            
            // Check for headings
            if trimmed.hasPrefix("#") {
                let level = trimmed.prefix(while: { $0 == "#" }).count
                let text = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    blocks.append(.heading(level: level, text: text))
                }
                continue
            }
            
            // Check for list items
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                blocks.append(.listItem(text, level: 0))
                continue
            }
            
            // Regular paragraph
            blocks.append(.paragraph(trimmed))
        }
        
        return blocks
    }
    
    /// Parse inline markdown formatting (bold, italic) into AttributedString
    /// - Parameter text: The text to parse
    /// - Returns: AttributedString with formatting applied
    static func parseInlineFormatting(_ text: String) -> AttributedString {
        // Use AttributedString's built-in markdown parsing for inline formatting
        if let attributed = try? AttributedString(markdown: text) {
            return attributed
        }
        return AttributedString(text)
    }
}

