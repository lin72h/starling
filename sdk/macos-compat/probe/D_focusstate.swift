import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @FocusState var f: Bool
  @State var s = ""
  var body: some View { TextField("t", text: $s).focused($f) } }
