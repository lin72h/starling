import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { var body: some View {
  ScrollView { LazyVStack { ForEach(0..<3) { i in Text("\(i)") } } } } }
