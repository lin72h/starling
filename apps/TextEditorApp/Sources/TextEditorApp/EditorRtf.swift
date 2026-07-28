// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Minimal RTF reader/writer covering exactly what `EditorBuffer` models:
/// per-paragraph alignment + bold/italic/underline, plus the document font
/// size. Writing targets other readers (TextEdit, Word, LibreOffice) with
/// plain RTF 1 constructs; reading tolerates their extra control words by
/// skipping anything unknown.
enum EditorRtf {

    // MARK: - Writer

    static func serialize(lines: [String], attrs: [ParagraphAttrs],
                          fontSize: Double) -> String {
        var out = "{\\rtf1\\ansi\\deff0\\uc1{\\fonttbl{\\f0\\fswiss Helvetica;}}\n"
        out += "\\f0\\fs\(Int(fontSize * 2))\n"
        for (i, line) in lines.enumerated() {
            let a = i < attrs.count ? attrs[i] : ParagraphAttrs()
            out += "\\pard"
            switch a.align {
            case .left: break
            case .center: out += "\\qc"
            case .right: out += "\\qr"
            }
            if a.bold { out += "\\b" }
            if a.italic { out += "\\i" }
            if a.underline { out += "\\ul" }
            out += " "
            out += _escape(line)
            if i < lines.count - 1 { out += "\\par" }
            out += "\n"
        }
        out += "}"
        return out
    }

    private static func _escape(_ s: String) -> String {
        var out = ""
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case "{": out += "\\{"
            case "}": out += "\\}"
            default:
                if scalar.value < 0x80 {
                    out.unicodeScalars.append(scalar)
                } else {
                    // Non-ASCII as signed-16-bit \uN with a "?" fallback
                    // (one per UTF-16 unit; surrogate pairs emit two).
                    for unit in String(scalar).utf16 {
                        out += "\\u\(Int16(bitPattern: unit))?"
                    }
                }
            }
        }
        return out
    }

    // MARK: - Reader

    struct Document {
        var lines: [String]
        var attrs: [ParagraphAttrs]
        var fontSize: Double?
    }

    /// nil when the content is not RTF (caller falls back to plain text).
    static func parse(_ rtf: String) -> Document? {
        let trimmed = rtf.drop { $0 == " " || $0 == "\n" || $0 == "\r" }
        guard trimmed.hasPrefix("{\\rtf") else { return nil }

        struct State {
            var attrs = ParagraphAttrs()
            var ucSkip = 1
            var destination = false   // inside \fonttbl, \*\..., etc.
        }
        let scalars = Array(trimmed.unicodeScalars)
        var i = 0
        var state = State()
        var stack: [State] = []
        var lines: [String] = []
        var attrsOut: [ParagraphAttrs] = []
        var pending: [UInt16] = []    // UTF-16 units of the open paragraph
        var pendingAttrs = ParagraphAttrs()  // attrs in effect at last emit
        var fontSize: Double? = nil

        /// Append text to the open paragraph, remembering the formatting it
        /// was written under — a closing `}` may restore an outer state
        /// before the paragraph ends (the last paragraph has no \par).
        func emit(_ units: [UInt16]) {
            pending.append(contentsOf: units)
            pendingAttrs = state.attrs
        }
        func endParagraph() {
            lines.append(String(decoding: pending, as: UTF16.self))
            attrsOut.append(pending.isEmpty ? state.attrs : pendingAttrs)
            pending = []
        }
        /// Consume the \uN fallback text ("?" or \'xx), ucSkip chars long.
        func skipFallback() {
            var left = state.ucSkip
            while left > 0 && i < scalars.count {
                if scalars[i] == "\\" && i + 1 < scalars.count && scalars[i + 1] == "'" {
                    i += 4
                } else if scalars[i] == "{" || scalars[i] == "}" || scalars[i] == "\\" {
                    break     // fallback ended early — don't eat structure
                } else {
                    i += 1
                }
                left -= 1
            }
        }

        while i < scalars.count {
            let c = scalars[i]
            switch c {
            case "{":
                stack.append(state)
                i += 1
            case "}":
                if let prev = stack.popLast() { state = prev }
                i += 1
            case "\\":
                i += 1
                guard i < scalars.count else { break }
                let n = scalars[i]
                if (n >= "a" && n <= "z") || (n >= "A" && n <= "Z") {
                    // Control word: letters + optional signed integer param.
                    var word = ""
                    while i < scalars.count,
                          (scalars[i] >= "a" && scalars[i] <= "z")
                          || (scalars[i] >= "A" && scalars[i] <= "Z") {
                        word.unicodeScalars.append(scalars[i])
                        i += 1
                    }
                    var param: Int? = nil
                    var negative = false
                    if i < scalars.count && scalars[i] == "-" { negative = true; i += 1 }
                    var digits = 0
                    var value = 0
                    while i < scalars.count, scalars[i] >= "0", scalars[i] <= "9" {
                        value = value * 10 + Int(scalars[i].value - 48)
                        digits += 1
                        i += 1
                    }
                    if digits > 0 { param = negative ? -value : value }
                    // A single space after the word is the delimiter.
                    if i < scalars.count && scalars[i] == " " { i += 1 }

                    switch word {
                    case "par", "line":
                        if !state.destination { endParagraph() }
                    case "pard":
                        state.attrs = ParagraphAttrs()
                    case "ql", "qj": state.attrs.align = .left
                    case "qc": state.attrs.align = .center
                    case "qr": state.attrs.align = .right
                    case "b": state.attrs.bold = param != 0
                    case "i": state.attrs.italic = param != 0
                    case "ul": state.attrs.underline = param != 0
                    case "ulnone": state.attrs.underline = false
                    case "uc": state.ucSkip = param ?? 1
                    case "u":
                        if !state.destination, let p = param {
                            emit([UInt16(bitPattern: Int16(clamping: p))])
                        }
                        skipFallback()
                    case "fs":
                        if !state.destination, fontSize == nil, let p = param {
                            fontSize = Double(p) / 2
                        }
                    case "tab":
                        if !state.destination { emit([32, 32, 32, 32]) }
                    case "fonttbl", "colortbl", "stylesheet", "info", "pict",
                         "themedata", "listtable", "generator":
                        state.destination = true
                    default:
                        break     // unknown word: ignore
                    }
                } else {
                    // Control symbol.
                    switch n {
                    case "\\", "{", "}":
                        if !state.destination { emit([UInt16(n.value)]) }
                        i += 1
                    case "'":
                        i += 1
                        var byte = 0
                        var count = 0
                        while count < 2, i < scalars.count,
                              let d = scalars[i].hexDigitValue {
                            byte = byte * 16 + d
                            count += 1
                            i += 1
                        }
                        if !state.destination { emit([UInt16(byte)]) }
                    case "~":
                        if !state.destination { emit([32]) }
                        i += 1
                    case "*":
                        state.destination = true
                        i += 1
                    case "\r", "\n":
                        // Escaped newline — TextEdit's paragraph break.
                        if !state.destination { endParagraph() }
                        i += 1
                    default:
                        i += 1    // \- \_ and friends: ignore
                    }
                }
            case "\r", "\n":
                i += 1            // raw newlines are insignificant in RTF
            default:
                if !state.destination {
                    emit(Array(String(c).utf16))
                }
                i += 1
            }
        }
        endParagraph()            // trailing paragraph has no \par
        return Document(lines: lines, attrs: attrsOut, fontSize: fontSize)
    }
}

private extension Unicode.Scalar {
    var hexDigitValue: Int? {
        switch self {
        case "0"..."9": return Int(value - 48)
        case "a"..."f": return Int(value - 87)
        case "A"..."F": return Int(value - 55)
        default: return nil
        }
    }
}
