// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(Linux)

import Flutter
import FlutterGTKBridge

/// `Clipboard` for an app in an ordinary GTK window, backed by GtkClipboard —
/// so a FlutterSwift app on GNOME or KDE copies and pastes with everything else
/// on that desktop, not just with itself.
///
/// Installed by `GTKWindowedHost.install()`. The Starling shell path uses
/// `WaylandClipboardProvider` instead; a dma-buf child has no GTK.
public final class GtkClipboardProvider: ClipboardProvider {
    public init() {}

    public func setText(_ text: String) {
        text.withCString { flgtk_clipboard_set_text($0) }
    }

    public func getText(_ completion: @escaping (String?) -> Void) {
        // GTK calls back on the GLib main loop, which is the UI thread here, so
        // the completion is invoked directly. Hopping through
        // DispatchQueue.main would be actively wrong: nothing drains GCD's main
        // queue under gtk_main, so the paste would never arrive.
        let box = Unmanaged.passRetained(_GtkTextBox(completion)).toOpaque()
        flgtk_clipboard_get_text({ ctx, text in
            guard let ctx = ctx else { return }
            let boxed = Unmanaged<_GtkTextBox>.fromOpaque(ctx).takeRetainedValue()
            boxed.completion(text.map { String(cString: $0) })
        }, box)
    }
}

/// Carries a Swift closure through the C callback's `void*`.
private final class _GtkTextBox {
    let completion: (String?) -> Void
    init(_ completion: @escaping (String?) -> Void) { self.completion = completion }
}

#endif
