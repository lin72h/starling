// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Summary information about a `SemanticsNode` object.
///
/// **Dart Source:** `packages/flutter/lib/src/semantics/semantics.dart`
/// **Original Name:** `SemanticsData`
/// **Lines:** 951-1410

import Foundation
import FlutterSwiftBridge

// MARK: - SemanticsTag Hashable Conformance

/// Make `SemanticsTag` usable in `Set` collections by conforming to `Hashable`
/// via identity (matching Dart's default identity-based equality for classes).
///
/// DIFFERENCE FROM DART: Explicit `Hashable` conformance using `ObjectIdentifier`.
/// REASON: Dart classes are implicitly identity-hashable for use in `Set`.
/// Swift requires explicit `Hashable` conformance. Using `ObjectIdentifier`
/// preserves the same identity-based semantics as Dart's `new` keyword behavior.
extension SemanticsTag: Hashable {
  public static func == (lhs: SemanticsTag, rhs: SemanticsTag) -> Bool {
    return lhs === rhs
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

// MARK: - SemanticsData

/// Summary information about a `SemanticsNode` object.
///
/// A semantics node might merge all descendants into itself,
/// which means the individual fields on the semantics node don't fully describe
/// the semantics at that node. This data structure contains the full semantics
/// for the node.
///
/// Typically obtained from `SemanticsNode.getSemanticsData()`.
///
/// **Dart Source:** `packages/flutter/lib/src/semantics/semantics.dart`
/// **Original Name:** `SemanticsData`
/// **Lines:** 951-1410
///
/// DIFFERENCE FROM DART: Using a Swift struct instead of `@immutable class`.
/// REASON: `SemanticsData` is immutable with value semantics in Dart; Swift structs
/// are the idiomatic equivalent. Cannot conform to `Diagnosticable` protocol
/// (which requires `AnyObject`) since this is a struct. `debugFillProperties`
/// is provided as a regular method instead.
public struct SemanticsData {
  /// Creates a semantics data object.
  ///
  /// If `label` is not empty, then `textDirection` must also not be null.
  ///
  /// **Dart Source:** `semantics.dart:955-1014`
  /// **Original:** `SemanticsData({...})`
  public init(
    flagsCollection: SemanticsFlags,
    actions: Int,
    identifier: String,
    attributedLabel: AttributedString,
    attributedValue: AttributedString,
    attributedIncreasedValue: AttributedString,
    attributedDecreasedValue: AttributedString,
    attributedHint: AttributedString,
    tooltip: String,
    textDirection: TextDirection?,
    rect: Rect,
    textSelection: TextSelection?,
    scrollIndex: Int?,
    scrollChildCount: Int?,
    scrollPosition: Double?,
    scrollExtentMax: Double?,
    scrollExtentMin: Double?,
    platformViewId: Int?,
    maxValueLength: Int?,
    currentValueLength: Int?,
    headingLevel: Int,
    linkUrl: URL?,
    role: SemanticsRole,
    controlsNodes: Set<String>?,
    validationResult: SemanticsValidationResult,
    inputType: SemanticsInputType,
    locale: FlutterSwiftBridge.Locale?,
    tags: Set<SemanticsTag>? = nil,
    transform: Matrix4? = nil,
    customSemanticsActionIds: [Int]? = nil
  ) {
    assert(
      tooltip.isEmpty || textDirection != nil,
      "A SemanticsData object with tooltip \"\(tooltip)\" had a null textDirection."
    )
    assert(
      attributedLabel.string.isEmpty || textDirection != nil,
      "A SemanticsData object with label \"\(attributedLabel.string)\" had a null textDirection."
    )
    assert(
      attributedValue.string.isEmpty || textDirection != nil,
      "A SemanticsData object with value \"\(attributedValue.string)\" had a null textDirection."
    )
    assert(
      attributedDecreasedValue.string.isEmpty || textDirection != nil,
      "A SemanticsData object with decreasedValue \"\(attributedDecreasedValue.string)\" had a null textDirection."
    )
    assert(
      attributedIncreasedValue.string.isEmpty || textDirection != nil,
      "A SemanticsData object with increasedValue \"\(attributedIncreasedValue.string)\" had a null textDirection."
    )
    assert(
      attributedHint.string.isEmpty || textDirection != nil,
      "A SemanticsData object with hint \"\(attributedHint.string)\" had a null textDirection."
    )
    assert(
      headingLevel >= 0 && headingLevel <= 6,
      "Heading level must be between 0 and 6"
    )
    assert(
      linkUrl == nil || flagsCollection.isLink,
      "A SemanticsData object with a linkUrl must have the isLink flag set to true"
    )

    self.flagsCollection = flagsCollection
    self.actions = actions
    self.identifier = identifier
    self.attributedLabel = attributedLabel
    self.attributedValue = attributedValue
    self.attributedIncreasedValue = attributedIncreasedValue
    self.attributedDecreasedValue = attributedDecreasedValue
    self.attributedHint = attributedHint
    self.tooltip = tooltip
    self.textDirection = textDirection
    self.rect = rect
    self.textSelection = textSelection
    self.scrollIndex = scrollIndex
    self.scrollChildCount = scrollChildCount
    self.scrollPosition = scrollPosition
    self.scrollExtentMax = scrollExtentMax
    self.scrollExtentMin = scrollExtentMin
    self.platformViewId = platformViewId
    self.maxValueLength = maxValueLength
    self.currentValueLength = currentValueLength
    self.headingLevel = headingLevel
    self.linkUrl = linkUrl
    self.role = role
    self.controlsNodes = controlsNodes
    self.validationResult = validationResult
    self.inputType = inputType
    self.locale = locale
    self.tags = tags
    self.transform = transform
    self.customSemanticsActionIds = customSemanticsActionIds
  }

  // MARK: - Stored Properties

  /// Semantics flags.
  ///
  /// **Dart Source:** `semantics.dart:1024`
  public let flagsCollection: SemanticsFlags

  /// A bit field of `SemanticsAction`s that apply to this node.
  ///
  /// **Dart Source:** `semantics.dart:1027`
  public let actions: Int

  /// A programmatic identifier for this node.
  ///
  /// **Dart Source:** `semantics.dart:1030`
  public let identifier: String

  /// A textual description for the current label of the node in
  /// `AttributedString` format.
  ///
  /// The reading direction is given by `textDirection`.
  ///
  /// See also `label`, which exposes just the raw text.
  ///
  /// **Dart Source:** `semantics.dart:1045`
  public let attributedLabel: AttributedString

  /// A textual description for the current value of the node in
  /// `AttributedString` format.
  ///
  /// The reading direction is given by `textDirection`.
  ///
  /// See also `value`, which exposes just the raw text.
  ///
  /// **Dart Source:** `semantics.dart:1060`
  public let attributedValue: AttributedString

  /// The value that `value` will become after performing a
  /// `SemanticsAction.increase` action in `AttributedString` format.
  ///
  /// The reading direction is given by `textDirection`.
  ///
  /// See also `increasedValue`, which exposes just the raw text.
  ///
  /// **Dart Source:** `semantics.dart:1076`
  public let attributedIncreasedValue: AttributedString

  /// The value that `value` will become after performing a
  /// `SemanticsAction.decrease` action in `AttributedString` format.
  ///
  /// The reading direction is given by `textDirection`.
  ///
  /// See also `decreasedValue`, which exposes just the raw text.
  ///
  /// **Dart Source:** `semantics.dart:1092`
  public let attributedDecreasedValue: AttributedString

  /// A brief description of the result of performing an action on this node
  /// in `AttributedString` format.
  ///
  /// The reading direction is given by `textDirection`.
  ///
  /// See also `hint`, which exposes just the raw text.
  ///
  /// **Dart Source:** `semantics.dart:1107`
  public let attributedHint: AttributedString

  /// A textual description of the widget's tooltip.
  ///
  /// The reading direction is given by `textDirection`.
  ///
  /// **Dart Source:** `semantics.dart:1112`
  public let tooltip: String

  /// Indicates that this subtree represents a heading.
  ///
  /// A value of 0 indicates that it is not a heading. The value should be a
  /// number between 1 and 6, indicating the hierarchical level as a heading.
  ///
  /// **Dart Source:** `semantics.dart:1118`
  public let headingLevel: Int

  /// The reading direction for the text in `label`, `value`,
  /// `increasedValue`, `decreasedValue`, and `hint`.
  ///
  /// **Dart Source:** `semantics.dart:1122`
  public let textDirection: TextDirection?

  /// The currently selected text (or the position of the cursor) within `value`
  /// if this node represents a text field.
  ///
  /// **Dart Source:** `semantics.dart:1126`
  public let textSelection: TextSelection?

  /// The total number of scrollable children that contribute to semantics.
  ///
  /// If the number of children are unknown or unbounded, this value will be
  /// nil.
  ///
  /// **Dart Source:** `semantics.dart:1132`
  public let scrollChildCount: Int?

  /// The index of the first visible semantic child of a scroll node.
  ///
  /// **Dart Source:** `semantics.dart:1135`
  public let scrollIndex: Int?

  /// Indicates the current scrolling position in logical pixels if the node is
  /// scrollable.
  ///
  /// The properties `scrollExtentMin` and `scrollExtentMax` indicate the valid
  /// in-range values for this property. The value for `scrollPosition` may
  /// (temporarily) be outside that range, e.g. during an overscroll.
  ///
  /// **Dart Source:** `semantics.dart:1147`
  public let scrollPosition: Double?

  /// Indicates the maximum in-range value for `scrollPosition` if the node is
  /// scrollable.
  ///
  /// This value may be infinity if the scroll is unbound.
  ///
  /// **Dart Source:** `semantics.dart:1157`
  public let scrollExtentMax: Double?

  /// Indicates the minimum in-range value for `scrollPosition` if the node is
  /// scrollable.
  ///
  /// This value may be infinity if the scroll is unbound.
  ///
  /// **Dart Source:** `semantics.dart:1167`
  public let scrollExtentMin: Double?

  /// The id of the platform view, whose semantics nodes will be added as
  /// children to this node.
  ///
  /// If this value is non-nil, the SemanticsNode must not have any children
  /// as those would be replaced by the semantics nodes of the referenced
  /// platform view.
  ///
  /// **Dart Source:** `semantics.dart:1180`
  public let platformViewId: Int?

  /// The maximum number of characters that can be entered into an editable
  /// text field.
  ///
  /// For the purpose of this function a character is defined as one Unicode
  /// scalar value.
  ///
  /// This should only be set when `isTextField` flag is set. Defaults
  /// to nil, which means no limit is imposed on the text field.
  ///
  /// **Dart Source:** `semantics.dart:1190`
  public let maxValueLength: Int?

  /// The current number of characters that have been entered into an editable
  /// text field.
  ///
  /// For the purpose of this function a character is defined as one Unicode
  /// scalar value.
  ///
  /// This should only be set when `isTextField` flag is set. This must
  /// be set when `maxValueLength` is set.
  ///
  /// **Dart Source:** `semantics.dart:1200`
  public let currentValueLength: Int?

  /// The URL that this node links to.
  ///
  /// **Dart Source:** `semantics.dart:1207`
  ///
  /// DIFFERENCE FROM DART: Uses Swift `URL` instead of Dart `Uri`.
  /// REASON: Swift's `URL` type from Foundation is the standard equivalent
  /// of Dart's `Uri` type.
  public let linkUrl: URL?

  /// The bounding box for this node in its coordinate system.
  ///
  /// **Dart Source:** `semantics.dart:1210`
  public let rect: Rect

  /// The set of `SemanticsTag`s associated with this node.
  ///
  /// **Dart Source:** `semantics.dart:1213`
  public let tags: Set<SemanticsTag>?

  /// The transform from this node's coordinate system to its parent's coordinate system.
  ///
  /// By default, the transform is nil, which represents the identity
  /// transformation (i.e., that this node has the same coordinate system as its
  /// parent).
  ///
  /// **Dart Source:** `semantics.dart:1220`
  ///
  /// DIFFERENCE FROM DART: Uses `Matrix4?` instead of Dart's `Matrix4?`.
  /// REASON: Direct equivalent; both represent a 4x4 transformation matrix.
  public let transform: Matrix4?

  /// The identifiers for the custom semantics actions and standard action
  /// overrides for this node.
  ///
  /// The list must be sorted in increasing order.
  ///
  /// **Dart Source:** `semantics.dart:1230`
  public let customSemanticsActionIds: [Int]?

  /// The semantic role of this node.
  ///
  /// **Dart Source:** `semantics.dart:1233`
  public let role: SemanticsRole

  /// The set of identifiers for nodes that this node controls.
  ///
  /// **Dart Source:** `semantics.dart:1238`
  public let controlsNodes: Set<String>?

  /// The validation result for this semantics node.
  ///
  /// **Dart Source:** `semantics.dart:1241`
  public let validationResult: SemanticsValidationResult

  /// The input type for this semantics node.
  ///
  /// **Dart Source:** `semantics.dart:1244`
  public let inputType: SemanticsInputType

  /// The locale for this semantics node.
  ///
  /// Assistive technologies use this property to correctly interpret the
  /// content of this semantics node.
  ///
  /// **Dart Source:** `semantics.dart:1250`
  public let locale: FlutterSwiftBridge.Locale?

  // MARK: - Computed Properties

  /// A textual description for the current label of the node.
  ///
  /// The reading direction is given by `textDirection`.
  ///
  /// This exposes the raw text of the `attributedLabel`.
  ///
  /// **Dart Source:** `semantics.dart:1037`
  /// **Original:** `String get label => attributedLabel.string;`
  public var label: String { attributedLabel.string }

  /// A textual description for the current value of the node.
  ///
  /// The reading direction is given by `textDirection`.
  ///
  /// This exposes the raw text of the `attributedValue`.
  ///
  /// **Dart Source:** `semantics.dart:1052`
  /// **Original:** `String get value => attributedValue.string;`
  public var value: String { attributedValue.string }

  /// The value that `value` will become after performing a
  /// `SemanticsAction.increase` action.
  ///
  /// The reading direction is given by `textDirection`.
  ///
  /// This exposes the raw text of the `attributedIncreasedValue`.
  ///
  /// **Dart Source:** `semantics.dart:1068`
  /// **Original:** `String get increasedValue => attributedIncreasedValue.string;`
  public var increasedValue: String { attributedIncreasedValue.string }

  /// The value that `value` will become after performing a
  /// `SemanticsAction.decrease` action.
  ///
  /// The reading direction is given by `textDirection`.
  ///
  /// This exposes the raw text of the `attributedDecreasedValue`.
  ///
  /// **Dart Source:** `semantics.dart:1084`
  /// **Original:** `String get decreasedValue => attributedDecreasedValue.string;`
  public var decreasedValue: String { attributedDecreasedValue.string }

  /// A brief description of the result of performing an action on this node.
  ///
  /// The reading direction is given by `textDirection`.
  ///
  /// This exposes the raw text of the `attributedHint`.
  ///
  /// **Dart Source:** `semantics.dart:1099`
  /// **Original:** `String get hint => attributedHint.string;`
  public var hint: String { attributedHint.string }

  // MARK: - Methods

  /// Whether `actions` contains the given action.
  ///
  /// **Dart Source:** `semantics.dart:1260`
  /// **Original:** `bool hasAction(SemanticsAction action) => (actions & action.index) != 0;`
  public func hasAction(_ action: SemanticsAction) -> Bool {
    return (actions & action.index) != 0
  }

  /// Returns a short string description of this object.
  ///
  /// **Dart Source:** `semantics.dart:1263`
  /// **Original:** `String toStringShort() => objectRuntimeType(this, 'SemanticsData');`
  public func toStringShort() -> String {
    return "SemanticsData"
  }

  /// Add additional properties associated with the node for debugging.
  ///
  /// **Dart Source:** `semantics.dart:1266-1322`
  /// **Original:** `void debugFillProperties(DiagnosticPropertiesBuilder properties)`
  ///
  /// DIFFERENCE FROM DART: This is a regular method instead of an override of
  /// `Diagnosticable.debugFillProperties`, because `SemanticsData` is a struct
  /// and cannot conform to the `Diagnosticable` protocol (which requires `AnyObject`).
  /// REASON: Swift structs cannot conform to class-constrained protocols.
  public func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
    properties.add(DiagnosticsProperty<Rect>("rect", rect, showName: false))
    properties.add(TransformProperty("transform", transform, showName: false, defaultValue: nil))
    let actionSummary: [String] = SemanticsAction.values.compactMap { action in
      (actions & action.index) != 0 ? action.name : nil
    }
    let customSemanticsActionSummary: [String?] = (customSemanticsActionIds ?? []).map { actionId in
      CustomSemanticsAction.getAction(actionId)?.label
    }
    properties.add(IterableProperty<String>("actions", actionSummary, ifEmpty: nil))
    properties.add(
      IterableProperty<String?>("customActions", customSemanticsActionSummary, ifEmpty: nil)
    )

    let flagSummary = flagsCollection.toStrings()
    properties.add(IterableProperty<String>("flags", flagSummary, ifEmpty: nil))
    properties.add(StringProperty("identifier", identifier, defaultValue: ""))
    properties.add(AttributedStringProperty("label", attributedLabel))
    properties.add(AttributedStringProperty("value", attributedValue))
    properties.add(AttributedStringProperty("increasedValue", attributedIncreasedValue))
    properties.add(AttributedStringProperty("decreasedValue", attributedDecreasedValue))
    properties.add(AttributedStringProperty("hint", attributedHint))
    properties.add(StringProperty("tooltip", tooltip, defaultValue: ""))
    properties.add(
      DiagnosticsProperty<TextDirection>("textDirection", textDirection, defaultValue: nil)
    )
    if textSelection?.isValid ?? false {
      properties.add(
        MessageProperty(
          "textSelection", "[\(textSelection!.start), \(textSelection!.end)]"
        )
      )
    }
    properties.add(IntProperty("platformViewId", platformViewId, defaultValue: nil))
    properties.add(IntProperty("maxValueLength", maxValueLength, defaultValue: nil))
    properties.add(IntProperty("currentValueLength", currentValueLength, defaultValue: nil))
    properties.add(IntProperty("scrollChildren", scrollChildCount, defaultValue: nil))
    properties.add(IntProperty("scrollIndex", scrollIndex, defaultValue: nil))
    properties.add(DoubleProperty("scrollExtentMin", scrollExtentMin, defaultValue: nil))
    properties.add(DoubleProperty("scrollPosition", scrollPosition, defaultValue: nil))
    properties.add(DoubleProperty("scrollExtentMax", scrollExtentMax, defaultValue: nil))
    properties.add(IntProperty("headingLevel", headingLevel, defaultValue: 0))
    properties.add(DiagnosticsProperty<URL>("linkUrl", linkUrl, defaultValue: nil))
    if let controlsNodes = controlsNodes {
      properties.add(
        IterableProperty<String>("controls", Array(controlsNodes), ifEmpty: nil)
      )
    }
    if role != .none {
      properties.add(
        DiagnosticsProperty<SemanticsRole>("role", role, defaultValue: SemanticsRole.none)
      )
    }
    if validationResult != .none {
      properties.add(
        DiagnosticsProperty<SemanticsValidationResult>(
          "validationResult",
          validationResult,
          defaultValue: SemanticsValidationResult.none
        )
      )
    }
  }

  // MARK: - Private Helpers

  /// Compares two sorted lists for equality.
  ///
  /// **Dart Source:** `semantics.dart:1393-1409`
  /// **Original:** `static bool _sortedListsEqual(List<int>? left, List<int>? right)`
  private static func _sortedListsEqual(_ left: [Int]?, _ right: [Int]?) -> Bool {
    if left == nil && right == nil {
      return true
    }
    if let left = left, let right = right {
      if left.count != right.count {
        return false
      }
      for i in 0..<left.count {
        if left[i] != right[i] {
          return false
        }
      }
      return true
    }
    return false
  }
}

// MARK: - Equatable

/// DIFFERENCE FROM DART: Cannot conform to `Equatable` protocol because
/// `AttributedString` and `SemanticsFlags` (a class) don't conform to `Equatable`
/// in the standard protocol sense. Instead, we implement `==` as a static method.
/// REASON: `AttributedString` uses a custom `==` operator but does not conform to
/// the `Equatable` protocol. `SemanticsFlags` is a class with `Equatable` conformance
/// but `SemanticsTag` only has identity-based equality via `ObjectIdentifier`.
extension SemanticsData: Equatable {
  /// **Dart Source:** `semantics.dart:1325-1356`
  /// **Original:** `bool operator ==(Object other)`
  public static func == (lhs: SemanticsData, rhs: SemanticsData) -> Bool {
    return lhs.flagsCollection == rhs.flagsCollection
      && lhs.actions == rhs.actions
      && lhs.identifier == rhs.identifier
      && lhs.attributedLabel == rhs.attributedLabel
      && lhs.attributedValue == rhs.attributedValue
      && lhs.attributedIncreasedValue == rhs.attributedIncreasedValue
      && lhs.attributedDecreasedValue == rhs.attributedDecreasedValue
      && lhs.attributedHint == rhs.attributedHint
      && lhs.tooltip == rhs.tooltip
      && lhs.textDirection == rhs.textDirection
      && lhs.rect == rhs.rect
      && lhs.tags == rhs.tags
      && lhs.scrollChildCount == rhs.scrollChildCount
      && lhs.scrollIndex == rhs.scrollIndex
      && lhs.textSelection == rhs.textSelection
      && lhs.scrollPosition == rhs.scrollPosition
      && lhs.scrollExtentMax == rhs.scrollExtentMax
      && lhs.scrollExtentMin == rhs.scrollExtentMin
      && lhs.platformViewId == rhs.platformViewId
      && lhs.maxValueLength == rhs.maxValueLength
      && lhs.currentValueLength == rhs.currentValueLength
      && lhs.transform == rhs.transform
      && lhs.headingLevel == rhs.headingLevel
      && lhs.linkUrl == rhs.linkUrl
      && lhs.role == rhs.role
      && lhs.validationResult == rhs.validationResult
      && lhs.inputType == rhs.inputType
      && _sortedListsEqual(lhs.customSemanticsActionIds, rhs.customSemanticsActionIds)
      && lhs.controlsNodes == rhs.controlsNodes
  }
}

// MARK: - Hashable

extension SemanticsData: Hashable {
  /// **Dart Source:** `semantics.dart:1358-1391`
  /// **Original:** `int get hashCode => Object.hash(...)`
  ///
  /// DIFFERENCE FROM DART: Uses Swift's `Hasher` instead of Dart's `Object.hash`.
  /// REASON: Swift's `Hasher` is the idiomatic way to implement custom hashing.
  /// The hash includes the same fields as the Dart implementation.
  public func hash(into hasher: inout Hasher) {
    hasher.combine(flagsCollection)
    hasher.combine(actions)
    hasher.combine(identifier)
    hasher.combine(attributedLabel.hashValue)
    hasher.combine(attributedValue.hashValue)
    hasher.combine(attributedIncreasedValue.hashValue)
    hasher.combine(attributedDecreasedValue.hashValue)
    hasher.combine(attributedHint.hashValue)
    hasher.combine(tooltip)
    hasher.combine(textDirection)
    hasher.combine(rect)
    hasher.combine(tags)
    hasher.combine(textSelection)
    hasher.combine(scrollChildCount)
    hasher.combine(scrollIndex)
    hasher.combine(scrollPosition)
    hasher.combine(scrollExtentMax)
    hasher.combine(scrollExtentMin)
    hasher.combine(platformViewId)
    hasher.combine(maxValueLength)
    hasher.combine(currentValueLength)
    if let transform = transform {
      for element in transform.storage {
        hasher.combine(element)
      }
    }
    hasher.combine(headingLevel)
    hasher.combine(linkUrl)
    if let ids = customSemanticsActionIds {
      for id in ids {
        hasher.combine(id)
      }
    }
    hasher.combine(role)
    hasher.combine(validationResult)
    if let controls = controlsNodes {
      for node in controls.sorted() {
        hasher.combine(node)
      }
    }
    hasher.combine(inputType)
  }
}
