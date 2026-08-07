// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(Windows)

import Flutter
import FlutterWin32Bridge

/// `Clipboard` for a Flutter-Swift app in a Win32 window, over the system
/// clipboard — so copy and paste reach the rest of Windows.
///
/// Installed by `Win32WindowedHost.install()`.
///
/// Note the shape difference from the other two backends: Win32 hands the data
/// over directly rather than asking the current owner to write it, so a read
/// cannot block on another process and the completion runs inline. The
/// callback signature is kept anyway, because `ClipboardProvider` is what the
/// asynchronous backends need and one protocol beats two.
public final class Win32ClipboardProvider: ClipboardProvider {
    public init() {}

    public func setText(_ text: String) {
        _ = text.withCString { flwin32_clipboard_set_text($0) }
    }

    public func getText(_ completion: @escaping (String?) -> Void) {
        // Grow rather than truncate: -1 means the buffer was too small, and a
        // silently clipped paste is worse than a slow one. The cap stops a
        // pathological clipboard from being copied forever.
        var capacity = 64 * 1024
        while capacity <= 64 * 1024 * 1024 {
            var buffer = [CChar](repeating: 0, count: capacity)
            let written = buffer.withUnsafeMutableBufferPointer { buf in
                flwin32_clipboard_get_text(buf.baseAddress, Int32(buf.count))
            }
            if written == -1 {
                capacity *= 4
                continue
            }
            if written <= 0 {
                completion(nil)       // no text on the clipboard
                return
            }
            completion(String(cString: buffer))
            return
        }
        completion(nil)
    }
}

#endif
