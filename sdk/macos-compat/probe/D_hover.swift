import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @State var h = false
  var body: some View { Text(h ? "in" : "out").onHover { h = $0 } } }
