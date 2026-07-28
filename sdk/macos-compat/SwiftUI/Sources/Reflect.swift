// Milestone 2a: reflection-based introspection of an unmodified app's view tree.
//
// App.main() instantiates the app type, reads its `body` (a WindowGroup), pulls
// out the root View, and walks the SwiftUI hierarchy — proving we can extract the
// real UI structure of a binary we did not compile. This is the precursor to
// translating the tree into Flutter widgets (the actual bridge).

import Foundation

// MARK: - Erased body access (only ever called on non-primitive user views)

extension View {
    func _erasedBody() -> any View { body }
}

// MARK: - Structural nodes exposed by our primitive views

enum _Node {
    case text(String)
    case empty
    case vstack(spacing: CGFloat?, children: [any View])
    case button(label: any View, action: () -> Void)
    case padding(edges: Edge.Set, length: CGFloat?, content: any View)
    case passthrough(any View)
}

protocol _PrimitiveNode {
    var _node: _Node { get }
}

protocol _AnyTuple {
    var _elements: [any View] { get }
}
extension TupleView: _AnyTuple {
    var _elements: [any View] {
        Mirror(reflecting: value).children.compactMap { $0.value as? any View }
    }
}

protocol _AnyWindowGroup {
    var _rootView: any View { get }
}
extension WindowGroup: _AnyWindowGroup {
    var _rootView: any View { content }
}

extension Text: _PrimitiveNode {
    var _node: _Node { .text(_resolvedString) }
}
extension EmptyView: _PrimitiveNode {
    var _node: _Node { .empty }
}
extension VStack: _PrimitiveNode {
    var _node: _Node {
        let kids = (content as? _AnyTuple)?._elements ?? [content]
        return .vstack(spacing: spacing, children: kids)
    }
}
extension Button: _PrimitiveNode {
    var _node: _Node { .button(label: label, action: action) }
}
extension ModifiedContent: _PrimitiveNode where Content: View, Modifier: ViewModifier {
    var _node: _Node {
        if let pad = modifier as? _PaddingLayout {
            return .padding(edges: pad.edges, length: pad.insets, content: content)
        }
        return .passthrough(content)
    }
}

// MARK: - Tree walk

func _walk(_ v: any View, depth: Int) {
    let pad = String(repeating: "│  ", count: depth)
    if let node = (v as? _PrimitiveNode)?._node {
        switch node {
        case .text(let s):
            print("\(pad)Text(\"\(s)\")")
        case .empty:
            print("\(pad)EmptyView")
        case .vstack(let spacing, let kids):
            let sp = spacing.map { String(describing: $0) } ?? "default"
            print("\(pad)VStack(spacing: \(sp))")
            for k in kids { _walk(k, depth: depth + 1) }
        case .button(let label, _):
            print("\(pad)Button")
            _walk(label, depth: depth + 1)
        case .padding(let edges, let length, let content):
            let len = length.map { String(describing: $0) } ?? "system-default"
            print("\(pad).padding(edges: 0b\(String(edges.rawValue, radix: 2)), length: \(len))")
            _walk(content, depth: depth + 1)
        case .passthrough(let content):
            _walk(content, depth: depth + 1)
        }
    } else {
        print("\(pad)<\(type(of: v))>  (user view → reading .body)")
        _walk(v._erasedBody(), depth: depth + 1)
    }
}

// First button action found in the tree (for the @State round-trip demo).
func _firstButtonAction(_ v: any View) -> (() -> Void)? {
    if let node = (v as? _PrimitiveNode)?._node {
        switch node {
        case .button(_, let action): return action
        case .vstack(_, let kids):
            for k in kids { if let a = _firstButtonAction(k) { return a } }
            return nil
        case .padding(_, _, let content): return _firstButtonAction(content)
        case .passthrough(let content): return _firstButtonAction(content)
        case .text, .empty: return nil
        }
    }
    return _firstButtonAction(v._erasedBody())
}

// MARK: - Entry from App.main()

func _reflectAndDump<A: App>(_ app: A) {
    let scene = app.body
    guard let wg = scene as? _AnyWindowGroup else {
        print("⚠️  unsupported scene type: \(type(of: scene))")
        return
    }
    let root = wg._rootView

    print("\n─── reflected SwiftUI view tree (from unmodified binary) ───")
    _walk(root, depth: 0)

    // Demonstrate that @State round-trips through our reimplementation:
    // re-read the tree, fire the first button's action, re-read.
    if let action = _firstButtonAction(root) {
        print("\n─── firing first Button action (simulating a click) ───")
        action()
        print("─── re-walking tree (note the @State change) ───")
        _walk(root, depth: 0)
    }
    print("───────────────────────────────────────────────────────────\n")
}
