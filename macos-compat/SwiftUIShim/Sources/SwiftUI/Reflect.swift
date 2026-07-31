// Tree-flattening helpers for the _makeView render path (MakeView.swift). Rendering
// itself now goes through the real View._makeView witness recursion; the only place
// we still need Mirror / closure-expansion is flattening the @ViewBuilder grouping
// types — TupleView (a tuple of views), ForEach (a closure per element), and Group
// (a transparent wrapper) — into a flat child list, since we have no Apple variadic
// `_makeViewList` machinery to reuse.

import Foundation

protocol _AnyTuple { var _elements: [any View] { get } }
extension TupleView: _AnyTuple {
    var _elements: [any View] {
        Mirror(reflecting: value).children.compactMap { $0.value as? any View }
    }
}

protocol _ForEachExpandable { var _expanded: [any View] { get } }
extension ForEach: _ForEachExpandable where Content: View {
    var _expanded: [any View] { data.map { content($0) } }
}
extension Group: _ForEachExpandable where Content: View {
    var _expanded: [any View] { _stackChildren(content) }   // transparent: children join the parent
}

// A container's children, flattening TupleView / ForEach / Group inline.
func _stackChildren(_ content: any View) -> [any View] {
    _stackChildren2((content as? _AnyTuple)?._elements ?? [content])
}
func _stackChildren2(_ views: [any View]) -> [any View] {
    views.flatMap { v -> [any View] in
        if let fe = v as? _ForEachExpandable { return _stackChildren2(fe._expanded) }
        if let tup = v as? _AnyTuple { return _stackChildren2(tup._elements) }
        return [v]
    }
}

protocol _AnyWindowGroup { var _rootView: any View { get } }
extension WindowGroup: _AnyWindowGroup { var _rootView: any View { content } }
