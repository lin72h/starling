// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Inline span types for building rich text paragraphs.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/inline_span.dart`

import FlutterSwiftBridge

// MARK: - Dependency Stubs

/// Holds the `Size` and baseline required to represent the dimensions of
/// a placeholder in text.
///
/// Placeholders specify an empty space in the text layout, which is used
/// to later render arbitrary inline widgets into defined by a `WidgetSpan`.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/text_painter.dart:73-147`
public struct PlaceholderDimensions: Hashable, Sendable, CustomStringConvertible {
    /// Width and height dimensions of the placeholder.
    ///
    /// **Dart Source:** `text_painter.dart:93`
    public let size: Size

    /// How to align the placeholder with the text.
    ///
    /// **Dart Source:** `text_painter.dart:105`
    public let alignment: PlaceholderAlignment

    /// Distance of the `baseline` from the upper edge of the placeholder.
    ///
    /// Only used when `alignment` is `PlaceholderAlignment.baseline`.
    ///
    /// **Dart Source:** `text_painter.dart:110`
    public let baselineOffset: Double?

    /// The `TextBaseline` to align to.
    ///
    /// **Dart Source:** `text_painter.dart:118`
    public let baseline: TextBaseline?

    /// Constructs a `PlaceholderDimensions` with the specified parameters.
    ///
    /// **Dart Source:** `text_painter.dart:79-84`
    public init(
        size: Size,
        alignment: PlaceholderAlignment,
        baseline: TextBaseline? = nil,
        baselineOffset: Double? = nil
    ) {
        self.size = size
        self.alignment = alignment
        self.baseline = baseline
        self.baselineOffset = baselineOffset
    }

    /// A constant representing an empty placeholder.
    ///
    /// **Dart Source:** `text_painter.dart:87-90`
    public static let empty = PlaceholderDimensions(
        size: Size.zero,
        alignment: .bottom
    )

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `text_painter.dart:136-146`
    public var description: String {
        switch alignment {
        case .baseline:
            return "PlaceholderDimensions(\(size), \(alignment)(\(baselineOffset.map { "\($0)" } ?? "nil") from top))"
        default:
            return "PlaceholderDimensions(\(size), \(alignment))"
        }
    }
}

// NOTE: The GestureRecognizer stub protocol that was previously defined here
// has been removed. The full GestureRecognizer class is now provided by
// Gestures/Recognizer.swift.

// MARK: - Accumulator

/// Mutable wrapper of an integer that can be passed by reference to track a
/// value across a recursive stack.
///
/// **Dart Source:** `inline_span.dart:28-42`
public final class Accumulator {
    /// The integer stored in this `Accumulator`.
    ///
    /// **Dart Source:** `inline_span.dart:34-35`
    public private(set) var value: Int

    /// Creates an `Accumulator` that may be initialized with a specified value;
    /// otherwise, it will initialize to zero.
    ///
    /// **Dart Source:** `inline_span.dart:31`
    public init(_ value: Int = 0) {
        self.value = value
    }

    /// Increases the `value` by the `addend`.
    ///
    /// **Dart Source:** `inline_span.dart:38-41`
    public func increment(_ addend: Int) {
        assert(addend >= 0)
        value += addend
    }
}

// MARK: - InlineSpanVisitor

/// Called on each span as `InlineSpan.visitChildren` walks the `InlineSpan` tree.
///
/// Returns true when the walk should continue, and false to stop visiting further
/// `InlineSpan`s.
///
/// **Dart Source:** `inline_span.dart:48`
public typealias InlineSpanVisitor = (InlineSpan) -> Bool

// MARK: - InlineSpanSemanticsInformation

/// The textual and semantic label information for an `InlineSpan`.
///
/// For `PlaceholderSpan`s, `InlineSpanSemanticsInformation.placeholder` is used
/// by default.
///
/// See also:
///
///  * `InlineSpan.getSemanticsInformation`
///
/// **Dart Source:** `inline_span.dart:57-123`
public struct InlineSpanSemanticsInformation: Equatable, CustomStringConvertible {

    /// The text value, if any. For `PlaceholderSpan`s, this will be the unicode
    /// placeholder value.
    ///
    /// **Dart Source:** `inline_span.dart:81`
    public let text: String

    /// The semanticsLabel, if any.
    ///
    /// **Dart Source:** `inline_span.dart:85`
    public let semanticsLabel: String?

    /// The semanticsIdentifier, if any.
    ///
    /// **Dart Source:** `inline_span.dart:88`
    public let semanticsIdentifier: String?

    /// The gesture recognizer, if any, for this span.
    ///
    /// **Dart Source:** `inline_span.dart:91`
    public let recognizer: GestureRecognizer?

    /// Whether this is for a placeholder span.
    ///
    /// **Dart Source:** `inline_span.dart:94`
    public let isPlaceholder: Bool

    /// True if this configuration should get its own semantics node.
    ///
    /// This will be the case if the `recognizer` is not nil, or if
    /// `isPlaceholder` is true, or if `semanticsIdentifier` has a value.
    ///
    /// **Dart Source:** `inline_span.dart:96-100`
    public let requiresOwnNode: Bool

    /// The string attributes attached to this semantics information.
    ///
    /// **Dart Source:** `inline_span.dart:103`
    public let stringAttributes: [any StringAttribute]

    /// Constructs an object that holds the text and semantics label values of an
    /// `InlineSpan`.
    ///
    /// Use `InlineSpanSemanticsInformation.placeholder` instead of directly setting
    /// `isPlaceholder`.
    ///
    /// **Dart Source:** `inline_span.dart:64-72`
    public init(
        _ text: String,
        isPlaceholder: Bool = false,
        semanticsLabel: String? = nil,
        semanticsIdentifier: String? = nil,
        stringAttributes: [any StringAttribute] = [],
        recognizer: GestureRecognizer? = nil
    ) {
        assert(
            !isPlaceholder
                || (text == "\u{FFFC}" && semanticsLabel == nil && recognizer == nil)
        )
        self.text = text
        self.isPlaceholder = isPlaceholder
        self.semanticsLabel = semanticsLabel
        self.semanticsIdentifier = semanticsIdentifier
        self.stringAttributes = stringAttributes
        self.recognizer = recognizer
        self.requiresOwnNode = isPlaceholder || recognizer != nil || semanticsIdentifier != nil
    }

    /// The text info for a `PlaceholderSpan`.
    ///
    /// **Dart Source:** `inline_span.dart:75-78`
    nonisolated(unsafe) public static let placeholder = InlineSpanSemanticsInformation(
        "\u{FFFC}",
        isPlaceholder: true
    )

    // MARK: - Equatable

    /// **Dart Source:** `inline_span.dart:106-114`
    public static func == (lhs: InlineSpanSemanticsInformation, rhs: InlineSpanSemanticsInformation) -> Bool {
        lhs.text == rhs.text
            && lhs.semanticsLabel == rhs.semanticsLabel
            && lhs.semanticsIdentifier == rhs.semanticsIdentifier
            && lhs.recognizer === rhs.recognizer
            && lhs.isPlaceholder == rhs.isPlaceholder
            && _stringAttributesEqual(lhs.stringAttributes, rhs.stringAttributes)
    }

    // MARK: - Hashable-like

    /// A hash value for use in collections.
    ///
    /// Note: Since `StringAttribute` is a protocol (existential type), full
    /// `Hashable` conformance is not possible. We provide a `hashValue`
    /// computed property instead.
    ///
    /// **Dart Source:** `inline_span.dart:117-118`
    public var hashValue: Int {
        var hasher = Hasher()
        hasher.combine(text)
        hasher.combine(semanticsLabel)
        hasher.combine(semanticsIdentifier)
        if let rec = recognizer {
            hasher.combine(ObjectIdentifier(rec))
        }
        hasher.combine(isPlaceholder)
        return hasher.finalize()
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `inline_span.dart:121-122`
    public var description: String {
        "InlineSpanSemanticsInformation{text: \(text), semanticsLabel: \(semanticsLabel ?? "nil"), semanticsIdentifier: \(semanticsIdentifier ?? "nil"), recognizer: \(recognizer.map { "\($0)" } ?? "nil")}"
    }
}

/// Compares two arrays of `StringAttribute` for equality.
///
/// Two arrays are equal if they have the same length and each element
/// has the same range. Since `StringAttribute` is a protocol, identity
/// comparison is used as a fallback.
private func _stringAttributesEqual(
    _ a: [any StringAttribute],
    _ b: [any StringAttribute]
) -> Bool {
    guard a.count == b.count else { return false }
    for i in 0..<a.count {
        if a[i] !== b[i] {
            // Different objects; check if ranges match and are same type.
            // For a faithful port, we check range equality.
            if a[i].range != b[i].range {
                return false
            }
            // Also check if they are the same concrete type via identity
            if type(of: a[i]) != type(of: b[i]) {
                return false
            }
        }
    }
    return true
}

// MARK: - combineSemanticsInfo

/// Combines semantics info entries where permissible.
///
/// Consecutive inline spans can be combined if their
/// `InlineSpanSemanticsInformation.requiresOwnNode` returns false.
///
/// **Dart Source:** `inline_span.dart:129-173`
public func combineSemanticsInfo(
    _ infoList: [InlineSpanSemanticsInformation]
) -> [InlineSpanSemanticsInformation] {
    var combined: [InlineSpanSemanticsInformation] = []
    var workingText = ""
    var workingLabel = ""
    var workingAttributes: [any StringAttribute] = []

    for info in infoList {
        if info.requiresOwnNode {
            combined.append(
                InlineSpanSemanticsInformation(
                    workingText,
                    semanticsLabel: workingLabel,
                    stringAttributes: workingAttributes
                )
            )
            workingText = ""
            workingLabel = ""
            workingAttributes = []
            combined.append(info)
        } else {
            workingText += info.text
            let effectiveLabel = info.semanticsLabel ?? info.text
            for infoAttribute in info.stringAttributes {
                workingAttributes.append(
                    infoAttribute.copy(
                        range: TextRange(
                            start: infoAttribute.range.start + workingLabel.count,
                            end: infoAttribute.range.end + workingLabel.count
                        )
                    )
                )
            }
            workingLabel += effectiveLabel
        }
    }

    combined.append(
        InlineSpanSemanticsInformation(
            workingText,
            semanticsLabel: workingLabel,
            stringAttributes: workingAttributes
        )
    )

    return combined
}

// MARK: - InlineSpan

/// An immutable span of inline content which forms part of a paragraph.
///
///  * The subclass `TextSpan` specifies text and may contain child `InlineSpan`s.
///  * The subclass `PlaceholderSpan` represents a placeholder that may be
///    filled with non-text content. `PlaceholderSpan` itself defines a
///    `PlaceholderAlignment` and a `TextBaseline`. To be useful,
///    `PlaceholderSpan` must be extended to define content. An instance of
///    this is the `WidgetSpan` class in the widgets library.
///  * The subclass `WidgetSpan` specifies embedded inline widgets.
///
/// **Dart Source:** `inline_span.dart:218-431`
open class InlineSpan: DiagnosticableTree {

    /// The `TextStyle` to apply to this span.
    ///
    /// The `style` is also applied to any child spans when this is an instance
    /// of `TextSpan`.
    ///
    /// **Dart Source:** `inline_span.dart:223-227`
    public let style: TextStyle?

    /// Creates an `InlineSpan` with the given values.
    ///
    /// **Dart Source:** `inline_span.dart:221`
    public init(style: TextStyle? = nil) {
        self.style = style
    }

    // MARK: - Abstract Methods (subclasses must override)

    /// Apply the properties of this object to the given `ParagraphBuilder`, from
    /// which a `Paragraph` can be obtained.
    ///
    /// The `textScaler` parameter specifies a `TextScaler` that the text and
    /// placeholders will be scaled by. The scaling is performed before layout,
    /// so the text will be laid out with the scaled glyphs and placeholders.
    ///
    /// The `dimensions` parameter specifies the sizes of the placeholders.
    /// Each `PlaceholderSpan` must be paired with a `PlaceholderDimensions`
    /// in the same order as defined in the `InlineSpan` tree.
    ///
    /// **Dart Source:** `inline_span.dart:241-245`
    open func build(
        _ builder: any FlutterSwiftBridge.ParagraphBuilder,
        textScaler: any TextScaler = TextScalers.noScaling,
        dimensions: [PlaceholderDimensions]? = nil
    ) {
        fatalError("Subclasses must override build(_:textScaler:dimensions:)")
    }

    /// Walks this `InlineSpan` and any descendants in pre-order and calls `visitor`
    /// for each span that has content.
    ///
    /// When `visitor` returns true, the walk will continue. When `visitor` returns
    /// false, then the walk will end.
    ///
    /// **Dart Source:** `inline_span.dart:258`
    open func visitChildren(_ visitor: InlineSpanVisitor) -> Bool {
        fatalError("Subclasses must override visitChildren(_:)")
    }

    /// Calls `visitor` for each immediate child of this `InlineSpan`.
    ///
    /// The immediate children are visited in the same order they are added to
    /// a `ParagraphBuilder` in the `build` method, which is also the logical
    /// order of the child `InlineSpan`s in the text.
    ///
    /// **Dart Source:** `inline_span.dart:275`
    open func visitDirectChildren(_ visitor: InlineSpanVisitor) -> Bool {
        fatalError("Subclasses must override visitDirectChildren(_:)")
    }

    /// Performs the check at each `InlineSpan` for if the `position` falls within
    /// the range of the span and returns the span if it does.
    ///
    /// The `offset` parameter tracks the current index offset in the text buffer
    /// formed if the contents of the `InlineSpan` tree were concatenated together
    /// starting from the root `InlineSpan`.
    ///
    /// This method should not be directly called. Use `getSpanForPosition` instead.
    ///
    /// **Dart Source:** `inline_span.dart:297-298`
    open func getSpanForPositionVisitor(
        _ position: TextPosition,
        _ offset: Accumulator
    ) -> InlineSpan? {
        fatalError("Subclasses must override getSpanForPositionVisitor(_:_:)")
    }

    /// Walks the `InlineSpan` tree and accumulates a list of
    /// `InlineSpanSemanticsInformation` objects.
    ///
    /// This method should not be directly called. Use
    /// `getSemanticsInformation` instead.
    ///
    /// **Dart Source:** `inline_span.dart:337-338`
    open func computeSemanticsInformation(
        _ collector: inout [InlineSpanSemanticsInformation]
    ) {
        fatalError("Subclasses must override computeSemanticsInformation(_:)")
    }

    /// Walks the `InlineSpan` tree and writes the plain text representation to
    /// `buffer`.
    ///
    /// This method should not be directly called. Use `toPlainText` instead.
    ///
    /// **Dart Source:** `inline_span.dart:354-359`
    open func computeToPlainText(
        _ buffer: inout String,
        includeSemanticsLabels: Bool = true,
        includePlaceholders: Bool = true
    ) {
        fatalError("Subclasses must override computeToPlainText(_:includeSemanticsLabels:includePlaceholders:)")
    }

    /// Performs the check at each `InlineSpan` for if the `index` falls within the
    /// range of the span and returns the corresponding code unit. Returns nil
    /// otherwise.
    ///
    /// This method should not be directly called. Use `codeUnitAt` instead.
    ///
    /// **Dart Source:** `inline_span.dart:387-388`
    open func codeUnitAtVisitor(_ index: Int, _ offset: Accumulator) -> Int? {
        fatalError("Subclasses must override codeUnitAtVisitor(_:_:)")
    }

    /// Describe the difference between this span and another, in terms of
    /// how much damage it will make to the rendering. The comparison is deep.
    ///
    /// Comparing `InlineSpan` objects of different types, for example, comparing
    /// a `TextSpan` to a `WidgetSpan`, always results in `RenderComparison.layout`.
    ///
    /// **Dart Source:** `inline_span.dart:409`
    open func compareTo(_ other: InlineSpan) -> RenderComparison {
        fatalError("Subclasses must override compareTo(_:)")
    }

    // MARK: - Concrete Methods

    /// Returns the `InlineSpan` that contains the given position in the text.
    ///
    /// **Dart Source:** `inline_span.dart:278-287`
    public func getSpanForPosition(_ position: TextPosition) -> InlineSpan? {
        assert(debugAssertIsValid())
        let offset = Accumulator()
        var result: InlineSpan?
        _ = visitChildren { (span: InlineSpan) -> Bool in
            result = span.getSpanForPositionVisitor(position, offset)
            return result == nil
        }
        return result
    }

    /// Flattens the `InlineSpan` tree into a single string.
    ///
    /// Styles are not honored in this process. If `includeSemanticsLabels` is
    /// true, then the text returned will include the `TextSpan.semanticsLabel`s
    /// instead of the text contents for `TextSpan`s.
    ///
    /// When `includePlaceholders` is true, `PlaceholderSpan`s in the tree will be
    /// represented as a 0xFFFC 'object replacement character'.
    ///
    /// **Dart Source:** `inline_span.dart:308-316`
    public func toPlainText(
        includeSemanticsLabels: Bool = true,
        includePlaceholders: Bool = true
    ) -> String {
        var buffer = ""
        computeToPlainText(
            &buffer,
            includeSemanticsLabels: includeSemanticsLabels,
            includePlaceholders: includePlaceholders
        )
        return buffer
    }

    /// Flattens the `InlineSpan` tree to a list of
    /// `InlineSpanSemanticsInformation` objects.
    ///
    /// `PlaceholderSpan`s in the tree will be represented with a
    /// `InlineSpanSemanticsInformation.placeholder` value.
    ///
    /// **Dart Source:** `inline_span.dart:323-327`
    public func getSemanticsInformation() -> [InlineSpanSemanticsInformation] {
        var collector: [InlineSpanSemanticsInformation] = []
        computeSemanticsInformation(&collector)
        return collector
    }

    /// Returns the UTF-16 code unit at the given `index` in the flattened string.
    ///
    /// This only accounts for the `TextSpan.text` values and ignores
    /// `PlaceholderSpan`s.
    ///
    /// Returns nil if the `index` is out of bounds.
    ///
    /// **Dart Source:** `inline_span.dart:366-377`
    public func codeUnitAt(_ index: Int) -> Int? {
        if index < 0 {
            return nil
        }
        let offset = Accumulator()
        var result: Int?
        _ = visitChildren { (span: InlineSpan) -> Bool in
            result = span.codeUnitAtVisitor(index, offset)
            return result == nil
        }
        return result
    }

    /// In debug mode, throws an exception if the object is not in a
    /// valid configuration. Otherwise, returns true.
    ///
    /// **Dart Source:** `inline_span.dart:398`
    open func debugAssertIsValid() -> Bool {
        return true
    }

    // MARK: - Equatable

    /// **Dart Source:** `inline_span.dart:411-420`
    public static func == (lhs: InlineSpan, rhs: InlineSpan) -> Bool {
        if lhs === rhs {
            return true
        }
        if type(of: lhs) != type(of: rhs) {
            return false
        }
        return lhs.style == rhs.style
    }

    /// **Dart Source:** `inline_span.dart:422-423`
    public var hashValue: Int {
        var hasher = Hasher()
        hasher.combine(style)
        return hasher.finalize()
    }

    // MARK: - DiagnosticableTree

    /// **Dart Source:** `inline_span.dart:425-430`
    public func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
        properties.defaultDiagnosticsTreeStyle = .whitespace
        // In the Dart source, style.debugFillProperties(properties) is called
        // to inline the style's properties. Since TextStyle is a struct without
        // Diagnosticable conformance in Swift, we add it as a string property.
        if let style = style {
            properties.add(
                DiagnosticsProperty<String>(
                    "style",
                    style.description,
                    defaultValue: nil
                )
            )
        }
    }

    /// Returns a brief string representation.
    public func toStringShort() -> String {
        return objectRuntimeType(self, "InlineSpan")
    }

    /// Returns a diagnostics node for this inline span.
    public func toDiagnosticsNode(
        name: String? = nil,
        style: DiagnosticsTreeStyle? = nil
    ) -> DiagnosticsNode {
        return DiagnosticableTreeNodeImpl(name: name, value: self, style: style)
    }

    /// Returns a one-line detailed description of the object.
    public func toStringShallow(
        joiner: String = ", ",
        minLevel: DiagnosticLevel = .debug
    ) -> String {
        return toDiagnosticsNode(name: nil, style: .singleLine)
            .toString(parentConfiguration: nil, minLevel: minLevel)
    }

    /// Returns a string representation of this node and its descendants.
    public func toStringDeep(
        prefixLineOne: String = "",
        prefixOtherLines: String? = nil,
        minLevel: DiagnosticLevel = .debug,
        wrapWidth: Int = 65
    ) -> String {
        return toDiagnosticsNode(name: nil, style: nil).toStringDeep(
            prefixLineOne: prefixLineOne,
            prefixOtherLines: prefixOtherLines,
            minLevel: minLevel,
            wrapWidth: wrapWidth
        )
    }

    /// Returns a list of `DiagnosticsNode` objects describing this node's children.
    public func debugDescribeChildren() -> [any DiagnosticsNodeProtocol] {
        return []
    }
}
