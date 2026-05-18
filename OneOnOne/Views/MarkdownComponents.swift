//
//  MarkdownComponents.swift
//  OneOnOne
//
//  Markdown rendering components for rich text display in notes.
//  Supports fenced code blocks, inline code, bold, italic, and bullet lists.
//  Created by Jordan Koch on 2026-04-13.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

// MARK: - Markdown Block Types

enum MarkdownBlock {
    case text(String)
    case codeBlock(language: String?, code: String)
    case bulletList([String])
}

// MARK: - Block-Level Parser

struct MarkdownParser {
    static func parse(_ input: String) -> [MarkdownBlock] {
        guard !input.isEmpty else { return [] }

        var blocks: [MarkdownBlock] = []
        let lines = input.components(separatedBy: "\n")
        var i = 0
        var currentTextLines: [String] = []
        var currentBulletItems: [String] = []

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                // Flush accumulated text and bullets
                flushText(&currentTextLines, into: &blocks)
                flushBullets(&currentBulletItems, into: &blocks)

                // Extract optional language label
                let afterFence = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                let language = afterFence.isEmpty ? nil : afterFence

                // Collect code lines until closing fence
                var codeLines: [String] = []
                i += 1
                while i < lines.count {
                    if lines[i].trimmingCharacters(in: .whitespaces) == "```" {
                        break
                    }
                    codeLines.append(lines[i])
                    i += 1
                }

                blocks.append(.codeBlock(language: language, code: codeLines.joined(separator: "\n")))

            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                // Bullet item — flush text first
                flushText(&currentTextLines, into: &blocks)
                currentBulletItems.append(String(trimmed.dropFirst(2)))

            } else {
                // Regular text line — flush bullets first
                flushBullets(&currentBulletItems, into: &blocks)
                currentTextLines.append(line)
            }

            i += 1
        }

        flushText(&currentTextLines, into: &blocks)
        flushBullets(&currentBulletItems, into: &blocks)

        return blocks
    }

    private static func flushText(_ lines: inout [String], into blocks: inout [MarkdownBlock]) {
        let joined = lines.joined(separator: "\n").trimmingCharacters(in: .newlines)
        if !joined.isEmpty {
            blocks.append(.text(joined))
        }
        lines.removeAll()
    }

    private static func flushBullets(_ items: inout [String], into blocks: inout [MarkdownBlock]) {
        if !items.isEmpty {
            blocks.append(.bulletList(items))
            items.removeAll()
        }
    }
}

// MARK: - Markdown Notes View (Read-Only Renderer)

struct MarkdownNotesView: View {
    let text: String
    let fontSize: CGFloat

    init(_ text: String, fontSize: CGFloat = 14) {
        self.text = text
        self.fontSize = fontSize
    }

    var body: some View {
        let blocks = MarkdownParser.parse(text)
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let content):
                    InlineMarkdownText(content, fontSize: fontSize)

                case .codeBlock(let language, let code):
                    CodeBlockView(code: code, language: language)

                case .bulletList(let items):
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .font(.system(size: fontSize))
                                    .foregroundColor(ModernColors.accent)
                                InlineMarkdownText(item, fontSize: fontSize)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Inline Markdown Text (bold, italic, inline code via AttributedString)

struct InlineMarkdownText: View {
    let text: String
    let fontSize: CGFloat

    init(_ text: String, fontSize: CGFloat = 14) {
        self.text = text
        self.fontSize = fontSize
    }

    var body: some View {
        if let styled = styledMarkdown() {
            Text(styled)
                .textSelection(.enabled)
        } else {
            Text(text)
                .font(.system(size: fontSize))
                .foregroundColor(ModernColors.textPrimary)
                .textSelection(.enabled)
        }
    }

    private func styledMarkdown() -> AttributedString? {
        guard var attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return nil
        }

        // Base styling
        attributed.font = .system(size: fontSize)
        attributed.foregroundColor = ModernColors.textPrimary

        // Style inline code runs with monospace + accent color + background
        for run in attributed.runs {
            if let intent = run.inlinePresentationIntent, intent.contains(.code) {
                attributed[run.range].font = Font.system(size: fontSize - 1, design: .monospaced)
                attributed[run.range].foregroundColor = ModernColors.cyan
                attributed[run.range].backgroundColor = Color.white.opacity(0.1)
            }
        }

        return attributed
    }
}

// MARK: - Code Block View

struct CodeBlockView: View {
    let code: String
    let language: String?
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: language label + copy button
            HStack {
                if let language = language {
                    Text(language)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(ModernColors.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(4)
                }

                Spacer()

                Button {
                    copyToClipboard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied" : "Copy")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(copied ? ModernColors.accentGreen : ModernColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Code content with horizontal scroll for long lines
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(ModernColors.textPrimary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .background(Color.black.opacity(0.3))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func copyToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #else
        UIPasteboard.general.string = code
        #endif

        withAnimation(.easeInOut(duration: 0.2)) {
            copied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                copied = false
            }
        }
    }
}

// MARK: - Formatting Toolbar

struct FormattingToolbar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 4) {
            toolbarButton(systemImage: "bold") {
                text.append("**text**")
            }

            toolbarButton(systemImage: "italic") {
                text.append("*text*")
            }

            toolbarButton(systemImage: "chevron.left.forwardslash.chevron.right") {
                text.append("`code`")
            }

            Divider()
                .frame(height: 18)
                .background(Color.white.opacity(0.2))
                .padding(.horizontal, 2)

            toolbarButton(systemImage: "curlybraces") {
                let prefix = text.isEmpty || text.hasSuffix("\n") ? "" : "\n"
                text.append("\(prefix)```\n\n```")
            }

            toolbarButton(systemImage: "list.bullet") {
                let prefix = text.isEmpty || text.hasSuffix("\n") ? "" : "\n"
                text.append("\(prefix)- ")
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .cornerRadius(8)
    }

    private func toolbarButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ModernColors.textSecondary)
                .frame(width: 30, height: 26)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Rich Notes Editor (Toolbar + TextEditor)

struct RichNotesEditor: View {
    @Binding var text: String
    var minHeight: CGFloat = 200

    var body: some View {
        VStack(spacing: 8) {
            FormattingToolbar(text: $text)

            TextEditor(text: $text)
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
        }
    }
}
