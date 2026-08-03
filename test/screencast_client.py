#!/usr/bin/env python3
"""Drive org.freedesktop.portal.ScreenCast the way a real consumer does.

One D-Bus connection for the whole handshake (the request paths embed the
sender's unique name, so hopping connections per call — busctl's model —
cannot follow the Response signals). CreateSession -> SelectSources ->
Start, then print what a consumer needs as JSON on stdout:

    {"session": "/org/...", "node": 42, "width": 1920, "height": 1080}

The session is deliberately left open on exit — the caller pulls frames
from the node and closes the session itself (Session.Close accepts any
connection; the portal does not tie sessions to a sender).

Usage: screencast_client.py unix:path=/tmp/xdg-starling-1000/bus
"""

import json
import sys

import gi  # noqa: F401
from gi.repository import Gio, GLib

PORTAL = "org.freedesktop.portal.Desktop"
OPATH = "/org/freedesktop/portal/desktop"
SCREENCAST = "org.freedesktop.portal.ScreenCast"
REQUEST = "org.freedesktop.portal.Request"


def main() -> None:
    addr = sys.argv[1]
    conn = Gio.DBusConnection.new_for_address_sync(
        addr,
        Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT
        | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION,
        None, None)
    sender = conn.get_unique_name()[1:].replace(".", "_")
    loop = GLib.MainLoop()

    def wait_response(token: str, method: str, args: GLib.Variant) -> dict:
        """Subscribe on the predictable request path, then call — the
        AddMatch is queued on this connection before the method call, so
        the instant Response cannot be missed."""
        path = f"{OPATH}/request/{sender}/{token}"
        got = {}

        def on_signal(_c, _s, _p, _i, _sig, params):
            got["resp"] = params.unpack()
            loop.quit()

        sub = conn.signal_subscribe(PORTAL, REQUEST, "Response", path, None,
                                    Gio.DBusSignalFlags.NONE, on_signal)
        conn.call_sync(PORTAL, OPATH, SCREENCAST, method, args,
                       None, Gio.DBusCallFlags.NONE, 5000, None)
        timeout = GLib.timeout_add_seconds(10, lambda: loop.quit() or True)
        loop.run()
        GLib.source_remove(timeout)
        conn.signal_unsubscribe(sub)
        assert "resp" in got, f"{method}: no Response on {path}"
        code, results = got["resp"]
        assert code == 0, f"{method}: response code {code}"
        return results

    res = wait_response("t1", "CreateSession", GLib.Variant("(a{sv})", ({
        "handle_token": GLib.Variant("s", "t1"),
        "session_handle_token": GLib.Variant("s", "s1"),
    },)))
    session = res["session_handle"]

    wait_response("t2", "SelectSources", GLib.Variant("(oa{sv})", (session, {
        "handle_token": GLib.Variant("s", "t2"),
        "types": GLib.Variant("u", 1),        # MONITOR
        "cursor_mode": GLib.Variant("u", 2),  # EMBEDDED
    })))

    res = wait_response("t3", "Start", GLib.Variant("(osa{sv})", (session, "", {
        "handle_token": GLib.Variant("s", "t3"),
    })))
    streams = res["streams"]
    assert streams, "Start succeeded but carried no streams"
    node, props = streams[0]
    width, height = props["size"]

    print(json.dumps({"session": session, "node": node,
                      "width": width, "height": height}))


if __name__ == "__main__":
    main()
