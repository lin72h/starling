// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter

// MARK: - Themed root

/// Re-themes the editor when the parent shell pushes an appearance change
/// over the DMA-BUF socket (same pattern as SettingsApp / CalculatorApp).
/// Rooted in FluentApp so the toolbar's FluentTextBox finds its theme.
class ThemedEditorRoot: StatefulWidget {
    override func createState() -> State<StatefulWidget> {
        return _ThemedEditorRootState()
    }
}

class _ThemedEditorRootState: State<StatefulWidget> {
    private var _dark = true

    override func initState() {
        super.initState()
        #if os(Linux)
        if let dark = GpuDmaBufRenderer.lastPushedThemeIsDark {
            _dark = dark
        }
        GpuDmaBufRenderer.onThemeChanged = { [weak self] dark in
            guard let self, self._dark != dark else { return }
            self.setState { self._dark = dark }
        }
        #endif
    }

    override func build(_ context: any BuildContext) -> Widget {
        return FluentApp(
            themeMode: _dark ? .dark : .light,
            home: TextEditorApp(),
            title: "Text Editor"
        )
    }
}

runApp(ThemedEditorRoot())
