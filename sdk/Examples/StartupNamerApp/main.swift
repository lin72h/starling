// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// Startup Name Generator — the app built in Google's original "Write your
// first Flutter app" codelab (startup_namer), ported from Dart to
// FlutterSwift. The famous bits are all here: an infinite lazily-built
// ListView of generated word pairs with dividers on odd rows, a heart to
// favorite a name, and a second "Saved Suggestions" route pushed from the
// app-bar list action.
//
//   swift run -c release StartupNamerApp

#if os(Linux)
import CupertinoIcons
import ExampleHost
import Flutter
import FlutterSwiftBridge

let _biggerFont = Flutter.TextStyle(color: MaterialColors.body, fontSize: 18)

// class RandomWords extends StatefulWidget
class RandomWords: StatefulWidget {
    override func createState() -> State<StatefulWidget> {
        return _RandomWordsState()
    }
}

// class _RandomWordsState extends State<RandomWords>
class _RandomWordsState: State<StatefulWidget> {
    private var _suggestions: [WordPair] = []
    private var _saved: Set<WordPair> = []

    /// The codelab's ListTile row: PascalCase name, heart on the trailing
    /// edge, tap toggling the favorite.
    private func _buildRow(_ pair: WordPair) -> Widget {
        let alreadySaved = _saved.contains(pair)
        return GestureDetector(
            onTap: { [weak self] in
                guard let self = self else { return }
                self.setState {
                    if alreadySaved {
                        self._saved.remove(pair)
                    } else {
                        self._saved.insert(pair)
                    }
                }
                print("[StartupNamer] \(alreadySaved ? "unsaved" : "saved") \(pair.asPascalCase)")
            },
            behavior: .opaque,
            child: SizedBox(
                height: 56,
                child: Padding(
                    padding: EdgeInsets(horizontal: 16),
                    child: Row(children: [
                        Expanded(child: Text(pair.asPascalCase, style: _biggerFont, maxLines: 1)),
                        Icon(
                            alreadySaved ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                            color: alreadySaved ? MaterialColors.red : MaterialColors.headline
                        ),
                    ])
                )
            )
        )
    }

    /// ListView.builder with the codelab's odd-index Divider trick; the
    /// suggestion list grows by ten pairs whenever scrolling reaches its end.
    /// The Dart original is unbounded; this port caps at a thousand pairs
    /// because the framework's scroll-extent estimation needs a child count.
    private func _buildSuggestions() -> Widget {
        return ListView(
            padding: EdgeInsets(all: 16),
            itemCount: 2000,
            itemBuilder: { [weak self] _, i in
                guard let self = self else { return nil }
                if i % 2 == 1 { return MaterialDivider() }
                let index = i / 2
                if index >= self._suggestions.count {
                    self._suggestions.append(contentsOf: generateWordPairs(take: 10))
                }
                return self._buildRow(self._suggestions[index])
            }
        )
    }

    /// Pushes the Saved Suggestions route, as the codelab's _pushSaved does.
    private func _pushSaved(_ context: any BuildContext) {
        Navigator.of(context).push(MaterialPageRoute(builder: { [weak self] routeContext in
            var tiles: [Widget] = []
            for pair in (self?._saved ?? []).sorted(by: { $0.asPascalCase < $1.asPascalCase }) {
                if !tiles.isEmpty { tiles.append(MaterialDivider()) }
                tiles.append(SizedBox(
                    height: 56,
                    child: Padding(
                        padding: EdgeInsets(horizontal: 16),
                        child: Row(children: [
                            Expanded(child: Text(pair.asPascalCase, style: _biggerFont, maxLines: 1))
                        ])
                    )
                ))
            }
            return MaterialScaffold(
                appBar: MaterialAppBar(
                    title: "Saved Suggestions",
                    leading: GestureDetector(
                        onTap: { Navigator.pop(routeContext) },
                        behavior: .opaque,
                        child: Icon(CupertinoIcons.back, color: MaterialColors.onPrimary)
                    )
                ),
                body: ListView(children: tiles)
            )
        }))
    }

    override func build(_ context: any BuildContext) -> Widget {
        return MaterialScaffold(
            appBar: MaterialAppBar(
                title: "Startup Name Generator",
                actions: [
                    GestureDetector(
                        onTap: { [weak self] in self?._pushSaved(context) },
                        behavior: .opaque,
                        child: Icon(CupertinoIcons.list_bullet, color: MaterialColors.onPrimary)
                    )
                ]
            ),
            body: _buildSuggestions()
        )
    }
}

// class MyApp extends StatelessWidget — MaterialApp(home: RandomWords()),
// with the Navigator that MaterialApp would otherwise provide.
class MyApp: StatelessWidget {
    override func build(_ context: any BuildContext) -> Widget {
        return Directionality(
            textDirection: .ltr,
            child: Navigator(home: RandomWords())
        )
    }
}

runExampleApp(title: "Startup Name Generator", width: 480, height: 720) { MyApp() }

#else
fatalError("The example apps currently target Linux desktop sessions.")
#endif
