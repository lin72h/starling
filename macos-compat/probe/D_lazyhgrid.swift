import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { var body: some View { LazyHGrid(rows: [GridItem(.flexible())]) { Text("a"); Text("b") } } }
