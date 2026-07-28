import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { var body: some View { Text("a very long line of text that wraps around").lineLimit(1) } }
