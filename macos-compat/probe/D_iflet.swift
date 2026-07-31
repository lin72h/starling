import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { @State var n: String? = "x"
  var body: some View { VStack { if let n { Text(n) } } } }
