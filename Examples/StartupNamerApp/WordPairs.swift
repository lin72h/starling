// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// A miniature port of the `english_words` package's word-pair generator —
// just enough of it for the Startup Name Generator: random adjective+noun
// pairs with the PascalCase rendering the codelab displays.

// struct WordPair, english_words' pair of words.
struct WordPair: Hashable {
    let first: String
    let second: String

    /// "cheaplight" → "CheapLight", the form the codelab renders.
    var asPascalCase: String {
        return first.capitalized + second.capitalized
    }
}

private let _adjectives = [
    "air", "bold", "brave", "bright", "broad", "calm", "cheap", "chief",
    "clean", "clear", "cool", "deep", "fair", "fast", "fine", "firm",
    "fresh", "glad", "grand", "great", "green", "high", "keen", "kind",
    "light", "lone", "long", "loud", "neat", "new", "nice", "plain",
    "proud", "pure", "quick", "quiet", "rare", "rich", "ripe", "safe",
    "sharp", "smart", "soft", "solid", "sound", "swift", "true", "warm",
    "wide", "wise",
]

private let _nouns = [
    "beam", "bloom", "brook", "cloud", "craft", "dawn", "drift", "ember",
    "field", "fire", "flare", "forge", "frame", "frost", "gate", "glade",
    "grove", "haven", "hill", "lake", "leaf", "light", "mind", "mist",
    "moon", "night", "path", "peak", "pine", "point", "rain", "ridge",
    "river", "shade", "shore", "sky", "snow", "spark", "spring", "star",
    "stone", "storm", "stream", "trail", "vale", "wave", "wind", "wood",
    "word", "world",
]

/// generateWordPairs().take(n), near enough: `n` random pairs.
func generateWordPairs(take count: Int) -> [WordPair] {
    var pairs: [WordPair] = []
    pairs.reserveCapacity(count)
    for _ in 0..<count {
        pairs.append(WordPair(
            first: _adjectives.randomElement()!,
            second: _nouns.randomElement()!
        ))
    }
    return pairs
}
