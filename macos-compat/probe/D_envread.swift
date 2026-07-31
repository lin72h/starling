import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @Environment(\.colorScheme) var cs
  var body: some View { Text(cs == .dark ? "dark" : "light") } }
