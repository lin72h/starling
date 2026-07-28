// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// MARK: - ErrorWidget Builder

/// Signature for a function that creates a widget to display when an error occurs
/// during building.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:5472`
public typealias ErrorWidgetBuilder = (FlutterErrorDetails) -> Widget

// MARK: - ErrorWidget

/// A widget that renders an error message.
///
/// This widget is used when a build method fails, to display error information.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:5488`
public class ErrorWidget: LeafRenderObjectWidget {
    /// The message to display.
    public let message: String

    /// A builder that can be used to customize the error widget.
    nonisolated(unsafe) public static var builder: ErrorWidgetBuilder = { details in
        return ErrorWidget(details)
    }

    /// Creates an error widget from error details.
    public init(_ exception: Any) {
        if let details = exception as? FlutterErrorDetails {
            self.message = String(describing: details.exception)
        } else if let error = exception as? Error {
            self.message = String(describing: error)
        } else {
            self.message = String(describing: exception)
        }
        super.init()
    }

    /// Creates an error widget with a specific message.
    public init(message: String) {
        self.message = message
        super.init()
    }

    public override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return RenderErrorBox(message: message)
    }

    public override func updateRenderObject(
        _ context: any BuildContext, renderObject: RenderObject
    ) {
        // RenderErrorBox is immutable, nothing to update
    }
}

// MARK: - ComponentElement

/// An `Element` that composes other `Element`s.
///
/// Rather than creating a `RenderObject` directly, a `ComponentElement` creates
/// `RenderObject`s indirectly by creating other `Element`s.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:5556`
open class ComponentElement: Element {
    /// The child element built by this component.
    internal var _child: Element?

    /// Subclasses should override this method to return the built widget.
    open func build() -> Widget {
        fatalError("Subclasses must override build()")
    }

    /// First build: called during mount to build the child.
    internal func _firstBuild() {
        rebuild()
    }

    open override func mount(_ parent: Element?, _ newSlot: Any?) {
        super.mount(parent, newSlot)
        _firstBuild()
    }

    open override func performRebuild() {
        let built = build()
        _dirty = false
        _child = updateChild(_child, newWidget: built, newSlot: _slot)
    }

    /// Returns the nearest `RenderObject` by walking down through the child.
    ///
    /// Component elements don't have their own render objects, so they
    /// delegate to their child element. This is critical for
    /// `MultiChildRenderObjectElement.insertRenderObjectChild`, which uses
    /// `findRenderObject()` on the previous sibling to determine insertion
    /// order in the render object child list.
    ///
    /// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:4421`
    open override func findRenderObject() -> RenderObject? {
        return _child?.findRenderObject()
    }

    open override func visitChildElements(_ visitor: (Element) -> Void) {
        if let child = _child {
            visitor(child)
        }
    }

    open override func forgetChild(_ child: Element) {
        assert(child === _child)
        _child = nil
        super.forgetChild(child)
    }
}

// MARK: - StatelessElement

/// An `Element` that uses a `StatelessWidget` as its configuration.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:5570`
open class StatelessElement: ComponentElement {
    /// Creates an element that uses the given widget as its configuration.
    public init(_ widget: StatelessWidget) {
        super.init(widget)
    }

    open override func build() -> Widget {
        return (widget as! StatelessWidget).build(self)
    }

    open override func update(_ newWidget: Widget) {
        super.update(newWidget)
        _dirty = true
        rebuild()
    }
}

// MARK: - StatefulElement

/// An `Element` that uses a `StatefulWidget` as its configuration.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:5601`
open class StatefulElement: ComponentElement {
    /// The `State` instance associated with this element.
    ///
    /// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:5616`
    public let state: State<StatefulWidget>

    /// Whether `didChangeDependencies` has been called since the last build.
    internal var _didChangeDependencies = false

    /// Creates an element for the given `StatefulWidget`.
    public init(_ widget: StatefulWidget) {
        let createdState = widget.createState()
        self.state = createdState
        super.init(widget)
        // Set up the state's references to this element and widget
        createdState.context = self
        createdState.widget = widget
    }

    open override func build() -> Widget {
        return state.build(self)
    }

    internal override func _firstBuild() {
        state._debugLifecycleState = .created
        state.initState()
        state._debugLifecycleState = .initialized
        state.didChangeDependencies()
        state._debugLifecycleState = .ready
        state.mounted = true
        super._firstBuild()
    }

    open override func performRebuild() {
        if _didChangeDependencies {
            state.didChangeDependencies()
            _didChangeDependencies = false
        }
        super.performRebuild()
    }

    open override func update(_ newWidget: Widget) {
        let oldWidget = widget as! StatefulWidget
        super.update(newWidget)
        let newStatefulWidget = newWidget as! StatefulWidget
        state.widget = newStatefulWidget
        state.didUpdateWidget(oldWidget)
        _dirty = true
        rebuild()
    }

    open override func activate() {
        super.activate()
        state.activate()
        state.mounted = true
        markNeedsBuild()
    }

    open override func deactivate() {
        state.deactivate()
        super.deactivate()
    }

    open override func unmount() {
        super.unmount()
        state.dispose()
        state._debugLifecycleState = .defunct
        state.context = nil
        state.mounted = false
    }

    open override func didChangeDependencies() {
        super.didChangeDependencies()
        _didChangeDependencies = true
    }
}

// MARK: - Builder

/// A platonic widget that calls a closure to obtain its child widget.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/basic.dart:8301-8316`
public class Builder: StatelessWidget {
    /// Called to obtain the child widget.
    ///
    /// **Dart Source:** `basic.dart:8312`
    public let builder: WidgetBuilder

    /// Creates a widget that delegates its build to a callback.
    ///
    /// **Dart Source:** `basic.dart:8303`
    public init(key: (any Key)? = nil, builder: @escaping WidgetBuilder) {
        self.builder = builder
        super.init(key: key)
    }

    /// **Dart Source:** `basic.dart:8315`
    public override func build(_ context: any BuildContext) -> Widget {
        return builder(context)
    }
}

// MARK: - Additional Typealiases

/// Signature for `IndexedWidgetBuilder`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:152`
public typealias IndexedWidgetBuilder = (any BuildContext, Int) -> Widget

/// Signature for `NullableIndexedWidgetBuilder`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:155`
public typealias NullableIndexedWidgetBuilder = (any BuildContext, Int) -> Widget?

/// Signature for `TransitionBuilder`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:158`
public typealias TransitionBuilder = (any BuildContext, Widget?) -> Widget
