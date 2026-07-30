// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0
//
// A native Linux app written in Swift against the Flutter framework port.
// Build it and run it — no Dart, no shell, no desktop environment required:
//
//     swift build -c release && .build/release/HelloWindow
//
// The same binary runs on X11 and on Wayland; GLFW picks the backend from the
// environment at startup. Run it inside the Starling desktop and it renders
// through the compositor instead, without a rebuild.

import Flutter
import FlutterRunner

// ─── A counter, the smallest thing with state ────────────────────────────────

class Counter: StatefulWidget {
    override func createState() -> State<StatefulWidget> { CounterState() }
}

class CounterState: State<StatefulWidget> {
    private var count = 0

    override func build(_ context: any BuildContext) -> Widget {
        let theme = FluentTheme.of(context)
        return ScaffoldPage(
            content: Center(
                child: Column(
                    mainAxisAlignment: .center,
                    children: [
                        Text("You have pushed the button", style: theme.typography.body),
                        SizedBox(height: 8),
                        Text("\(count)", style: theme.typography.titleLarge),
                        SizedBox(height: 24),
                        FilledButton(
                            onPressed: { [self] in setState { count += 1 } },
                            child: Text("Push me")
                        ),
                    ]
                )
            )
        )
    }
}

// ─── Entry point ─────────────────────────────────────────────────────────────

runAppWindowed(
    FluentApp(home: Counter(), title: "Hello, Swift"),
    options: WindowOptions(title: "Hello, Swift", width: 720, height: 480)
)
