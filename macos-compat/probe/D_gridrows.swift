import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { var body: some View { Grid { GridRow { Text("a"); Text("b") }; GridRow { Text("c"); Text("d") } } } }
