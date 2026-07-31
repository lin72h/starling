import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { var body: some View {
  LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) { Text("a"); Text("b"); Text("c") } } }
