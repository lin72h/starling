// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import FlutterSwiftBridge

/// Maps framework key events to the byte sequences a terminal expects.
enum TerminalInput {

    // X11 keysyms as delivered in KeyData.logical by the DRM embedder / the
    // shell's DMA-BUF key forwarding.
    private enum Keysym {
        static let backspace: Int64 = 0xFF08
        static let tab: Int64 = 0xFF09
        static let enter: Int64 = 0xFF0D
        static let escape: Int64 = 0xFF1B
        static let home: Int64 = 0xFF50
        static let left: Int64 = 0xFF51
        static let up: Int64 = 0xFF52
        static let right: Int64 = 0xFF53
        static let down: Int64 = 0xFF54
        static let pageUp: Int64 = 0xFF55
        static let pageDown: Int64 = 0xFF56
        static let end: Int64 = 0xFF57
        static let insert: Int64 = 0xFF63
        static let kpEnter: Int64 = 0xFF8D
        static let delete: Int64 = 0xFFFF
        static let f1: Int64 = 0xFFBE  // F1..F12 are contiguous
    }

    /// Returns the bytes to write to the PTY for a key press, or nil if the
    /// key is not terminal input (e.g. a bare modifier).
    ///
    /// `appCursor` is the emulator's DECCKM state: arrows/Home/End send
    /// `ESC O x` instead of `ESC [ x` when set.
    static func bytes(for keyData: KeyData, appCursor: Bool) -> [UInt8]? {
        let logical = keyData.logical

        // Special keys first — they take priority over any character the
        // keymap attached to them.
        switch logical {
        case Keysym.enter, Keysym.kpEnter:
            return [0x0D]
        case Keysym.backspace:
            return [0x7F]
        case Keysym.tab:
            return [0x09]
        case Keysym.escape:
            return [0x1B]
        case Keysym.up:    return _cursor("A", appCursor)
        case Keysym.down:  return _cursor("B", appCursor)
        case Keysym.right: return _cursor("C", appCursor)
        case Keysym.left:  return _cursor("D", appCursor)
        case Keysym.home:  return _cursor("H", appCursor)
        case Keysym.end:   return _cursor("F", appCursor)
        case Keysym.insert:   return Array("\u{1B}[2~".utf8)
        case Keysym.delete:   return Array("\u{1B}[3~".utf8)
        case Keysym.pageUp:   return Array("\u{1B}[5~".utf8)
        case Keysym.pageDown: return Array("\u{1B}[6~".utf8)
        default:
            break
        }

        // Function keys F1-F12
        if logical >= Keysym.f1 && logical < Keysym.f1 + 12 {
            let n = Int(logical - Keysym.f1)  // 0-based
            switch n {
            case 0: return Array("\u{1B}OP".utf8)
            case 1: return Array("\u{1B}OQ".utf8)
            case 2: return Array("\u{1B}OR".utf8)
            case 3: return Array("\u{1B}OS".utf8)
            default:
                // F5.. use CSI codes with gaps (15,17,18,19,20,21,23,24)
                let codes = [15, 17, 18, 19, 20, 21, 23, 24]
                return Array("\u{1B}[\(codes[n - 4])~".utf8)
            }
        }

        // Character input: the keymap already applied modifiers, so Ctrl+C
        // arrives as 0x03, Shift+a as "A", etc. Write the UTF-8 bytes as-is.
        if let character = keyData.character, !character.isEmpty {
            return Array(character.utf8)
        }

        return nil  // bare modifier or unmapped special key
    }

    private static func _cursor(_ letter: String, _ appCursor: Bool) -> [UInt8] {
        return Array((appCursor ? "\u{1B}O\(letter)" : "\u{1B}[\(letter)").utf8)
    }
}
