// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

// MARK: - Cell

/// Character-cell attributes, bit flags.
struct CellAttrs: OptionSet {
    let rawValue: UInt8
    static let bold = CellAttrs(rawValue: 1 << 0)
    static let dim = CellAttrs(rawValue: 1 << 1)
    static let italic = CellAttrs(rawValue: 1 << 2)
    static let underline = CellAttrs(rawValue: 1 << 3)
    static let reverse = CellAttrs(rawValue: 1 << 4)
}

/// One terminal grid cell. Colors are ARGB; 0 means "default fg/bg".
struct TermCell {
    var char: Character = " "
    var fg: UInt32 = 0
    var bg: UInt32 = 0
    var attrs: CellAttrs = []

    static let blank = TermCell()
}

// MARK: - Emulator

/// A VT100/xterm-flavoured terminal emulator: feed it PTY bytes, it maintains
/// a character grid (plus scrollback and an alternate screen) and emits
/// responses (DSR/DA) via `onResponse`.
///
/// Threading: `feed`/`resize` and grid reads must be externally synchronized
/// (the app wraps calls in a lock).
final class TerminalEmulator {

    private(set) var cols: Int
    private(set) var rows: Int

    /// The active screen, `rows` lines of `cols` cells.
    private(set) var grid: [[TermCell]]

    /// Lines scrolled off the top of the primary screen (oldest first).
    private(set) var scrollback: [[TermCell]] = []
    let scrollbackLimit = 2000

    private(set) var cursorRow = 0
    private(set) var cursorCol = 0
    private(set) var cursorVisible = true

    /// Incremented on every visible change; the UI compares generations to
    /// know when to repaint.
    private(set) var generation: UInt64 = 0

    /// Terminal responses (cursor position reports etc.) to write to the PTY.
    var onResponse: ((String) -> Void)?
    var onBell: (() -> Void)?

    // Current SGR drawing state
    private var curFg: UInt32 = 0
    private var curBg: UInt32 = 0
    private var curAttrs: CellAttrs = []

    // Scroll region (0-based, inclusive)
    private var regionTop = 0
    private var regionBottom: Int

    // Modes
    private var autowrap = true
    private var originMode = false
    private var wrapPending = false

    /// DECCKM — application cursor keys (arrows send ESC O x instead of CSI).
    private(set) var applicationCursorKeys = false

    /// DEC private mode 2004: paste is wrapped in ESC[200~ … ESC[201~ so
    /// TUIs (Claude Code, vim) treat it as one atomic insert.
    private(set) var bracketedPaste = false

    // Alternate screen support
    private var altActive = false
    private var savedPrimaryGrid: [[TermCell]]?
    private var savedPrimaryCursor: (Int, Int) = (0, 0)

    // Saved cursor (DECSC)
    private var savedCursor: (row: Int, col: Int) = (0, 0)
    private var savedFg: UInt32 = 0
    private var savedBg: UInt32 = 0
    private var savedAttrs: CellAttrs = []

    // Parser state
    private enum ParseState {
        case ground
        case escape          // saw ESC
        case escapeIntermediate(Character)  // e.g. ESC ( — consume one more
        case csi             // collecting CSI params
        case osc             // collecting OSC string
        case oscEscape       // saw ESC inside OSC (expecting \)
    }
    private var state: ParseState = .ground
    private var csiParams: String = ""
    private var oscBuffer: String = ""

    // Incremental UTF-8 decoding
    private var utf8Pending: [UInt8] = []

    init(cols: Int, rows: Int) {
        self.cols = max(2, cols)
        self.rows = max(2, rows)
        self.regionBottom = self.rows - 1
        self.grid = Array(repeating: Array(repeating: .blank, count: self.cols),
                          count: self.rows)
    }

    // MARK: - Feeding input

    func feed(_ bytes: [UInt8]) {
        var input = utf8Pending
        input.append(contentsOf: bytes)
        utf8Pending = []

        var i = 0
        while i < input.count {
            let byte = input[i]

            // In ground state, non-ASCII lead bytes start a UTF-8 sequence.
            if case .ground = state, byte >= 0x80 {
                let len = _utf8Length(byte)
                if i + len > input.count {
                    // Partial sequence — keep for the next feed.
                    utf8Pending = Array(input[i...])
                    break
                }
                let seq = Array(input[i ..< i + len])
                if let scalarStr = String(bytes: seq, encoding: .utf8),
                   let ch = scalarStr.first {
                    _putChar(ch)
                }
                i += len
                continue
            }

            _processByte(byte)
            i += 1
        }
        generation &+= 1
    }

    private func _utf8Length(_ lead: UInt8) -> Int {
        if lead & 0xE0 == 0xC0 { return 2 }
        if lead & 0xF0 == 0xE0 { return 3 }
        if lead & 0xF8 == 0xF0 { return 4 }
        return 1
    }

    private func _processByte(_ byte: UInt8) {
        switch state {
        case .ground:
            _processGround(byte)
        case .escape:
            _processEscape(byte)
        case .escapeIntermediate:
            state = .ground  // consume the charset designator etc.
        case .csi:
            _processCsi(byte)
        case .osc:
            if byte == 0x07 {  // BEL terminator
                _finishOsc()
            } else if byte == 0x1B {
                state = .oscEscape
            } else {
                oscBuffer.append(Character(UnicodeScalar(byte)))
            }
        case .oscEscape:
            // ESC \ = ST terminator; anything else aborts the OSC.
            _finishOsc()
            if byte != 0x5C /* \ */ {
                _processByte(byte)
            }
        }
    }

    private func _processGround(_ byte: UInt8) {
        switch byte {
        case 0x07: onBell?()
        case 0x08:  // BS
            if cursorCol > 0 { cursorCol -= 1 }
            wrapPending = false
        case 0x09:  // TAB — fixed stops every 8
            cursorCol = min(cols - 1, ((cursorCol / 8) + 1) * 8)
        case 0x0A, 0x0B, 0x0C:  // LF, VT, FF
            _lineFeed()
        case 0x0D:  // CR
            cursorCol = 0
            wrapPending = false
        case 0x1B:
            state = .escape
        case 0x20...:
            _putChar(Character(UnicodeScalar(byte)))
        default:
            break  // ignore other C0 controls
        }
    }

    private func _processEscape(_ byte: UInt8) {
        state = .ground
        switch byte {
        case UInt8(ascii: "["):
            csiParams = ""
            state = .csi
        case UInt8(ascii: "]"):
            oscBuffer = ""
            state = .osc
        case UInt8(ascii: "7"):  // DECSC
            _saveCursor()
        case UInt8(ascii: "8"):  // DECRC
            _restoreCursor()
        case UInt8(ascii: "D"):  // IND
            _lineFeed()
        case UInt8(ascii: "E"):  // NEL
            cursorCol = 0
            _lineFeed()
        case UInt8(ascii: "M"):  // RI — reverse index
            if cursorRow == regionTop {
                _scrollDown(1)
            } else if cursorRow > 0 {
                cursorRow -= 1
            }
        case UInt8(ascii: "c"):  // RIS — full reset
            _fullReset()
        case UInt8(ascii: "("), UInt8(ascii: ")"),
             UInt8(ascii: "*"), UInt8(ascii: "+"),
             UInt8(ascii: "#"), UInt8(ascii: "%"):
            state = .escapeIntermediate(Character(UnicodeScalar(byte)))
        case UInt8(ascii: "="), UInt8(ascii: ">"):
            break  // keypad modes — ignored
        default:
            break
        }
    }

    private func _processCsi(_ byte: UInt8) {
        // Parameter / intermediate bytes accumulate; 0x40-0x7E terminates.
        if byte >= 0x40 && byte <= 0x7E {
            state = .ground
            _dispatchCsi(final: Character(UnicodeScalar(byte)))
        } else if byte >= 0x20 && byte <= 0x3F {
            csiParams.append(Character(UnicodeScalar(byte)))
        } else if byte == 0x1B {
            state = .escape
        }
        // other C0 bytes inside CSI: ignored for simplicity
    }

    private func _finishOsc() {
        state = .ground
        // OSC 0/2: window title — no-op for now (shell draws the title bar).
        oscBuffer = ""
    }

    // MARK: - CSI dispatch

    private func _params(default def: Int = 0) -> [Int] {
        let body = csiParams.hasPrefix("?") ? String(csiParams.dropFirst()) : csiParams
        if body.isEmpty { return [] }
        return body.split(separator: ";", omittingEmptySubsequences: false)
            .map { Int($0) ?? def }
    }

    private var _isPrivate: Bool { csiParams.hasPrefix("?") }

    private func _dispatchCsi(final: Character) {
        let params = _params()
        func p(_ i: Int, _ def: Int) -> Int {
            i < params.count && params[i] != 0 ? params[i] : def
        }

        switch final {
        case "A": _moveCursor(rowDelta: -p(0, 1), colDelta: 0)
        case "B": _moveCursor(rowDelta: p(0, 1), colDelta: 0)
        case "C": _moveCursor(rowDelta: 0, colDelta: p(0, 1))
        case "D": _moveCursor(rowDelta: 0, colDelta: -p(0, 1))
        case "E":
            cursorCol = 0
            _moveCursor(rowDelta: p(0, 1), colDelta: 0)
        case "F":
            cursorCol = 0
            _moveCursor(rowDelta: -p(0, 1), colDelta: 0)
        case "G", "`":
            cursorCol = max(0, min(cols - 1, p(0, 1) - 1))
            wrapPending = false
        case "d":
            _setCursor(row: p(0, 1) - 1, col: cursorCol)
        case "H", "f":
            _setCursor(row: p(0, 1) - 1, col: p(1, 1) - 1)
        case "J": _eraseDisplay(mode: params.first ?? 0)
        case "K": _eraseLine(mode: params.first ?? 0)
        case "L": _insertLines(p(0, 1))
        case "M": _deleteLines(p(0, 1))
        case "P": _deleteChars(p(0, 1))
        case "@": _insertChars(p(0, 1))
        case "X": _eraseChars(p(0, 1))
        case "S": _scrollUp(p(0, 1))
        case "T": _scrollDown(p(0, 1))
        case "r":
            let top = p(0, 1) - 1
            let bottom = p(1, rows) - 1
            if top < bottom && bottom < rows {
                regionTop = top
                regionBottom = bottom
            } else {
                regionTop = 0
                regionBottom = rows - 1
            }
            _setCursor(row: 0, col: 0)
        case "m": _sgr(params)
        case "h": _setMode(params, on: true)
        case "l": _setMode(params, on: false)
        case "n":
            if params.first == 5 { onResponse?("\u{1B}[0n") }
            if params.first == 6 {
                onResponse?("\u{1B}[\(cursorRow + 1);\(cursorCol + 1)R")
            }
        case "c":
            onResponse?("\u{1B}[?6c")  // claim VT102
        case "s": _saveCursor()
        case "u": _restoreCursor()
        case "g", "t", "q":
            break  // tab clear / window ops / cursor style — ignored
        default:
            break
        }
    }

    // MARK: - Cursor + character output

    private func _putChar(_ ch: Character) {
        if wrapPending {
            wrapPending = false
            if autowrap {
                cursorCol = 0
                _lineFeed()
            }
        }
        guard cursorRow >= 0, cursorRow < rows,
              cursorCol >= 0, cursorCol < cols else { return }
        grid[cursorRow][cursorCol] = TermCell(
            char: ch, fg: curFg, bg: curBg, attrs: curAttrs
        )
        if cursorCol == cols - 1 {
            wrapPending = true
        } else {
            cursorCol += 1
        }
    }

    private func _lineFeed() {
        wrapPending = false
        if cursorRow == regionBottom {
            _scrollUp(1)
        } else if cursorRow < rows - 1 {
            cursorRow += 1
        }
    }

    private func _moveCursor(rowDelta: Int, colDelta: Int) {
        cursorRow = max(0, min(rows - 1, cursorRow + rowDelta))
        cursorCol = max(0, min(cols - 1, cursorCol + colDelta))
        wrapPending = false
    }

    private func _setCursor(row: Int, col: Int) {
        let base = originMode ? regionTop : 0
        let limit = originMode ? regionBottom : rows - 1
        cursorRow = max(base, min(limit, base + row))
        cursorCol = max(0, min(cols - 1, col))
        wrapPending = false
    }

    private func _saveCursor() {
        savedCursor = (cursorRow, cursorCol)
        savedFg = curFg
        savedBg = curBg
        savedAttrs = curAttrs
    }

    private func _restoreCursor() {
        cursorRow = min(rows - 1, savedCursor.row)
        cursorCol = min(cols - 1, savedCursor.col)
        curFg = savedFg
        curBg = savedBg
        curAttrs = savedAttrs
        wrapPending = false
    }

    // MARK: - Erase / edit

    private var _blankCell: TermCell {
        TermCell(char: " ", fg: 0, bg: curBg, attrs: [])
    }

    private func _blankLine() -> [TermCell] {
        Array(repeating: _blankCell, count: cols)
    }

    private func _eraseDisplay(mode: Int) {
        switch mode {
        case 0:
            _eraseLine(mode: 0)
            for r in (cursorRow + 1) ..< rows { grid[r] = _blankLine() }
        case 1:
            _eraseLine(mode: 1)
            for r in 0 ..< cursorRow { grid[r] = _blankLine() }
        case 2:
            for r in 0 ..< rows { grid[r] = _blankLine() }
        case 3:
            for r in 0 ..< rows { grid[r] = _blankLine() }
            scrollback.removeAll()
        default:
            break
        }
    }

    private func _eraseLine(mode: Int) {
        guard cursorRow >= 0 && cursorRow < rows else { return }
        switch mode {
        case 0:
            for c in cursorCol ..< cols { grid[cursorRow][c] = _blankCell }
        case 1:
            for c in 0 ... min(cursorCol, cols - 1) { grid[cursorRow][c] = _blankCell }
        case 2:
            grid[cursorRow] = _blankLine()
        default:
            break
        }
    }

    private func _eraseChars(_ n: Int) {
        guard cursorRow >= 0 && cursorRow < rows else { return }
        for c in cursorCol ..< min(cols, cursorCol + n) {
            grid[cursorRow][c] = _blankCell
        }
    }

    private func _deleteChars(_ n: Int) {
        guard cursorRow >= 0 && cursorRow < rows else { return }
        var line = grid[cursorRow]
        let count = min(n, cols - cursorCol)
        line.removeSubrange(cursorCol ..< cursorCol + count)
        line.append(contentsOf: Array(repeating: _blankCell, count: count))
        grid[cursorRow] = line
    }

    private func _insertChars(_ n: Int) {
        guard cursorRow >= 0 && cursorRow < rows else { return }
        var line = grid[cursorRow]
        let count = min(n, cols - cursorCol)
        line.insert(contentsOf: Array(repeating: _blankCell, count: count),
                    at: cursorCol)
        line.removeLast(count)
        grid[cursorRow] = line
    }

    private func _insertLines(_ n: Int) {
        guard cursorRow >= regionTop && cursorRow <= regionBottom else { return }
        let count = min(n, regionBottom - cursorRow + 1)
        for _ in 0 ..< count {
            grid.remove(at: regionBottom)
            grid.insert(_blankLine(), at: cursorRow)
        }
        cursorCol = 0
    }

    private func _deleteLines(_ n: Int) {
        guard cursorRow >= regionTop && cursorRow <= regionBottom else { return }
        let count = min(n, regionBottom - cursorRow + 1)
        for _ in 0 ..< count {
            grid.remove(at: cursorRow)
            grid.insert(_blankLine(), at: regionBottom)
        }
        cursorCol = 0
    }

    private func _scrollUp(_ n: Int) {
        for _ in 0 ..< n {
            let removed = grid[regionTop]
            if !altActive && regionTop == 0 {
                scrollback.append(removed)
                if scrollback.count > scrollbackLimit {
                    scrollback.removeFirst(scrollback.count - scrollbackLimit)
                }
            }
            grid.remove(at: regionTop)
            grid.insert(_blankLine(), at: regionBottom)
        }
    }

    private func _scrollDown(_ n: Int) {
        for _ in 0 ..< n {
            grid.remove(at: regionBottom)
            grid.insert(_blankLine(), at: regionTop)
        }
    }

    // MARK: - SGR (colors / attributes)

    private func _sgr(_ params: [Int]) {
        let params = params.isEmpty ? [0] : params
        var i = 0
        while i < params.count {
            let p = params[i]
            switch p {
            case 0:
                curFg = 0; curBg = 0; curAttrs = []
            case 1: curAttrs.insert(.bold)
            case 2: curAttrs.insert(.dim)
            case 3: curAttrs.insert(.italic)
            case 4: curAttrs.insert(.underline)
            case 7: curAttrs.insert(.reverse)
            case 22: curAttrs.remove([.bold, .dim])
            case 23: curAttrs.remove(.italic)
            case 24: curAttrs.remove(.underline)
            case 27: curAttrs.remove(.reverse)
            case 30...37: curFg = TermPalette.ansi(p - 30, bold: false)
            case 39: curFg = 0
            case 40...47: curBg = TermPalette.ansi(p - 40, bold: false)
            case 49: curBg = 0
            case 90...97: curFg = TermPalette.ansi(p - 90, bold: true)
            case 100...107: curBg = TermPalette.ansi(p - 100, bold: true)
            case 38, 48:
                // 38;5;n / 38;2;r;g;b (and 48;… for background)
                var color: UInt32? = nil
                if i + 2 < params.count && params[i + 1] == 5 {
                    color = TermPalette.color256(params[i + 2])
                    i += 2
                } else if i + 4 < params.count && params[i + 1] == 2 {
                    let r = UInt32(clamping: params[i + 2])
                    let g = UInt32(clamping: params[i + 3])
                    let b = UInt32(clamping: params[i + 4])
                    color = 0xFF00_0000 | (r << 16) | (g << 8) | b
                    i += 4
                }
                if let color = color {
                    if p == 38 { curFg = color } else { curBg = color }
                }
            default:
                break
            }
            i += 1
        }
    }

    // MARK: - Modes

    private func _setMode(_ params: [Int], on: Bool) {
        guard _isPrivate else { return }  // ANSI modes (4 insert…) ignored
        for p in params {
            switch p {
            case 1: applicationCursorKeys = on
            case 7: autowrap = on
            case 6:
                originMode = on
                _setCursor(row: 0, col: 0)
            case 25: cursorVisible = on
            case 47, 1047:
                on ? _enterAltScreen(saveCursor: false)
                   : _exitAltScreen(restoreCursor: false)
            case 1049:
                on ? _enterAltScreen(saveCursor: true)
                   : _exitAltScreen(restoreCursor: true)
            case 1048:
                on ? _saveCursor() : _restoreCursor()
            case 2004:
                bracketedPaste = on
            default:
                break  // mouse modes, blinking… ignored
            }
        }
    }

    private func _enterAltScreen(saveCursor: Bool) {
        guard !altActive else { return }
        if saveCursor { _saveCursor() }
        savedPrimaryGrid = grid
        savedPrimaryCursor = (cursorRow, cursorCol)
        altActive = true
        grid = Array(repeating: _blankLine(), count: rows)
        cursorRow = 0
        cursorCol = 0
    }

    private func _exitAltScreen(restoreCursor: Bool) {
        guard altActive else { return }
        altActive = false
        if let saved = savedPrimaryGrid {
            grid = saved
            // Re-normalize in case a resize happened while in the alt screen.
            _normalizeGrid()
        }
        (cursorRow, cursorCol) = savedPrimaryCursor
        cursorRow = min(cursorRow, rows - 1)
        cursorCol = min(cursorCol, cols - 1)
        savedPrimaryGrid = nil
        if restoreCursor { _restoreCursor() }
    }

    private func _fullReset() {
        grid = Array(repeating: Array(repeating: .blank, count: cols), count: rows)
        scrollback.removeAll()
        cursorRow = 0
        cursorCol = 0
        curFg = 0
        curBg = 0
        curAttrs = []
        regionTop = 0
        regionBottom = rows - 1
        autowrap = true
        originMode = false
        wrapPending = false
        cursorVisible = true
        altActive = false
        savedPrimaryGrid = nil
    }

    // MARK: - Scrollback view

    /// Number of scrollback lines currently stored.
    var scrollbackCount: Int { scrollback.count }

    /// The `rows` lines visible when scrolled back by `offset` lines
    /// (0 = the live screen). Clamped to the available history.
    func visibleLines(offset: Int) -> [[TermCell]] {
        let off = max(0, min(offset, scrollback.count))
        if off == 0 { return grid }
        let base = scrollback.count - off
        var lines: [[TermCell]] = []
        lines.reserveCapacity(rows)
        for i in 0 ..< rows {
            let idx = base + i
            if idx < scrollback.count {
                // Scrollback lines may predate a resize — normalize width.
                lines.append(_fitLine(scrollback[idx]))
            } else {
                lines.append(grid[idx - scrollback.count])
            }
        }
        return lines
    }

    // MARK: - Resize

    func resize(cols newCols: Int, rows newRows: Int) {
        let newCols = max(2, newCols)
        let newRows = max(2, newRows)
        guard newCols != cols || newRows != rows else { return }
        cols = newCols
        rows = newRows
        regionTop = 0
        regionBottom = rows - 1
        _normalizeGrid()
        if var saved = savedPrimaryGrid {
            for i in 0 ..< saved.count { saved[i] = _fitLine(saved[i]) }
            while saved.count < rows { saved.append(_blankLine()) }
            while saved.count > rows { saved.removeFirst() }
            savedPrimaryGrid = saved
        }
        cursorRow = min(cursorRow, rows - 1)
        cursorCol = min(cursorCol, cols - 1)
        wrapPending = false
        generation &+= 1
    }

    private func _fitLine(_ line: [TermCell]) -> [TermCell] {
        if line.count == cols { return line }
        if line.count > cols { return Array(line[0 ..< cols]) }
        return line + Array(repeating: .blank, count: cols - line.count)
    }

    private func _normalizeGrid() {
        for i in 0 ..< grid.count { grid[i] = _fitLine(grid[i]) }
        while grid.count < rows { grid.append(_blankLine()) }
        while grid.count > rows {
            // Push overflow into scrollback (primary screen only)
            let removed = grid.removeFirst()
            if !altActive {
                scrollback.append(removed)
                if scrollback.count > scrollbackLimit {
                    scrollback.removeFirst(scrollback.count - scrollbackLimit)
                }
            }
            if cursorRow > 0 { cursorRow -= 1 }
        }
    }
}

// MARK: - Palette

/// xterm-256 color palette (ARGB).
enum TermPalette {
    /// The standard 16 ANSI colors (macOS Terminal-ish values, dark theme).
    static let ansi16: [UInt32] = [
        0xFF000000, 0xFFC23621, 0xFF25BC24, 0xFFADAD27,
        0xFF4C7BD4, 0xFFD338D3, 0xFF33BBC8, 0xFFCBCCCD,
        0xFF818383, 0xFFFC391F, 0xFF31E722, 0xFFEAEC23,
        0xFF6A9BF5, 0xFFF935F8, 0xFF14F0F0, 0xFFFFFFFF,
    ]

    static func ansi(_ index: Int, bold: Bool) -> UInt32 {
        let i = max(0, min(7, index)) + (bold ? 8 : 0)
        return ansi16[i]
    }

    static func color256(_ index: Int) -> UInt32 {
        let i = max(0, min(255, index))
        if i < 16 { return ansi16[i] }
        if i < 232 {
            // 6x6x6 color cube
            let v = i - 16
            let steps: [UInt32] = [0, 95, 135, 175, 215, 255]
            let r = steps[(v / 36) % 6]
            let g = steps[(v / 6) % 6]
            let b = steps[v % 6]
            return 0xFF00_0000 | (r << 16) | (g << 8) | b
        }
        // Grayscale ramp
        let gray = UInt32(8 + (i - 232) * 10)
        return 0xFF00_0000 | (gray << 16) | (gray << 8) | gray
    }
}
