import SwiftUI
import Foundation

// Third probe (after Hello + Gallery): a SwiftUI app that USES Foundation — the first
// non-SwiftUI dependency on the road to running real, third-party macOS app binaries.
// It exercises a realistic Foundation surface so running it through machold reveals
// exactly which Foundation symbols bind to the Linux toolchain and which still need
// work. See linux/FOUNDATION-WORKLIST.md.
//
// Linux split note: the macOS binary imports these as `$s10Foundation…`; the Linux
// toolchain (swift-foundation) puts the core value types in FoundationEssentials and
// i18n in FoundationInternationalization. machold's resolver tries those module names
// as fallbacks. ObjC-bridged Foundation (NS* via the `So` mangling) won't resolve on
// Linux — this probe deliberately sticks to the Swift-native Foundation APIs.

@main
struct FoundationApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

struct Product: Codable, Identifiable {
    let id: Int
    let name: String
    let price: Double
}

struct ContentView: View {
    // @State default expression runs Foundation at view construction: Data + JSONDecoder
    // (Codable), UUID, Date.
    @State private var products: [Product] = ContentView.load()
    @State private var token: String = UUID().uuidString
    @State private var loadedAt: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Foundation Probe")
                .font(.largeTitle).fontWeight(.bold)
            Text("Session \(token.prefix(8))…  ·  \(Self.formatted(loadedAt))")
                .foregroundColor(.secondary)

            Divider()

            ForEach(products) { p in
                HStack {
                    Text(p.name)
                    Spacer()
                    Text(String(format: "$%.2f", p.price)).bold()
                }
            }

            HStack {
                Text("Total")
                Spacer()
                Text(String(format: "$%.2f", products.reduce(0) { $0 + $1.price })).bold()
            }

            Button("New session") {
                token = UUID().uuidString
                loadedAt = Date()
            }
        }
        .padding()
    }

    // JSON round-trip through Codable + Data (FoundationEssentials on Linux).
    static func load() -> [Product] {
        let json = Data("""
        [{"id":1,"name":"Coffee","price":3.5},
         {"id":2,"name":"Bagel","price":2.25},
         {"id":3,"name":"Orange Juice","price":4.0}]
        """.utf8)
        return (try? JSONDecoder().decode([Product].self, from: json)) ?? []
    }

    // Date formatting via the modern FormatStyle API (FoundationInternationalization).
    static func formatted(_ d: Date) -> String {
        d.formatted(date: .abbreviated, time: .shortened)
    }
}
