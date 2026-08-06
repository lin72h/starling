// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge
import Foundation

#if os(Windows)
import FlutterWin32

// Windows has no Starling shell to be a child of, so the app always opens its
// own window through the engine's Win32 embedder. install() fills in the
// host-neutral hooks runStarlingApp dispatches through.
Win32WindowedHost.install()
runStarlingApp(title: "Terminal", width: 900, height: 600) {
    MacosApp(
        theme: MacosThemeData.dark(),
        home: TerminalApp()
    )
}
#else
runApp(
    MacosApp(
        theme: MacosThemeData.dark(),
        home: TerminalApp()
    )
)
#endif
