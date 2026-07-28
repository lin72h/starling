// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

// MARK: - EditorBuffer

/// Plain-text document model: an array of lines plus a caret. All column
/// arithmetic is in `Character` counts (grapheme clusters), matching what a
/// monospace `Text` run renders as one cell.
/// Per-paragraph formatting (TextEdit-style: alignment + face toggles apply
/// to whole paragraphs; plain-text save drops them).
struct ParagraphAttrs: Equatable {
    enum Align { case left, center, right }
    var align: Align = .left
    var bold = false
    var italic = false
    var underline = false
}

struct EditorBuffer {
    private(set) var lines: [String] = [""]
    private(set) var attrs: [ParagraphAttrs] = [ParagraphAttrs()]
    private(set) var caretRow = 0
    private(set) var caretCol = 0
    /// Column the caret "wants" when moving vertically through short lines.
    private var stickyCol = 0
    private(set) var modified = false

    /// Selection anchor; the selection spans anchor..caret (either order).
    /// nil = no selection.
    private(set) var selAnchor: (row: Int, col: Int)? = nil

    var hasSelection: Bool {
        guard let a = selAnchor else { return false }
        return a.row != caretRow || a.col != caretCol
    }

    /// Normalized selection: (start, end) in document order.
    var selectionRange: (start: (row: Int, col: Int), end: (row: Int, col: Int))? {
        guard let a = selAnchor, hasSelection else { return nil }
        let anchor = (a.row, a.col)
        let caret = (caretRow, caretCol)
        return anchor < caret ? (start: (row: a.row, col: a.col),
                                 end: (row: caretRow, col: caretCol))
                              : (start: (row: caretRow, col: caretCol),
                                 end: (row: a.row, col: a.col))
    }

    var selectedText: String? {
        guard let range = selectionRange else { return nil }
        let (s, e) = (range.start, range.end)
        if s.row == e.row {
            let line = Array(lines[s.row])
            return String(line[s.col..<e.col])
        }
        var parts: [String] = [String(Array(lines[s.row])[s.col...])]
        if e.row - s.row > 1 {
            parts.append(contentsOf: lines[(s.row + 1)..<e.row])
        }
        parts.append(String(Array(lines[e.row])[0..<e.col]))
        return parts.joined(separator: "\n")
    }

    /// Anchor the selection at the caret (before a shift-move or drag).
    mutating func beginSelection() {
        if selAnchor == nil { selAnchor = (caretRow, caretCol) }
    }

    mutating func clearSelection() { selAnchor = nil }

    mutating func selectAll() {
        selAnchor = (0, 0)
        caretRow = lines.count - 1
        caretCol = lines[caretRow].count
        stickyCol = caretCol
    }

    /// Remove the selected range; caret lands at its start. The surviving
    /// merged paragraph keeps the START paragraph's attributes.
    mutating func deleteSelection() {
        guard let range = selectionRange else { return }
        let (s, e) = (range.start, range.end)
        let head = String(Array(lines[s.row])[0..<s.col])
        let tail = String(Array(lines[e.row])[e.col...])
        lines[s.row] = head + tail
        if e.row > s.row {
            lines.removeSubrange((s.row + 1)...e.row)
            attrs.removeSubrange((s.row + 1)...e.row)
        }
        caretRow = s.row
        caretCol = s.col
        stickyCol = s.col
        selAnchor = nil
        modified = true
    }

    var lineCount: Int { lines.count }

    var text: String { lines.joined(separator: "\n") }

    mutating func load(_ text: String) {
        // Tabs render at unpredictable widths in the cell model — expand them.
        let expanded = text.replacingOccurrences(of: "\t", with: "    ")
        lines = expanded.components(separatedBy: "\n")
        if lines.isEmpty { lines = [""] }
        attrs = Array(repeating: ParagraphAttrs(), count: lines.count)
        caretRow = 0
        caretCol = 0
        stickyCol = 0
        selAnchor = nil
        modified = false
    }

    /// Load a parsed rich document (paragraphs + their attributes).
    mutating func loadRich(lines newLines: [String], attrs newAttrs: [ParagraphAttrs]) {
        lines = newLines.isEmpty ? [""]
            : newLines.map { $0.replacingOccurrences(of: "\t", with: "    ") }
        attrs = (0..<lines.count).map { $0 < newAttrs.count ? newAttrs[$0] : ParagraphAttrs() }
        caretRow = 0
        caretCol = 0
        stickyCol = 0
        selAnchor = nil
        modified = false
    }

    /// True when any paragraph carries formatting a plain-text save would drop.
    var hasFormatting: Bool { attrs.contains { $0 != ParagraphAttrs() } }

    mutating func markSaved() { modified = false }

    // MARK: - Editing

    mutating func insert(_ text: String) {
        guard !text.isEmpty else { return }
        if hasSelection { deleteSelection() } else { selAnchor = nil }
        let line = Array(lines[caretRow])
        let head = String(line[0..<caretCol])
        let tail = String(line[caretCol...])
        lines[caretRow] = head + text + tail
        caretCol += text.count
        stickyCol = caretCol
        modified = true
    }

    mutating func insertNewline() {
        if hasSelection { deleteSelection() } else { selAnchor = nil }
        let line = Array(lines[caretRow])
        let head = String(line[0..<caretCol])
        let tail = String(line[caretCol...])
        lines[caretRow] = head
        lines.insert(tail, at: caretRow + 1)
        attrs.insert(attrs[caretRow], at: caretRow + 1)
        caretRow += 1
        caretCol = 0
        stickyCol = 0
        modified = true
    }

    mutating func backspace() {
        if hasSelection {
            deleteSelection()
            return
        }
        selAnchor = nil
        if caretCol > 0 {
            let line = Array(lines[caretRow])
            lines[caretRow] = String(line[0..<(caretCol - 1)]) + String(line[caretCol...])
            caretCol -= 1
        } else if caretRow > 0 {
            let prevLen = lines[caretRow - 1].count
            lines[caretRow - 1] += lines[caretRow]
            lines.remove(at: caretRow)
            attrs.remove(at: caretRow)
            caretRow -= 1
            caretCol = prevLen
        } else {
            return
        }
        stickyCol = caretCol
        modified = true
    }

    mutating func deleteForward() {
        if hasSelection {
            deleteSelection()
            return
        }
        selAnchor = nil
        let line = Array(lines[caretRow])
        if caretCol < line.count {
            lines[caretRow] = String(line[0..<caretCol]) + String(line[(caretCol + 1)...])
        } else if caretRow < lines.count - 1 {
            lines[caretRow] += lines[caretRow + 1]
            lines.remove(at: caretRow + 1)
            attrs.remove(at: caretRow + 1)
        } else {
            return
        }
        modified = true
    }

    // MARK: - Caret movement

    mutating func moveLeft() {
        if caretCol > 0 {
            caretCol -= 1
        } else if caretRow > 0 {
            caretRow -= 1
            caretCol = lines[caretRow].count
        }
        stickyCol = caretCol
    }

    mutating func moveRight() {
        if caretCol < lines[caretRow].count {
            caretCol += 1
        } else if caretRow < lines.count - 1 {
            caretRow += 1
            caretCol = 0
        }
        stickyCol = caretCol
    }

    // MARK: - Word movement

    private static func _isWordChar(_ ch: Character) -> Bool {
        ch.isLetter || ch.isNumber || ch == "_"
    }

    /// Caret to the start of the previous word (Ctrl+Left semantics).
    mutating func moveWordLeft() {
        if caretCol == 0 {
            if caretRow > 0 {
                caretRow -= 1
                caretCol = lines[caretRow].count
            }
            stickyCol = caretCol
            return
        }
        let line = Array(lines[caretRow])
        var i = caretCol
        while i > 0 && !Self._isWordChar(line[i - 1]) { i -= 1 }
        while i > 0 && Self._isWordChar(line[i - 1]) { i -= 1 }
        caretCol = i
        stickyCol = i
    }

    /// Caret past the end of the next word (Ctrl+Right semantics).
    mutating func moveWordRight() {
        let line = Array(lines[caretRow])
        if caretCol >= line.count {
            if caretRow < lines.count - 1 {
                caretRow += 1
                caretCol = 0
            }
            stickyCol = caretCol
            return
        }
        var i = caretCol
        while i < line.count && !Self._isWordChar(line[i]) { i += 1 }
        while i < line.count && Self._isWordChar(line[i]) { i += 1 }
        caretCol = i
        stickyCol = i
    }

    /// Delete from the caret to the previous word start (Ctrl+Backspace).
    mutating func deleteWordBack() {
        guard !hasSelection else {
            deleteSelection()
            return
        }
        selAnchor = (caretRow, caretCol)
        moveWordLeft()
        if hasSelection { deleteSelection() } else { selAnchor = nil }
    }

    // MARK: - Paragraph formatting

    /// The caret paragraph's attributes (what the format bar reflects).
    var caretAttrs: ParagraphAttrs { attrs[caretRow] }

    mutating func setCaretAlign(_ align: ParagraphAttrs.Align) {
        attrs[caretRow].align = align
        modified = true
    }

    mutating func toggleBold() { attrs[caretRow].bold.toggle(); modified = true }
    mutating func toggleItalic() { attrs[caretRow].italic.toggle(); modified = true }
    mutating func toggleUnderline() { attrs[caretRow].underline.toggle(); modified = true }

    /// Select the run (word / spaces / punctuation) under the caret.
    mutating func selectWord() {
        let line = Array(lines[caretRow])
        guard !line.isEmpty else { return }
        let idx = min(caretCol, line.count - 1)
        func cls(_ ch: Character) -> Int {
            if ch.isLetter || ch.isNumber || ch == "_" { return 0 }
            if ch == " " { return 1 }
            return 2
        }
        let kind = cls(line[idx])
        var start = idx
        var end = idx + 1
        while start > 0 && cls(line[start - 1]) == kind { start -= 1 }
        while end < line.count && cls(line[end]) == kind { end += 1 }
        selAnchor = (caretRow, start)
        caretCol = end
        stickyCol = end
    }

    mutating func selectParagraph() {
        selAnchor = (caretRow, 0)
        caretCol = lines[caretRow].count
        stickyCol = caretCol
    }

    mutating func moveTo(row: Int, col: Int, selecting: Bool = false) {
        if selecting { beginSelection() } else { selAnchor = nil }
        caretRow = max(0, min(lines.count - 1, row))
        caretCol = max(0, min(lines[caretRow].count, col))
        stickyCol = caretCol
    }
}
