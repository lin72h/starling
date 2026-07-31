import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { var body: some View {
  TabView { Text("a").tabItem { Text("A") }; Text("b").tabItem { Text("B") } } } }
