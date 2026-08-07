#!/usr/bin/env python3
"""A wl_data_device clipboard client, standing in for Chrome.

    clipboard_gtk_client.py --check-gtk   exit 0 if GTK 3 bindings are usable
    clipboard_gtk_client.py --read        map a window, read the selection,
                                          print GOT:<text>

Why GTK and not wl-paste: wl-clipboard speaks zwlr_data_control, which is
focus-free and is handed the selection the moment it binds. Chrome, Electron
and every GTK/Qt app speak **wl_data_device**, which is focus-based — and that
is the path that shipped broken, where a client starting after a copy never
learned a selection existed. Only a wl_data_device client can catch that
regression, so the test needs one.

The window is real and gets clicked on purpose. Keyboard focus in this
compositor is lazy (sent from the first keystroke), so pointer enter is what
actually triggers the compositor to hand a late-arriving client the selection.
A windowless client, or one nobody points at, legitimately reads nothing.
"""

import sys

if "--check-gtk" in sys.argv:
    try:
        import gi
        # Both, and before either import: GTK 4 is also installed here, and
        # importing Gdk without pinning it loads 4.0 — after which requiring
        # 3.0 raises. That failure looked exactly like "the compositor never
        # offered the selection".
        gi.require_version("Gtk", "3.0")
        gi.require_version("Gdk", "3.0")
        from gi.repository import Gdk, Gtk  # noqa: F401
    except Exception as exc:  # noqa: BLE001
        print(f"gtk unavailable: {exc}", file=sys.stderr)
        sys.exit(1)
    sys.exit(0)

import gi  # noqa: E402

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

READ_FALLBACK_S = 12   # read anyway if nothing ever clicks us
HARD_STOP_S = 22

state = {"asked": False, "done": False}


def _finish(text):
    if state["done"]:
        return
    state["done"] = True
    print(f"GOT:{text if text is not None else ''}", flush=True)
    Gtk.main_quit()


def _on_text(_clipboard, text):
    _finish(text)


def _ask():
    """Request the selection. Idempotent — a click and the fallback timer can
    both fire, and asking twice would print two answers."""
    if state["asked"] or state["done"]:
        return False
    state["asked"] = True
    Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD).request_text(_on_text)
    return False


def _on_click(_widget, _event):
    # Give the compositor a moment to deliver the offer that rides this
    # interaction before asking for its contents.
    GLib.timeout_add(700, _ask)
    return False


def main() -> int:
    win = Gtk.Window(title="starling clipboard check")
    win.set_default_size(420, 220)
    win.add(Gtk.Label(label="clipboard check"))
    win.add_events(Gdk.EventMask.BUTTON_PRESS_MASK
                   | Gdk.EventMask.ENTER_NOTIFY_MASK)
    win.connect("button-press-event", _on_click)
    win.connect("enter-notify-event", _on_click)
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    win.present()
    print("READY", flush=True)

    GLib.timeout_add_seconds(READ_FALLBACK_S, _ask)
    GLib.timeout_add_seconds(HARD_STOP_S, lambda: _finish(None))
    Gtk.main()
    if not state["done"]:
        print("GOT:", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
