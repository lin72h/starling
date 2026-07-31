import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @State var s = "edit me"
  var body: some View { TextEditor(text: $s) } }
