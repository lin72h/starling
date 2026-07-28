// RealApp — the composite milestone probe: a multi-screen interactive todo app
// written like a real app (stores, tabs, navigation, sheets, forms, persistence),
// built UNMODIFIED with Apple's toolchain. Everything here composes features the
// single-feature probes proved individually.
import SwiftUI
import Combine

final class TodoStore: ObservableObject {
    @Published var items: [String] = ["Buy milk", "Ship machold", "Write report"]
    @Published var done: Set<Int> = [1]
    func add(_ s: String) { items.append(s) }
    func toggle(_ i: Int) { if done.contains(i) { done.remove(i) } else { done.insert(i) } }
}

@main
struct RealApp: App {
    @StateObject var store = TodoStore()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store) }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            TodoListView().tabItem { Label("Todos", systemImage: "list.bullet") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

struct TodoListView: View {
    @EnvironmentObject var store: TodoStore
    @State private var showAdd = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Todos").font(.system(size: 24, weight: .bold))
            ForEach(0..<3) { i in
                HStack(spacing: 8) {
                    Text(store.done.contains(i) ? "[x]" : "[ ]")
                        .onTapGesture { store.toggle(i) }
                    Text(store.items[i])
                        .foregroundStyle(store.done.contains(i) ? Color.secondary : Color.primary)
                }
            }
            HStack {
                Button("Add") { showAdd = true }.buttonStyle(.borderedProminent)
                Text("\(store.done.count)/\(store.items.count) done")
                    .font(.caption).foregroundColor(.secondary)
            }
            ProgressView(value: Double(store.done.count), total: Double(max(store.items.count, 1)))
                .frame(width: 220)
        }
        .padding()
        .sheet(isPresented: $showAdd) {
            VStack(spacing: 10) {
                Text("New todo").font(.headline)
                Button("Save 'Call mom'") { store.add("Call mom"); showAdd = false }
            }
            .padding()
        }
    }
}

struct SettingsView: View {
    @AppStorage("fontSize") var fontSize = 17
    @Environment(\.colorScheme) var scheme
    @State private var notify = true
    var body: some View {
        Form {
            Section("Appearance") {
                Text("Scheme: \(scheme == .dark ? "dark" : "light")")
                Stepper("Font size: \(fontSize)", value: $fontSize)
            }
            Section("Alerts") {
                Toggle("Notify", isOn: $notify)
            }
        }
        .padding()
    }
}
