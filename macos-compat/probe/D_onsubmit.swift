import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @State var s = ""
  var body: some View { TextField("t", text: $s).onSubmit { } } }
