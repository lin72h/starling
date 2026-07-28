// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

/// Selection enums and value types for the rendering selection system.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/selection.dart`

// MARK: - SelectionResult

/// The result after handling a `SelectionEvent`.
///
/// `SelectionEvent`s are sent from `SelectionRegistrar` to be handled by
/// `SelectionHandler.dispatchSelectionEvent`. The subclasses of
/// `SelectionHandler` or `Selectable` must return appropriate
/// `SelectionResult`s after handling the events.
///
/// This is used by the `SelectionContainer` to determine how a selection
/// expands across its `Selectable` children.
///
/// **Dart Source:** `selection.dart:24-64`
public enum SelectionResult {
    /// There is nothing left to select forward in this `Selectable`, and further
    /// selection should extend to the next `Selectable` in screen order.
    ///
    /// This is used after subclasses `SelectionHandler` or `Selectable` handled
    /// `SelectionEdgeUpdateEvent`.
    ///
    /// **Dart Source:** `selection.dart:25-32`
    case next

    /// Selection does not reach this `Selectable` and is located before it in
    /// screen order.
    ///
    /// This is used after subclasses `SelectionHandler` or `Selectable` handled
    /// `SelectionEdgeUpdateEvent`.
    ///
    /// **Dart Source:** `selection.dart:34-38`
    case previous

    /// Selection ends in this `Selectable`.
    ///
    /// Part of the `Selectable` may or may not be selected, but there is still
    /// content to select forward or backward.
    ///
    /// This is used after subclasses `SelectionHandler` or `Selectable` handled
    /// `SelectionEdgeUpdateEvent`.
    ///
    /// **Dart Source:** `selection.dart:40-46`
    case end

    /// The result can't be determined in this frame.
    ///
    /// This is typically used when the subtree is scrolling to reveal more
    /// content.
    ///
    /// This is used after subclasses `SelectionHandler` or `Selectable` handled
    /// `SelectionEdgeUpdateEvent`.
    ///
    /// **Dart Source:** `selection.dart:48-56`
    case pending

    /// There is no result for the selection event.
    ///
    /// This is used when a selection result is not applicable, e.g.
    /// `SelectAllSelectionEvent`, `ClearSelectionEvent`, and
    /// `SelectWordSelectionEvent`.
    ///
    /// **Dart Source:** `selection.dart:58-63`
    case none
}

// MARK: - SelectionEventType

/// The type of a `SelectionEvent`.
///
/// Used by `SelectionEvent.type` to distinguish different types of events.
///
/// **Dart Source:** `selection.dart:377-415`
public enum SelectionEventType {
    /// An event to update the selection start edge.
    ///
    /// Used by `SelectionEdgeUpdateEvent`.
    ///
    /// **Dart Source:** `selection.dart:378-381`
    case startEdgeUpdate

    /// An event to update the selection end edge.
    ///
    /// Used by `SelectionEdgeUpdateEvent`.
    ///
    /// **Dart Source:** `selection.dart:383-386`
    case endEdgeUpdate

    /// An event to clear the current selection.
    ///
    /// Used by `ClearSelectionEvent`.
    ///
    /// **Dart Source:** `selection.dart:388-391`
    case clear

    /// An event to select all the available content.
    ///
    /// Used by `SelectAllSelectionEvent`.
    ///
    /// **Dart Source:** `selection.dart:393-396`
    case selectAll

    /// An event to select a word at the location
    /// `SelectWordSelectionEvent.globalPosition`.
    ///
    /// Used by `SelectWordSelectionEvent`.
    ///
    /// **Dart Source:** `selection.dart:398-402`
    case selectWord

    /// An event to select a paragraph at the location
    /// `SelectParagraphSelectionEvent.globalPosition`.
    ///
    /// Used by `SelectParagraphSelectionEvent`.
    ///
    /// **Dart Source:** `selection.dart:404-408`
    case selectParagraph

    /// An event that extends the selection by a specific `TextGranularity`.
    ///
    /// **Dart Source:** `selection.dart:410-411`
    case granularlyExtendSelection

    /// An event that extends the selection in a specific direction.
    ///
    /// **Dart Source:** `selection.dart:413-414`
    case directionallyExtendSelection
}

// MARK: - TextGranularity

/// The unit of how selection handles move in text.
///
/// The `GranularlyExtendSelectionEvent` uses this enum to describe how
/// `Selectable` should extend its selection.
///
/// **Dart Source:** `selection.dart:421-436`
public enum TextGranularity {
    /// Treats each character as an atomic unit when moving the selection handles.
    ///
    /// **Dart Source:** `selection.dart:422-423`
    case character

    /// Treats word as an atomic unit when moving the selection handles.
    ///
    /// **Dart Source:** `selection.dart:425-426`
    case word

    /// Treats a paragraph as an atomic unit when moving the selection handles.
    ///
    /// **Dart Source:** `selection.dart:428-429`
    case paragraph

    /// Treats each line break as an atomic unit when moving the selection handles.
    ///
    /// **Dart Source:** `selection.dart:431-432`
    case line

    /// Treats the entire document as an atomic unit when moving the selection handles.
    ///
    /// **Dart Source:** `selection.dart:434-435`
    case document
}

// MARK: - SelectionExtendDirection

/// The direction to extend a selection.
///
/// The `DirectionallyExtendSelectionEvent` uses this enum to describe how
/// `Selectable` should extend their selection.
///
/// **Dart Source:** `selection.dart:578-622`
public enum SelectionExtendDirection {
    /// Move one edge of the selection vertically to the previous adjacent line.
    ///
    /// For text selection, it should consider both soft and hard linebreak.
    ///
    /// See `DirectionallyExtendSelectionEvent.dx` on how to
    /// calculate the horizontal offset.
    ///
    /// **Dart Source:** `selection.dart:579-585`
    case previousLine

    /// Move one edge of the selection vertically to the next adjacent line.
    ///
    /// For text selection, it should consider both soft and hard linebreak.
    ///
    /// See `DirectionallyExtendSelectionEvent.dx` on how to
    /// calculate the horizontal offset.
    ///
    /// **Dart Source:** `selection.dart:587-593`
    case nextLine

    /// Move the selection edges forward to a certain horizontal offset in the
    /// same line.
    ///
    /// If there is no on-going selection, the selection must start with the first
    /// line (or equivalence of first line in a non-text selectable) and select
    /// toward the horizontal offset in the same line.
    ///
    /// The selectable that receives `DirectionallyExtendSelectionEvent` with this
    /// enum must return `SelectionResult.end`.
    ///
    /// See `DirectionallyExtendSelectionEvent.dx` on how to
    /// calculate the horizontal offset.
    ///
    /// **Dart Source:** `selection.dart:595-607`
    case forward

    /// Move the selection edges backward to a certain horizontal offset in the
    /// same line.
    ///
    /// If there is no on-going selection, the selection must start with the last
    /// line (or equivalence of last line in a non-text selectable) and select
    /// backward the horizontal offset in the same line.
    ///
    /// The selectable that receives `DirectionallyExtendSelectionEvent` with this
    /// enum must return `SelectionResult.end`.
    ///
    /// See `DirectionallyExtendSelectionEvent.dx` on how to
    /// calculate the horizontal offset.
    ///
    /// **Dart Source:** `selection.dart:609-621`
    case backward
}

// MARK: - SelectionStatus

/// The status that indicates whether there is a selection and whether the
/// selection is collapsed.
///
/// A collapsed selection means the selection starts and ends at the same
/// location.
///
/// **Dart Source:** `selection.dart:704-722`
public enum SelectionStatus: Sendable {
    /// The selection is not collapsed.
    ///
    /// For example if `{}` represent the selection edges:
    ///   `"ab{cd}"`, the collapsing status is `uncollapsed`.
    ///   `"{abcd}"`, the collapsing status is `uncollapsed`.
    ///
    /// **Dart Source:** `selection.dart:705-710`
    case uncollapsed

    /// The selection is collapsed.
    ///
    /// For example if `{}` represent the selection edges:
    ///   `"ab{}cd"`, the collapsing status is `collapsed`.
    ///   `"{}abcd"`, the collapsing status is `collapsed`.
    ///   `"abcd{}"`, the collapsing status is `collapsed`.
    ///
    /// **Dart Source:** `selection.dart:712-718`
    case collapsed

    /// No selection.
    ///
    /// **Dart Source:** `selection.dart:720-721`
    case none
}

// MARK: - TextSelectionHandleType

/// The type of selection handle to be displayed.
///
/// With mixed-direction text, both handles may be the same type. Examples:
///
/// * LTR text: `"the <quick brown> fox"`:
///   The `<` is drawn with the `left` type, the `>` with the `right`.
///
/// * RTL text: `"XOF <NWORB KCIUQ> EHT"`:
///   Same as above.
///
/// * Mixed text: `"<the NWOR<B KCIUQ fox"`:
///   Here `"the QUICK B"` is selected, but `"QUICK BROWN"` is RTL. Both are drawn
///   with the `left` type.
///
/// See also:
///
///  * `TextDirection`, which discusses left-to-right and right-to-left text in
///    more detail.
///
/// **Dart Source:** `selection.dart:913-922`
public enum TextSelectionHandleType: Sendable {
    /// The selection handle is to the left of the selection end point.
    ///
    /// **Dart Source:** `selection.dart:914-915`
    case left

    /// The selection handle is to the right of the selection end point.
    ///
    /// **Dart Source:** `selection.dart:917-918`
    case right

    /// The start and end of the selection are co-incident at this point.
    ///
    /// **Dart Source:** `selection.dart:920-921`
    case collapsed
}

// MARK: - SelectedContentRange

/// The selected content range in a `Selectable` or `SelectionHandler`.
///
/// The `SelectedContentRange` for a given `Selectable` or `SelectionHandler`
/// can be retrieved by calling `SelectionHandler.getSelection`.
///
/// **Dart Source:** `selection.dart:124-194`
public struct SelectedContentRange: Equatable, Hashable, Sendable {
    /// Creates a `SelectedContentRange` with the given values.
    ///
    /// Both `startOffset` and `endOffset` must be non-negative.
    ///
    /// **Dart Source:** `selection.dart:127-128`
    public init(startOffset: Int, endOffset: Int) {
        assert(startOffset >= 0 && endOffset >= 0)
        self.startOffset = startOffset
        self.endOffset = endOffset
    }

    /// The start of the selection relative to the start of the content.
    ///
    /// For example a `Text` widget's content is in the format of a `TextSpan` tree.
    /// If we select from the beginning of 'world' to the end of the '.' at the end
    /// of the `TextSpan` tree, the `SelectedContentRange` from
    /// `SelectionHandler.getSelection` will be relative to the text of the
    /// `TextSpan` tree, with `WidgetSpan` content being flattened.
    ///
    /// **Dart Source:** `selection.dart:130-163`
    public let startOffset: Int

    /// The end of the selection relative to the start of the content.
    ///
    /// **Dart Source:** `selection.dart:165-168`
    public let endOffset: Int
}

// MARK: - SelectedContent

/// The selected content in a `Selectable` or `SelectionHandler`.
///
/// **Dart Source:** `selection.dart:199-214`
public struct SelectedContent: Equatable, Sendable {
    /// Creates a selected content object.
    ///
    /// Only supports plain text.
    ///
    /// **Dart Source:** `selection.dart:203-204`
    public init(plainText: String) {
        self.plainText = plainText
    }

    /// The selected content in plain text format.
    ///
    /// **Dart Source:** `selection.dart:207`
    public let plainText: String
}

// MARK: - SelectionPoint

/// The geometry information of a selection point.
///
/// **Dart Source:** `selection.dart:843-890`
public struct SelectionPoint: Equatable, Hashable, Sendable {
    /// Creates a selection point object.
    ///
    /// **Dart Source:** `selection.dart:846-850`
    public init(localPosition: Offset, lineHeight: Double, handleType: TextSelectionHandleType) {
        self.localPosition = localPosition
        self.lineHeight = lineHeight
        self.handleType = handleType
    }

    /// The position of the selection point in the local coordinates of the
    /// containing `Selectable`.
    ///
    /// **Dart Source:** `selection.dart:854`
    public let localPosition: Offset

    /// The line height at the selection point.
    ///
    /// **Dart Source:** `selection.dart:857`
    public let lineHeight: Double

    /// The selection handle type that should be used at the selection point.
    ///
    /// This is used for building the mobile selection handle.
    ///
    /// **Dart Source:** `selection.dart:860-862`
    public let handleType: TextSelectionHandleType
}

// MARK: - SelectionGeometry

/// The geometry information of a selection.
///
/// The positions in geometry are in local coordinates of the `SelectionHandler`
/// or `Selectable`.
///
/// **Dart Source:** `selection.dart:733-840`
public struct SelectionGeometry: Equatable, Hashable, Sendable {
    /// Creates a selection geometry object.
    ///
    /// If any of the `startSelectionPoint` and `endSelectionPoint` is not nil,
    /// the `status` must not be `.none`.
    ///
    /// **Dart Source:** `selection.dart:738-747`
    public init(
        startSelectionPoint: SelectionPoint? = nil,
        endSelectionPoint: SelectionPoint? = nil,
        selectionRects: [Rect] = [],
        status: SelectionStatus,
        hasContent: Bool
    ) {
        assert(
            (startSelectionPoint == nil && endSelectionPoint == nil)
                || status != .none
        )
        self.startSelectionPoint = startSelectionPoint
        self.endSelectionPoint = endSelectionPoint
        self.selectionRects = selectionRects
        self.status = status
        self.hasContent = hasContent
    }

    /// The geometry information at the selection start.
    ///
    /// This information is used for drawing mobile selection controls. The
    /// `SelectionPoint.localPosition` of the selection start is typically at the
    /// start of the selection highlight at where the start selection handle
    /// should be drawn.
    ///
    /// The `SelectionPoint.handleType` should be `.left` for forward selection
    /// or `.right` for backward selection in most cases.
    ///
    /// Can be nil if the selection start is offstage, for example, when the
    /// selection is outside of the viewport or is kept alive by a scrollable.
    ///
    /// **Dart Source:** `selection.dart:749-762`
    public let startSelectionPoint: SelectionPoint?

    /// The geometry information at the selection end.
    ///
    /// This information is used for drawing mobile selection controls. The
    /// `SelectionPoint.localPosition` of the selection end is typically at the end
    /// of the selection highlight at where the end selection handle should be
    /// drawn.
    ///
    /// The `SelectionPoint.handleType` should be `.right` for forward selection
    /// or `.left` for backward selection in most cases.
    ///
    /// Can be nil if the selection end is offstage, for example, when the
    /// selection is outside of the viewport or is kept alive by a scrollable.
    ///
    /// **Dart Source:** `selection.dart:764-777`
    public let endSelectionPoint: SelectionPoint?

    /// The status of ongoing selection in the `Selectable` or `SelectionHandler`.
    ///
    /// **Dart Source:** `selection.dart:779-780`
    public let status: SelectionStatus

    /// The rects in the local coordinates of the containing `Selectable` that
    /// represent the selection if there is any.
    ///
    /// **Dart Source:** `selection.dart:782-784`
    public let selectionRects: [Rect]

    /// Whether there is any selectable content in the `Selectable` or
    /// `SelectionHandler`.
    ///
    /// **Dart Source:** `selection.dart:786-788`
    public let hasContent: Bool

    /// Whether there is an ongoing selection.
    ///
    /// **Dart Source:** `selection.dart:790-791`
    public var hasSelection: Bool {
        status != .none
    }

    /// Makes a copy of this object with the given values updated.
    ///
    /// **Dart Source:** `selection.dart:794-808`
    public func copyWith(
        startSelectionPoint: SelectionPoint?? = nil,
        endSelectionPoint: SelectionPoint?? = nil,
        selectionRects: [Rect]? = nil,
        status: SelectionStatus? = nil,
        hasContent: Bool? = nil
    ) -> SelectionGeometry {
        SelectionGeometry(
            startSelectionPoint: startSelectionPoint ?? self.startSelectionPoint,
            endSelectionPoint: endSelectionPoint ?? self.endSelectionPoint,
            selectionRects: selectionRects ?? self.selectionRects,
            status: status ?? self.status,
            hasContent: hasContent ?? self.hasContent
        )
    }

    /// An empty selection geometry with no selection and no content.
    ///
    /// **Dart Source:** N/A (Swift convenience addition)
    public static let empty = SelectionGeometry(
        status: .none,
        hasContent: false
    )
}

// MARK: - SelectionEvent

/// Base class for all selection events.
///
/// This should not be directly used. To handle a selection event, it should
/// be downcast to a specific subclass. One can use `type` to look up which
/// subclasses to downcast to.
///
/// See also:
/// * `SelectAllSelectionEvent`, for events to select all contents.
/// * `ClearSelectionEvent`, for events to clear selections.
/// * `SelectWordSelectionEvent`, for events to select words at the locations.
/// * `SelectionEdgeUpdateEvent`, for events to update selection edges.
/// * `SelectionEventType`, for determining the subclass types.
///
/// **Dart Source:** `selection.dart:450-455`
public class SelectionEvent {
    /// The type of this selection event.
    ///
    /// **Dart Source:** `selection.dart:453-454`
    public let type: SelectionEventType

    internal init(type: SelectionEventType) {
        self.type = type
    }
}

/// Selects all selectable contents.
///
/// This event can be sent as the result of keyboard select-all, i.e.
/// ctrl + A, or cmd + A in macOS.
///
/// **Dart Source:** `selection.dart:461-464`
public class SelectAllSelectionEvent: SelectionEvent {
    /// Creates a select all selection event.
    ///
    /// **Dart Source:** `selection.dart:462-463`
    public init() {
        super.init(type: .selectAll)
    }
}

/// Clears the selection from the `Selectable` and removes any existing
/// highlight as if there is no selection at all.
///
/// **Dart Source:** `selection.dart:468-471`
public class ClearSelectionEvent: SelectionEvent {
    /// Creates a clear selection event.
    ///
    /// **Dart Source:** `selection.dart:469-470`
    public init() {
        super.init(type: .clear)
    }
}

/// Selects the whole word at the location.
///
/// This event can be sent as the result of mobile long press selection.
///
/// **Dart Source:** `selection.dart:476-483`
public class SelectWordSelectionEvent: SelectionEvent {
    /// The position in global coordinates to select word at.
    ///
    /// **Dart Source:** `selection.dart:481-482`
    public let globalPosition: Offset

    /// Creates a select word event at the `globalPosition`.
    ///
    /// **Dart Source:** `selection.dart:477-479`
    public init(globalPosition: Offset) {
        self.globalPosition = globalPosition
        super.init(type: .selectWord)
    }
}

/// Selects the entire paragraph at the location.
///
/// This event can be sent as the result of a triple click to select.
///
/// **Dart Source:** `selection.dart:488-499`
public class SelectParagraphSelectionEvent: SelectionEvent {
    /// The position in global coordinates to select paragraph at.
    ///
    /// **Dart Source:** `selection.dart:493-494`
    public let globalPosition: Offset

    /// Whether the selectable receiving the event should be absorbed into
    /// an encompassing paragraph.
    ///
    /// **Dart Source:** `selection.dart:496-498`
    public let absorb: Bool

    /// Creates a select paragraph event at the `globalPosition`.
    ///
    /// **Dart Source:** `selection.dart:489-491`
    public init(globalPosition: Offset, absorb: Bool = false) {
        self.globalPosition = globalPosition
        self.absorb = absorb
        super.init(type: .selectParagraph)
    }
}

/// Updates a selection edge.
///
/// An active selection contains two edges, start and end. Use the `type` to
/// determine which edge this event applies to. If the `type` is
/// `.startEdgeUpdate`, the event updates start edge. If the `type` is
/// `.endEdgeUpdate`, the event updates end edge.
///
/// The `globalPosition` contains the new offset of the edge.
///
/// The `granularity` contains the granularity that the selection edge should
/// move by. Only `TextGranularity.character` and `TextGranularity.word` are
/// currently supported.
///
/// This event is dispatched when the framework detects `TapDragStartDetails` in
/// `SelectionArea`'s gesture recognizers for mouse devices, or the selection
/// handles have been dragged to new locations.
///
/// **Dart Source:** `selection.dart:516-549`
public class SelectionEdgeUpdateEvent: SelectionEvent {
    /// The new location of the selection edge.
    ///
    /// **Dart Source:** `selection.dart:541-542`
    public let globalPosition: Offset

    /// The granularity for which the selection moves.
    ///
    /// Only `TextGranularity.character` and `TextGranularity.word` are currently
    /// supported.
    ///
    /// Defaults to `TextGranularity.character`.
    ///
    /// **Dart Source:** `selection.dart:544-549`
    public let granularity: TextGranularity

    /// Creates a selection edge update event.
    ///
    /// The `type` must be `.startEdgeUpdate` or `.endEdgeUpdate`.
    ///
    /// **Dart Source:** `selection.dart:517-539`
    public init(globalPosition: Offset, type: SelectionEventType, granularity: TextGranularity = .character) {
        assert(type == .startEdgeUpdate || type == .endEdgeUpdate)
        self.globalPosition = globalPosition
        self.granularity = granularity
        super.init(type: type)
    }
}

/// Extends the start or end of the selection by a given `TextGranularity`.
///
/// To handle this event, move the associated selection edge, as dictated by
/// `isEnd`, according to the `granularity`.
///
/// **Dart Source:** `selection.dart:556-572`
public class GranularlyExtendSelectionEvent: SelectionEvent {
    /// Whether this event is updating the end selection edge.
    ///
    /// **Dart Source:** `selection.dart:567-568`
    public let isEnd: Bool

    /// Whether to extend the selection forward.
    ///
    /// **Dart Source:** `selection.dart:564-565`
    public let forward: Bool

    /// The granularity for which the selection extend.
    ///
    /// **Dart Source:** `selection.dart:570-571`
    public let granularity: TextGranularity

    /// Creates a `GranularlyExtendSelectionEvent`.
    ///
    /// **Dart Source:** `selection.dart:557-562`
    public init(isEnd: Bool, forward: Bool, granularity: TextGranularity) {
        self.isEnd = isEnd
        self.forward = forward
        self.granularity = granularity
        super.init(type: .granularlyExtendSelection)
    }
}

/// Extends the current selection with respect to a `direction`.
///
/// To handle this event, move the associated selection edge, as dictated by
/// `isEnd`, according to the `direction`.
///
/// The movements are always based on `dx`. The value is in
/// global coordinates and is the horizontal offset the selection edge should
/// move to when moving to across lines.
///
/// **Dart Source:** `selection.dart:632-667`
public class DirectionallyExtendSelectionEvent: SelectionEvent {
    /// Whether this event is updating the end selection edge.
    ///
    /// **Dart Source:** `selection.dart:645-646`
    public let isEnd: Bool

    /// The directional movement of this event.
    ///
    /// See also:
    ///  * `SelectionExtendDirection`, which explains how to handle each enum.
    ///
    /// **Dart Source:** `selection.dart:648-652`
    public let direction: SelectionExtendDirection

    /// The horizontal offset the selection should move to.
    ///
    /// The offset is in global coordinates.
    ///
    /// **Dart Source:** `selection.dart:640-643`
    public let dx: Double

    /// Creates a `DirectionallyExtendSelectionEvent`.
    ///
    /// **Dart Source:** `selection.dart:633-638`
    public init(isEnd: Bool, direction: SelectionExtendDirection, dx: Double) {
        self.isEnd = isEnd
        self.direction = direction
        self.dx = dx
        super.init(type: .directionallyExtendSelection)
    }

    /// Makes a copy of this object with its property replaced with the new values.
    ///
    /// **Dart Source:** `selection.dart:654-666`
    public func copyWith(
        dx: Double? = nil,
        isEnd: Bool? = nil,
        direction: SelectionExtendDirection? = nil
    ) -> DirectionallyExtendSelectionEvent {
        DirectionallyExtendSelectionEvent(
            isEnd: isEnd ?? self.isEnd,
            direction: direction ?? self.direction,
            dx: dx ?? self.dx
        )
    }
}

// MARK: - LayerLink

/// An object that a `LeaderLayer` can register with.
///
/// An instance of this class should be provided as the `link` property of
/// the `LeaderLayer`, and is fed to the `FollowerLayer`'s constructor to
/// enable the child layer to follow the leader layer.
///
/// This is a placeholder for the full `LayerLink` class in `layer.dart`.
/// The full implementation will be provided when `LeaderLayer` and
/// `FollowerLayer` are migrated.
///
/// **Dart Source:** `layer.dart:2416-2479`
public class LayerLink {
    /// The total size of the content of the connected `LeaderLayer`.
    ///
    /// **Dart Source:** `layer.dart:2473`
    public var leaderSize: Size?

    /// The `LeaderLayer` connected to this link.
    ///
    /// **Dart Source:** `layer.dart:2470`
    public weak var leader: LeaderLayer?

    /// Creates a layer link.
    public init() {}
}

// MARK: - SelectionHandler

/// An interface to interact with the selection system.
///
/// This protocol returns a `SelectionGeometry` as its `value`, and is
/// responsible to notify its listener when its selection geometry has changed
/// as the result of receiving selection events.
///
/// In Dart, this extends `ValueListenable<SelectionGeometry>`. Swift
/// conformance to `ValueListenable` can be added by concrete types that also
/// conform to `Listenable`.
///
/// **Dart Source:** `selection.dart:76-117`
public protocol SelectionHandler: AnyObject {
    /// Marks this handler to be responsible for pushing `LeaderLayer`s for the
    /// selection handles.
    ///
    /// This handler is responsible for pushing the leader layers with the
    /// given layer links if they are not nil. It is possible that only one layer
    /// is non-nil if this handler is only responsible for pushing one layer
    /// link.
    ///
    /// The `startHandle` needs to be placed at the visual location of selection
    /// start, the `endHandle` needs to be placed at the visual location of
    /// selection end.
    ///
    /// **Dart Source:** `selection.dart:77-90`
    func pushHandleLayers(startHandle: LayerLink?, endHandle: LayerLink?)

    /// Gets the selected content in this object.
    ///
    /// Return `nil` if nothing is selected.
    ///
    /// **Dart Source:** `selection.dart:92-95`
    func getSelectedContent() -> SelectedContent?

    /// Gets the `SelectedContentRange` representing the selected range in this
    /// object.
    ///
    /// When nothing is selected, subclasses should return `nil`.
    ///
    /// **Dart Source:** `selection.dart:97-100`
    func getSelection() -> SelectedContentRange?

    /// Handles the `SelectionEvent` sent to this object.
    ///
    /// The subclasses need to update their selections or delegate the
    /// `SelectionEvent`s to their subtrees.
    ///
    /// The `event`s are subclasses of `SelectionEvent`. Check
    /// `SelectionEvent.type` to determine what kinds of event are dispatched to
    /// this handler and handle them accordingly.
    ///
    /// **Dart Source:** `selection.dart:102-113`
    func dispatchSelectionEvent(_ event: SelectionEvent) -> SelectionResult

    /// The current selection geometry value.
    ///
    /// In Dart, `SelectionHandler` extends `ValueListenable<SelectionGeometry>`,
    /// which provides this property. In Swift, we include it directly.
    ///
    /// **Dart Source:** `selection.dart:76` (via `ValueListenable`)
    var value: SelectionGeometry { get }

    /// The length of the content in this object.
    ///
    /// **Dart Source:** `selection.dart:115-116`
    var contentLength: Int { get }
}

// MARK: - Selectable

/// An interface that a `RenderObject` can implement to receive selection events.
///
/// This protocol is typically adopted by `RenderObject`s. The
/// `RenderObject.paint` methods are responsible to push the `LayerLink`s
/// provided to `pushHandleLayers`.
///
/// In Dart, `Selectable` is a mixin that implements `SelectionHandler`. Here it
/// is modeled as a protocol that refines `SelectionHandler`.
///
/// **Dart Source:** `selection.dart:238-251`
public protocol Selectable: SelectionHandler {
    /// Returns the transformation from the local coordinate system of this
    /// object to the coordinate system of `ancestor`.
    ///
    /// **Dart Source:** `selection.dart:239-240`
    func getTransformTo(_ ancestor: RenderObject?) -> Matrix4

    /// The size of this `Selectable`.
    ///
    /// **Dart Source:** `selection.dart:242-243`
    var size: Size { get }

    /// A list of `Rect`s that represent the bounding box of this `Selectable`
    /// in local coordinates.
    ///
    /// **Dart Source:** `selection.dart:245-247`
    var boundingBoxes: [Rect] { get }

    /// Disposes resources held by this selectable.
    ///
    /// **Dart Source:** `selection.dart:249-250`
    func dispose()
}

// MARK: - SelectionRegistrant

/// A protocol to auto-register the adopter to the `registrar`.
///
/// To use this protocol, the adopter needs to set the `registrar` to the
/// `SelectionRegistrar` it wants to register to.
///
/// This protocol only registers the adopter with the `registrar` if the
/// `SelectionGeometry.hasContent` returned by the adopter is `true`.
///
/// In Dart, this is a mixin on `Selectable`.
///
/// **Dart Source:** `selection.dart:260-310`
public protocol SelectionRegistrant: Selectable {
    /// The `SelectionRegistrar` the adopter will be or is registered to.
    ///
    /// This `Selectable` only registers the adopter if the
    /// `SelectionGeometry.hasContent` returned by the `Selectable` is `true`.
    ///
    /// **Dart Source:** `selection.dart:261-281`
    var registrar: SelectionRegistrar? { get set }
}

// MARK: - SelectionRegistrar

/// An interface for registering `Selectable`s.
///
/// Implementers of this protocol can be assigned to `SelectionRegistrant.registrar`
/// to receive the `Selectable`s in the registrant's subtree.
///
/// See also:
/// * `SelectionRegistrant`, which auto registers the object to
///   `SelectionRegistrar`.
///
/// **Dart Source:** `selection.dart:685-697`
public protocol SelectionRegistrar {
    /// Adds the `selectable` into the registrar.
    ///
    /// A `Selectable` must register with the `SelectionRegistrar` in order to
    /// receive selection events.
    ///
    /// **Dart Source:** `selection.dart:686-690`
    func add(_ selectable: any Selectable)

    /// Removes the `selectable` from the registrar.
    ///
    /// A `Selectable` must unregister itself if it is removed from the rendering
    /// tree.
    ///
    /// **Dart Source:** `selection.dart:692-696`
    func remove(_ selectable: any Selectable)
}

// MARK: - SelectionUtils

/// A utility enum that provides useful methods for handling selection events.
///
/// This is an `enum` with no cases (caseless enum) to serve as a namespace for
/// static methods, matching Dart's `abstract final class` pattern.
///
/// **Dart Source:** `selection.dart:313-372`
public enum SelectionUtils {
    /// Determines `SelectionResult` purely based on the target rectangle.
    ///
    /// This method returns `SelectionResult.end` if the `point` is inside the
    /// `targetRect`. Returns `SelectionResult.previous` if the `point` is
    /// considered to be higher than `targetRect` in screen order. Returns
    /// `SelectionResult.next` if the point is considered to be lower than
    /// `targetRect` in screen order.
    ///
    /// **Dart Source:** `selection.dart:321-332`
    public static func getResultBasedOnRect(_ targetRect: Rect, _ point: Offset) -> SelectionResult {
        if targetRect.contains(point) {
            return .end
        }
        if point.dy < targetRect.top {
            return .previous
        }
        if point.dy > targetRect.bottom {
            return .next
        }
        return point.dx >= targetRect.right ? .next : .previous
    }

    /// Adjusts the dragging offset based on the target rect.
    ///
    /// This method moves the offsets to be within the target rect in case they
    /// are outside the rect.
    ///
    /// This is used in the case where a drag happens outside of the rectangle
    /// of a `Selectable`.
    ///
    /// The logic works as the following:
    ///
    /// For points inside the rect:
    ///   Their effective locations are unchanged.
    ///
    /// For points in Area 1 (above, or left of rect on same line):
    ///   Move them to top-left of the rect if text direction is ltr, or
    ///   top-right if rtl.
    ///
    /// For points in Area 2 (below, or right of rect on same line):
    ///   Move them to bottom-right of the rect if text direction is ltr, or
    ///   bottom-left if rtl.
    ///
    /// **Dart Source:** `selection.dart:355-372`
    public static func adjustDragOffset(
        _ targetRect: Rect,
        _ point: Offset,
        direction: TextDirection = .ltr
    ) -> Offset {
        if targetRect.contains(point) {
            return point
        }
        if point.dy <= targetRect.top
            || (point.dy <= targetRect.bottom && point.dx <= targetRect.left)
        {
            // Area 1
            return direction == .ltr ? targetRect.topLeft : targetRect.topRight
        } else {
            // Area 2
            return direction == .ltr ? targetRect.bottomRight : targetRect.bottomLeft
        }
    }
}
