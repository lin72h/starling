// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// An immutable span of text.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/text_span.dart`

import FlutterSwiftBridge

// MARK: - TextSpan

/// An immutable span of text.
///
/// A `TextSpan` object can be styled using its `style` property. The style will
/// be applied to the `text` and the `children`.
///
/// A `TextSpan` object can just have plain text, or it can have children
/// `TextSpan` objects with their own styles that (possibly only partially)
/// override the `style` of this object. If a `TextSpan` has both `text` and
/// `children`, then the `text` is treated as if it was an un-styled `TextSpan`
/// at the start of the `children` list. Leaving the `TextSpan.text` field nil
/// results in the `TextSpan` acting as an empty node in the `InlineSpan` tree
/// with a list of children.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/text_span.dart`
/// **Lines:** 74-599
public final class TextSpan: InlineSpan {

    // MARK: - Properties

    /// The text contained in this span.
    ///
    /// If both `text` and `children` are non-nil, the text will precede the
    /// children.
    ///
    /// This getter does not include the contents of its children.
    ///
    /// **Dart Source:** `text_span.dart:95-101`
    public let text: String?

    /// Additional spans to include as children.
    ///
    /// If both `text` and `children` are non-nil, the text will precede the
    /// children.
    ///
    /// Modifying the list after the `TextSpan` has been created is not supported
    /// and may have unexpected results.
    ///
    /// The list must not contain any nils.
    ///
    /// **Dart Source:** `text_span.dart:103-112`
    public let children: [InlineSpan]?

    /// A gesture recognizer that will receive events that hit this span.
    ///
    /// `InlineSpan` itself does not implement hit testing or event dispatch. The
    /// object that manages the `InlineSpan` painting is also responsible for
    /// dispatching events.
    ///
    /// **Dart Source:** `text_span.dart:114-193`
    public let recognizer: GestureRecognizer?

    // TODO: Mouse-related properties (mouseCursor, onEnter, onExit) are skipped
    // pending migration of the gestures/services layer. These depend on:
    // - MouseCursor from services/mouse_cursor.dart
    // - PointerEnterEvent, PointerExitEvent from gestures/events.dart
    // - MouseTrackerAnnotation protocol from services/mouse_tracking.dart
    // - HitTestTarget protocol from gestures/hit_test.dart

    /// An alternative semantics label for this `TextSpan`.
    ///
    /// If present, the semantics of this span will contain this value instead
    /// of the actual text.
    ///
    /// This is useful for replacing abbreviations or shorthands with the full
    /// text value:
    ///
    /// ```swift
    /// TextSpan(text: "$$", semanticsLabel: "Double dollars")
    /// ```
    ///
    /// **Dart Source:** `text_span.dart:221-232`
    public let semanticsLabel: String?

    /// A unique identifier for the semantics node for this `TextSpan`.
    ///
    /// This is useful for cases where the text content of the `TextSpan` needs
    /// to be uniquely identified through the automation tools without having
    /// a dependency on the actual content of the text that can possibly be
    /// dynamic in nature.
    ///
    /// **Dart Source:** `text_span.dart:234-240`
    public let semanticsIdentifier: String?

    /// The language of the text in this span and its span children.
    ///
    /// Setting the locale of this text span affects the way that assistive
    /// technologies, such as VoiceOver or TalkBack, pronounce the text.
    ///
    /// If this span contains other text span children, they also inherit the
    /// locale from this span unless explicitly set to different locales.
    ///
    /// **Dart Source:** `text_span.dart:242-249`
    public let locale: Locale?

    /// Whether the assistive technologies should spell out this text character
    /// by character.
    ///
    /// If the text is 'hello world', setting this to true causes the assistive
    /// technologies, such as VoiceOver or TalkBack, to pronounce
    /// 'h-e-l-l-o-space-w-o-r-l-d' instead of complete words.
    ///
    /// If this span contains other text span children, they also inherit the
    /// property from this span unless explicitly set.
    ///
    /// If the property is not set, this text span inherits the spell out setting
    /// from its parent.
    ///
    /// **Dart Source:** `text_span.dart:251-266`
    public let spellOut: Bool?

    // MARK: - Initializer

    /// Creates a `TextSpan` with the given values.
    ///
    /// For the object to be useful, at least one of `text` or `children` should
    /// be set.
    ///
    /// **Dart Source:** `text_span.dart:79-93`
    public init(
        text: String? = nil,
        children: [InlineSpan]? = nil,
        style: Flutter.TextStyle? = nil,
        recognizer: GestureRecognizer? = nil,
        semanticsLabel: String? = nil,
        semanticsIdentifier: String? = nil,
        locale: Locale? = nil,
        spellOut: Bool? = nil
    ) {
        assert(
            !(text == nil && semanticsLabel != nil),
            "A semanticsLabel requires text to be set"
        )
        self.text = text
        self.children = children
        self.recognizer = recognizer
        self.semanticsLabel = semanticsLabel
        self.semanticsIdentifier = semanticsIdentifier
        self.locale = locale
        self.spellOut = spellOut
        super.init(style: style)
    }

    // MARK: - Build

    /// Apply the `style`, `text`, and `children` of this object to the
    /// given `ParagraphBuilder`, from which a `Paragraph` can be obtained.
    ///
    /// **Dart Source:** `text_span.dart:286-322`
    public override func build(
        _ builder: any FlutterSwiftBridge.ParagraphBuilder,
        textScaler: any TextScaler = TextScalers.noScaling,
        dimensions: [PlaceholderDimensions]? = nil
    ) {
        assert(debugAssertIsValid())
        let hasStyle = style != nil
        if hasStyle {
            builder.pushStyle(style!.getTextStyle(textScaler: textScaler))
        }
        if let text = text {
            // In Dart, addText can throw ArgumentError for invalid text. The Swift
            // ParagraphBuilder.addText does not throw, so we call it directly.
            // If Swift's addText were to throw in the future, we would catch and
            // report via FlutterError.reportError, using U+FFFD as a fallback.
            builder.addText(text)
        }
        if let children = self.children {
            for child in children {
                child.build(builder, textScaler: textScaler, dimensions: dimensions)
            }
        }
        if hasStyle {
            builder.pop()
        }
    }

    // MARK: - Traversal

    /// Walks this `TextSpan` and its descendants in pre-order and calls `visitor`
    /// for each span that has text.
    ///
    /// When `visitor` returns true, the walk will continue. When `visitor`
    /// returns false, then the walk will end.
    ///
    /// **Dart Source:** `text_span.dart:330-343`
    public override func visitChildren(_ visitor: InlineSpanVisitor) -> Bool {
        if text != nil && !visitor(self) {
            return false
        }
        if let children = self.children {
            for child in children {
                if !child.visitChildren(visitor) {
                    return false
                }
            }
        }
        return true
    }

    /// Calls `visitor` for each immediate child of this `TextSpan`.
    ///
    /// **Dart Source:** `text_span.dart:345-356`
    public override func visitDirectChildren(_ visitor: InlineSpanVisitor) -> Bool {
        if let children = self.children {
            for child in children {
                if !visitor(child) {
                    return false
                }
            }
        }
        return true
    }

    /// Returns the text span that contains the given position in the text.
    ///
    /// **Dart Source:** `text_span.dart:360-376`
    public override func getSpanForPositionVisitor(
        _ position: TextPosition,
        _ offset: Accumulator
    ) -> InlineSpan? {
        guard let text = self.text, !text.isEmpty else {
            return nil
        }
        let affinity = position.affinity
        let targetOffset = position.offset
        let endOffset = offset.value + text.utf16.count

        if (offset.value == targetOffset && affinity == .downstream)
            || (offset.value < targetOffset && targetOffset < endOffset)
            || (endOffset == targetOffset && affinity == .upstream)
        {
            return self
        }
        offset.increment(text.utf16.count)
        return nil
    }

    // MARK: - Plain Text

    /// Walks the `InlineSpan` tree and writes the plain text representation to
    /// `buffer`.
    ///
    /// **Dart Source:** `text_span.dart:378-399`
    public override func computeToPlainText(
        _ buffer: inout String,
        includeSemanticsLabels: Bool = true,
        includePlaceholders: Bool = true
    ) {
        assert(debugAssertIsValid())
        if let semanticsLabel = semanticsLabel, includeSemanticsLabels {
            buffer += semanticsLabel
        } else if let text = text {
            buffer += text
        }
        if let children = self.children {
            for child in children {
                child.computeToPlainText(
                    &buffer,
                    includeSemanticsLabels: includeSemanticsLabels,
                    includePlaceholders: includePlaceholders
                )
            }
        }
    }

    // MARK: - Semantics

    /// Walks the `InlineSpan` tree and accumulates a list of
    /// `InlineSpanSemanticsInformation` objects.
    ///
    /// **Dart Source:** `text_span.dart:401-445`
    public override func computeSemanticsInformation(
        _ collector: inout [InlineSpanSemanticsInformation]
    ) {
        _computeSemanticsInformation(
            &collector,
            inheritedLocale: nil,
            inheritedSpellOut: false
        )
    }

    /// Internal semantics computation that supports locale/spellOut inheritance.
    ///
    /// **Dart Source:** `text_span.dart:401-445`
    internal func _computeSemanticsInformation(
        _ collector: inout [InlineSpanSemanticsInformation],
        inheritedLocale: Locale?,
        inheritedSpellOut: Bool
    ) {
        assert(debugAssertIsValid())
        let effectiveLocale = locale ?? inheritedLocale
        let effectiveSpellOut = spellOut ?? inheritedSpellOut

        if let text = text {
            let textLength = semanticsLabel?.utf16.count ?? text.utf16.count
            var stringAttributes: [any StringAttribute] = []
            if effectiveSpellOut && textLength > 0 {
                stringAttributes.append(
                    SpellOutStringAttribute(range: TextRange(start: 0, end: textLength))
                )
            }
            if let effectiveLocale = effectiveLocale, textLength > 0 {
                stringAttributes.append(
                    LocaleStringAttribute(
                        range: TextRange(start: 0, end: textLength),
                        locale: effectiveLocale
                    )
                )
            }
            collector.append(
                InlineSpanSemanticsInformation(
                    text,
                    semanticsLabel: semanticsLabel,
                    semanticsIdentifier: semanticsIdentifier,
                    stringAttributes: stringAttributes,
                    recognizer: recognizer
                )
            )
        }
        if let children = self.children {
            for child in children {
                if let textSpanChild = child as? TextSpan {
                    textSpanChild._computeSemanticsInformation(
                        &collector,
                        inheritedLocale: effectiveLocale,
                        inheritedSpellOut: effectiveSpellOut
                    )
                } else {
                    child.computeSemanticsInformation(&collector)
                }
            }
        }
    }

    // MARK: - Code Unit

    /// Gets the code unit at the given index in the flattened string.
    ///
    /// **Dart Source:** `text_span.dart:447-457`
    public override func codeUnitAtVisitor(_ index: Int, _ offset: Accumulator) -> Int? {
        guard let text = self.text else {
            return nil
        }
        let utf16 = Array(text.utf16)
        let localOffset = index - offset.value
        assert(localOffset >= 0)
        offset.increment(utf16.count)
        return localOffset < utf16.count ? Int(utf16[localOffset]) : nil
    }

    // MARK: - Validation

    /// In debug mode, throws an exception if the object is not in a valid
    /// configuration. Otherwise, returns true.
    ///
    /// **Dart Source:** `text_span.dart:468-478`
    public override func debugAssertIsValid() -> Bool {
        assert({
            if let children = children {
                for child in children {
                    assert(child.debugAssertIsValid())
                }
            }
            return true
        }())
        return super.debugAssertIsValid()
    }

    // MARK: - Comparison

    /// Describe the difference between this span and another, in terms of
    /// how much damage it will make to the rendering. The comparison is deep.
    ///
    /// **Dart Source:** `text_span.dart:480-518`
    public override func compareTo(_ other: InlineSpan) -> RenderComparison {
        if self === other {
            return .identical
        }
        guard let textSpan = other as? TextSpan else {
            return .layout
        }
        if textSpan.text != text
            || children?.count != textSpan.children?.count
            || (style == nil) != (textSpan.style == nil)
        {
            return .layout
        }
        var result: RenderComparison = recognizer === textSpan.recognizer
            ? .identical
            : .metadata
        if let style = style {
            let candidate = style.compareTo(textSpan.style!)
            if candidate.rawValue > result.rawValue {
                result = candidate
            }
            if result == .layout {
                return result
            }
        }
        if let children = children {
            for index in 0..<children.count {
                let candidate = children[index].compareTo(textSpan.children![index])
                if candidate.rawValue > result.rawValue {
                    result = candidate
                }
                if result == .layout {
                    return result
                }
            }
        }
        return result
    }

    // MARK: - Equality

    /// Compares two `TextSpan` objects for equality.
    ///
    /// **Dart Source:** `text_span.dart:520-540`
    public static func == (lhs: TextSpan, rhs: TextSpan) -> Bool {
        if lhs === rhs {
            return true
        }
        // Check InlineSpan base equality (style)
        guard (lhs as InlineSpan) == (rhs as InlineSpan) else {
            return false
        }
        return lhs.text == rhs.text
            && lhs.recognizer === rhs.recognizer
            && lhs.semanticsLabel == rhs.semanticsLabel
            && lhs.semanticsIdentifier == rhs.semanticsIdentifier
            && _listEquals(lhs.children, rhs.children)
    }

    /// A hash value for this `TextSpan`.
    ///
    /// **Dart Source:** `text_span.dart:542-553`
    public override var hashValue: Int {
        var hasher = Hasher()
        hasher.combine(style)
        hasher.combine(text)
        if let recognizer = recognizer {
            hasher.combine(ObjectIdentifier(recognizer))
        }
        hasher.combine(semanticsLabel)
        hasher.combine(semanticsIdentifier)
        if let children = children {
            for child in children {
                hasher.combine(child.hashValue)
            }
        }
        return hasher.finalize()
    }

    // MARK: - Diagnostics

    /// Returns a brief string representation.
    ///
    /// **Dart Source:** `text_span.dart:555-556`
    public override func toStringShort() -> String {
        return objectRuntimeType(self, "TextSpan")
    }

    /// Fills the diagnostic properties for this `TextSpan`.
    ///
    /// **Dart Source:** `text_span.dart:558-590`
    public override func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
        super.debugFillProperties(properties)

        properties.add(
            StringProperty("text", text, showName: false, defaultValue: nil)
        )
        if style == nil && text == nil && children == nil {
            properties.add(DiagnosticsNode.message("(empty)"))
        }

        properties.add(
            DiagnosticsProperty<String>(
                "recognizer",
                recognizer.map { "\(type(of: $0))" },
                defaultValue: nil
            )
        )

        if let semanticsLabel = semanticsLabel {
            properties.add(StringProperty("semanticsLabel", semanticsLabel))
        }

        if let semanticsIdentifier = semanticsIdentifier {
            properties.add(StringProperty("semanticsIdentifier", semanticsIdentifier))
        }
    }

    /// Returns a list of `DiagnosticsNode` objects describing this node's children.
    ///
    /// **Dart Source:** `text_span.dart:592-598`
    public override func debugDescribeChildren() -> [any DiagnosticsNodeProtocol] {
        return children?.map { (child: InlineSpan) -> any DiagnosticsNodeProtocol in
            child.toDiagnosticsNode()
        } ?? []
    }
}

// MARK: - Private Helpers

/// Compares two optional arrays of `InlineSpan` for equality.
///
/// Uses dynamic dispatch to call the correct `==` operator for each element,
/// since Swift static `==` methods do not dispatch virtually.
private func _listEquals(_ a: [InlineSpan]?, _ b: [InlineSpan]?) -> Bool {
    if a == nil && b == nil { return true }
    guard let a = a, let b = b else { return false }
    guard a.count == b.count else { return false }
    for i in 0..<a.count {
        if !_inlineSpanEquals(a[i], b[i]) {
            return false
        }
    }
    return true
}

/// Dynamically dispatches equality comparison for `InlineSpan` subclasses.
///
/// Swift's static `==` method on base classes does not dispatch virtually,
/// so we need to check the concrete type and call the appropriate `==`.
private func _inlineSpanEquals(_ lhs: InlineSpan, _ rhs: InlineSpan) -> Bool {
    if lhs === rhs { return true }
    if type(of: lhs) != type(of: rhs) { return false }
    if let lhsTextSpan = lhs as? TextSpan, let rhsTextSpan = rhs as? TextSpan {
        return lhsTextSpan == rhsTextSpan
    }
    // Fall back to base InlineSpan equality (style comparison)
    return lhs == rhs
}
