import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @State var s = 0
  var body: some View { Picker("Pick", selection: $s) { Text("One").tag(0); Text("Two").tag(1) } } }
