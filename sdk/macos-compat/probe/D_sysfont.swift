import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { var body: some View { Text("sys").font(.system(size: 24, weight: .bold)) } }
