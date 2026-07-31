import SwiftUI
@main struct A: App { var body: some Scene { WindowGroup { CV() } } }
struct CV: View { var body: some View { Circle().fill(Color.red).frame(width: 40, height: 40) } }
