// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Semantics hint overrides and properties used by assistive technologies.
///
/// **Dart Source:** `packages/flutter/lib/src/semantics/semantics.dart`

import Foundation
import FlutterSwiftBridge

// MARK: - SemanticsHintOverrides

/// Provides hint values which override the default hints on supported
/// platforms.
///
/// On iOS, these values are always ignored.
///
/// **Dart Source:** `semantics.dart:1431-1481`
/// **Original Name:** `SemanticsHintOverrides`
///
/// DIFFERENCE FROM DART: Uses a Swift struct instead of `@immutable class` extending
/// `DiagnosticableTree`.
/// REASON: `SemanticsHintOverrides` is immutable with value semantics in Dart; Swift
/// structs are the idiomatic equivalent. Cannot conform to `DiagnosticableTree` protocol
/// (which requires `AnyObject`) since this is a struct. `debugFillProperties` is provided
/// as a regular method instead.
public struct SemanticsHintOverrides: Hashable, Sendable {

  /// Creates a semantics hint overrides.
  ///
  /// **Dart Source:** `semantics.dart:1433-1435`
  /// **Original:** `const SemanticsHintOverrides({this.onTapHint, this.onLongPressHint})`
  public init(onTapHint: String? = nil, onLongPressHint: String? = nil) {
    assert(onTapHint != "", "onTapHint must not be an empty string")
    assert(onLongPressHint != "", "onLongPressHint must not be an empty string")
    self.onTapHint = onTapHint
    self.onLongPressHint = onLongPressHint
  }

  /// The hint text for a tap action.
  ///
  /// If null, the standard hint is used instead.
  ///
  /// The hint should describe what happens when a tap occurs, not the
  /// manner in which a tap is accomplished.
  ///
  /// Bad: 'Double tap to show movies'.
  /// Good: 'show movies'.
  ///
  /// **Dart Source:** `semantics.dart:1437-1446`
  public let onTapHint: String?

  /// The hint text for a long press action.
  ///
  /// If null, the standard hint is used instead.
  ///
  /// The hint should describe what happens when a long press occurs, not
  /// the manner in which the long press is accomplished.
  ///
  /// Bad: 'Double tap and hold to show tooltip'.
  /// Good: 'show tooltip'.
  ///
  /// **Dart Source:** `semantics.dart:1448-1457`
  public let onLongPressHint: String?

  /// Whether there are any non-null hint values.
  ///
  /// **Dart Source:** `semantics.dart:1460`
  /// **Original:** `bool get isNotEmpty => onTapHint != null || onLongPressHint != null;`
  public var isNotEmpty: Bool {
    onTapHint != nil || onLongPressHint != nil
  }

  // MARK: - Hashable

  /// **Dart Source:** `semantics.dart:1463`
  public func hash(into hasher: inout Hasher) {
    hasher.combine(onTapHint)
    hasher.combine(onLongPressHint)
  }

  /// **Dart Source:** `semantics.dart:1466-1472`
  public static func == (lhs: SemanticsHintOverrides, rhs: SemanticsHintOverrides) -> Bool {
    lhs.onTapHint == rhs.onTapHint && lhs.onLongPressHint == rhs.onLongPressHint
  }

  // MARK: - Debug

  /// Add additional properties associated with the node for debugging.
  ///
  /// **Dart Source:** `semantics.dart:1476-1480`
  /// **Original:** `void debugFillProperties(DiagnosticPropertiesBuilder properties)`
  ///
  /// DIFFERENCE FROM DART: This is a regular method instead of an override of
  /// `DiagnosticableTree.debugFillProperties`, because `SemanticsHintOverrides`
  /// is a struct and cannot conform to the `Diagnosticable` protocol (which requires `AnyObject`).
  /// REASON: Swift structs cannot conform to class-constrained protocols.
  public func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
    properties.add(StringProperty("onTapHint", onTapHint, defaultValue: nil))
    properties.add(StringProperty("onLongPressHint", onLongPressHint, defaultValue: nil))
  }
}

// MARK: - SemanticsProperties

/// Contains properties used by assistive technologies to make the application
/// more accessible.
///
/// The properties of this class are used to generate `SemanticsNode`s in the
/// semantics tree.
///
/// **Dart Source:** `semantics.dart:1489-2505`
/// **Original Name:** `SemanticsProperties`
///
/// DIFFERENCE FROM DART: Uses a Swift struct instead of `@immutable class` extending
/// `DiagnosticableTree`.
/// REASON: `SemanticsProperties` is immutable with value semantics in Dart; Swift structs
/// are the idiomatic equivalent. Cannot conform to `DiagnosticableTree` protocol (which
/// requires `AnyObject`) since this is a struct. `debugFillProperties` is provided as a
/// regular method instead.
///
/// DIFFERENCE FROM DART: Skipped deprecated `focusable` parameter.
/// REASON: The parameter was deprecated after v3.36.0-0.0.pre. Setting `focused`
/// automatically sets focusable.
// DIFFERENCE FROM DART: Not conforming to `Sendable`.
// REASON: Contains closure properties (`VoidCallback`, `MoveCursorHandler`, etc.)
// which are non-Sendable function types. Thread safety is deferred per migration guide.
public struct SemanticsProperties {

  /// Creates a semantic annotation.
  ///
  /// **Dart Source:** `semantics.dart:1491-1593`
  /// **Original:** `const SemanticsProperties({...})`
  public init(
    enabled: Bool? = nil,
    checked: Bool? = nil,
    mixed: Bool? = nil,
    expanded: Bool? = nil,
    selected: Bool? = nil,
    toggled: Bool? = nil,
    button: Bool? = nil,
    link: Bool? = nil,
    linkUrl: URL? = nil,
    header: Bool? = nil,
    headingLevel: Int? = nil,
    textField: Bool? = nil,
    slider: Bool? = nil,
    keyboardKey: Bool? = nil,
    readOnly: Bool? = nil,
    focused: Bool? = nil,
    inMutuallyExclusiveGroup: Bool? = nil,
    hidden: Bool? = nil,
    obscured: Bool? = nil,
    multiline: Bool? = nil,
    scopesRoute: Bool? = nil,
    namesRoute: Bool? = nil,
    image: Bool? = nil,
    liveRegion: Bool? = nil,
    isRequired: Bool? = nil,
    maxValueLength: Int? = nil,
    currentValueLength: Int? = nil,
    identifier: String? = nil,
    label: String? = nil,
    attributedLabel: AttributedString? = nil,
    value: String? = nil,
    attributedValue: AttributedString? = nil,
    increasedValue: String? = nil,
    attributedIncreasedValue: AttributedString? = nil,
    decreasedValue: String? = nil,
    attributedDecreasedValue: AttributedString? = nil,
    hint: String? = nil,
    tooltip: String? = nil,
    attributedHint: AttributedString? = nil,
    hintOverrides: SemanticsHintOverrides? = nil,
    textDirection: TextDirection? = nil,
    sortKey: SemanticsSortKey? = nil,
    tagForChildren: SemanticsTag? = nil,
    role: SemanticsRole? = nil,
    controlsNodes: Set<String>? = nil,
    inputType: SemanticsInputType? = nil,
    validationResult: SemanticsValidationResult = .none,
    onTap: VoidCallback? = nil,
    onLongPress: VoidCallback? = nil,
    onScrollLeft: VoidCallback? = nil,
    onScrollRight: VoidCallback? = nil,
    onScrollUp: VoidCallback? = nil,
    onScrollDown: VoidCallback? = nil,
    onIncrease: VoidCallback? = nil,
    onDecrease: VoidCallback? = nil,
    onCopy: VoidCallback? = nil,
    onCut: VoidCallback? = nil,
    onPaste: VoidCallback? = nil,
    onMoveCursorForwardByCharacter: MoveCursorHandler? = nil,
    onMoveCursorBackwardByCharacter: MoveCursorHandler? = nil,
    onMoveCursorForwardByWord: MoveCursorHandler? = nil,
    onMoveCursorBackwardByWord: MoveCursorHandler? = nil,
    onSetSelection: SetSelectionHandler? = nil,
    onSetText: SetTextHandler? = nil,
    onDidGainAccessibilityFocus: VoidCallback? = nil,
    onDidLoseAccessibilityFocus: VoidCallback? = nil,
    onFocus: VoidCallback? = nil,
    onDismiss: VoidCallback? = nil,
    onExpand: VoidCallback? = nil,
    onCollapse: VoidCallback? = nil,
    customSemanticsActions: [CustomSemanticsAction: VoidCallback]? = nil
  ) {
    assert(
      label == nil || attributedLabel == nil,
      "Only one of label or attributedLabel should be provided"
    )
    assert(
      value == nil || attributedValue == nil,
      "Only one of value or attributedValue should be provided"
    )
    assert(
      increasedValue == nil || attributedIncreasedValue == nil,
      "Only one of increasedValue or attributedIncreasedValue should be provided"
    )
    assert(
      decreasedValue == nil || attributedDecreasedValue == nil,
      "Only one of decreasedValue or attributedDecreasedValue should be provided"
    )
    assert(
      hint == nil || attributedHint == nil,
      "Only one of hint or attributedHint should be provided"
    )
    assert(
      headingLevel == nil || (headingLevel! > 0 && headingLevel! <= 6),
      "Heading level must be between 1 and 6"
    )
    assert(
      linkUrl == nil || (link ?? false),
      "If linkUrl is set then link must be true"
    )

    self.enabled = enabled
    self.checked = checked
    self.mixed = mixed
    self.expanded = expanded
    self.selected = selected
    self.toggled = toggled
    self.button = button
    self.link = link
    self.linkUrl = linkUrl
    self.header = header
    self.headingLevel = headingLevel
    self.textField = textField
    self.slider = slider
    self.keyboardKey = keyboardKey
    self.readOnly = readOnly
    self.focused = focused
    self.inMutuallyExclusiveGroup = inMutuallyExclusiveGroup
    self.hidden = hidden
    self.obscured = obscured
    self.multiline = multiline
    self.scopesRoute = scopesRoute
    self.namesRoute = namesRoute
    self.image = image
    self.liveRegion = liveRegion
    self.isRequired = isRequired
    self.maxValueLength = maxValueLength
    self.currentValueLength = currentValueLength
    self.identifier = identifier
    self.label = label
    self.attributedLabel = attributedLabel
    self.value = value
    self.attributedValue = attributedValue
    self.increasedValue = increasedValue
    self.attributedIncreasedValue = attributedIncreasedValue
    self.decreasedValue = decreasedValue
    self.attributedDecreasedValue = attributedDecreasedValue
    self.hint = hint
    self.tooltip = tooltip
    self.attributedHint = attributedHint
    self.hintOverrides = hintOverrides
    self.textDirection = textDirection
    self.sortKey = sortKey
    self.tagForChildren = tagForChildren
    self.role = role
    self.controlsNodes = controlsNodes
    self.inputType = inputType
    self.validationResult = validationResult
    self.onTap = onTap
    self.onLongPress = onLongPress
    self.onScrollLeft = onScrollLeft
    self.onScrollRight = onScrollRight
    self.onScrollUp = onScrollUp
    self.onScrollDown = onScrollDown
    self.onIncrease = onIncrease
    self.onDecrease = onDecrease
    self.onCopy = onCopy
    self.onCut = onCut
    self.onPaste = onPaste
    self.onMoveCursorForwardByCharacter = onMoveCursorForwardByCharacter
    self.onMoveCursorBackwardByCharacter = onMoveCursorBackwardByCharacter
    self.onMoveCursorForwardByWord = onMoveCursorForwardByWord
    self.onMoveCursorBackwardByWord = onMoveCursorBackwardByWord
    self.onSetSelection = onSetSelection
    self.onSetText = onSetText
    self.onDidGainAccessibilityFocus = onDidGainAccessibilityFocus
    self.onDidLoseAccessibilityFocus = onDidLoseAccessibilityFocus
    self.onFocus = onFocus
    self.onDismiss = onDismiss
    self.onExpand = onExpand
    self.onCollapse = onCollapse
    self.customSemanticsActions = customSemanticsActions
  }

  // MARK: - Boolean Flag Properties

  /// If non-null, indicates that this subtree represents something that can be
  /// in an enabled or disabled state.
  ///
  /// For example, a button that a user can currently interact with would set
  /// this field to true. A button that currently does not respond to user
  /// interactions would set this field to false.
  ///
  /// **Dart Source:** `semantics.dart:1595-1601`
  public let enabled: Bool?

  /// If non-null, indicates that this subtree represents a checkbox
  /// or similar widget with a "checked" state, and what its current
  /// state is.
  ///
  /// When the `Checkbox.value` of a tristate Checkbox is null,
  /// indicating a mixed-state, this value shall be false, in which
  /// case, `mixed` will be true.
  ///
  /// This is mutually exclusive with `toggled` and `mixed`.
  ///
  /// **Dart Source:** `semantics.dart:1603-1612`
  public let checked: Bool?

  /// If non-null, indicates that this subtree represents a checkbox
  /// or similar widget with a "half-checked" state or similar, and
  /// whether it is currently in this half-checked state.
  ///
  /// This must be null when `Checkbox.tristate` is false, or
  /// when the widget is not a checkbox. When a tristate
  /// checkbox is fully unchecked/checked, this value shall
  /// be false.
  ///
  /// This is mutually exclusive with `checked` and `toggled`.
  ///
  /// **Dart Source:** `semantics.dart:1614-1624`
  public let mixed: Bool?

  /// If non-null, indicates that this subtree represents something
  /// that can be in an "expanded" or "collapsed" state.
  ///
  /// For example, if a `SubmenuButton` is opened, this property
  /// should be set to true; otherwise, this property should be
  /// false.
  ///
  /// **Dart Source:** `semantics.dart:1626-1632`
  public let expanded: Bool?

  /// If non-null, indicates that this subtree represents a toggle switch
  /// or similar widget with an "on" state, and what its current
  /// state is.
  ///
  /// This is mutually exclusive with `checked` and `mixed`.
  ///
  /// **Dart Source:** `semantics.dart:1634-1639`
  public let toggled: Bool?

  /// If non-null indicates that this subtree represents something that can be
  /// in a selected or unselected state, and what its current state is.
  ///
  /// The active tab in a tab bar for example is considered "selected", whereas
  /// all other tabs are unselected.
  ///
  /// **Dart Source:** `semantics.dart:1641-1646`
  public let selected: Bool?

  /// If non-null, indicates that this subtree represents a button.
  ///
  /// TalkBack/VoiceOver provides users with the hint "button" when a button
  /// is focused.
  ///
  /// **Dart Source:** `semantics.dart:1648-1652`
  public let button: Bool?

  /// If non-null, indicates that this subtree represents a link.
  ///
  /// iOS's VoiceOver provides users with a unique hint when a link is focused.
  /// Android's Talkback will announce a link hint the same way it does a
  /// button.
  ///
  /// **Dart Source:** `semantics.dart:1654-1659`
  public let link: Bool?

  /// If non-null, indicates that this subtree represents a header.
  ///
  /// A header divides into sections. For example, an address book application
  /// might define headers A, B, C, etc. to divide the list of alphabetically
  /// sorted contacts into sections.
  ///
  /// **Dart Source:** `semantics.dart:1661-1666`
  public let header: Bool?

  /// If non-null, indicates that this subtree represents a text field.
  ///
  /// TalkBack/VoiceOver provide special affordances to enter text into a
  /// text field.
  ///
  /// **Dart Source:** `semantics.dart:1668-1672`
  public let textField: Bool?

  /// If non-null, indicates that this subtree represents a slider.
  ///
  /// Talkback/VoiceOver provides users with the hint "slider" when a
  /// slider is focused.
  ///
  /// **Dart Source:** `semantics.dart:1674-1678`
  public let slider: Bool?

  /// If non-null, indicates that this subtree represents a keyboard key.
  ///
  /// **Dart Source:** `semantics.dart:1680-1681`
  public let keyboardKey: Bool?

  /// If non-null, indicates that this subtree is read only.
  ///
  /// Only applicable when `textField` is true.
  ///
  /// TalkBack/VoiceOver will treat it as non-editable text field.
  ///
  /// **Dart Source:** `semantics.dart:1683-1688`
  public let readOnly: Bool?

  /// If non-null, whether the node currently holds input focus.
  ///
  /// If null, the node is not focusable.
  ///
  /// At most one node in the tree should hold input focus at any point in time.
  ///
  /// Input focus indicates that the node will receive keyboard events. It is not
  /// to be confused with accessibility focus. Accessibility focus is the
  /// green/black rectangular highlight that TalkBack/VoiceOver draws around the
  /// element it is reading, and is separate from input focus.
  ///
  /// **Dart Source:** `semantics.dart:1705-1716`
  public let focused: Bool?

  /// If non-null, whether a semantic node is in a mutually exclusive group.
  ///
  /// For example, a radio button is in a mutually exclusive group because only
  /// one radio button in that group can be marked as `checked`.
  ///
  /// **Dart Source:** `semantics.dart:1718-1722`
  public let inMutuallyExclusiveGroup: Bool?

  /// If non-null, whether the node is considered hidden.
  ///
  /// Hidden elements are currently not visible on screen. They may be covered
  /// by other elements or positioned outside of the visible area of a viewport.
  ///
  /// Hidden elements cannot gain accessibility focus though regular touch. The
  /// only way they can be focused is by moving the focus to them via linear
  /// navigation.
  ///
  /// Platforms are free to completely ignore hidden elements and new platforms
  /// are encouraged to do so.
  ///
  /// Instead of marking an element as hidden it should usually be excluded from
  /// the semantics tree altogether. Hidden elements are only included in the
  /// semantics tree to work around platform limitations and they are mainly
  /// used to implement accessibility scrolling on iOS.
  ///
  /// **Dart Source:** `semantics.dart:1724-1740`
  public let hidden: Bool?

  /// If non-null, whether `value` should be obscured.
  ///
  /// This option is usually set in combination with `textField` to indicate
  /// that the text field contains a password (or other sensitive information).
  /// Doing so instructs screen readers to not read out the `value`.
  ///
  /// **Dart Source:** `semantics.dart:1742-1747`
  public let obscured: Bool?

  /// Whether the `value` is coming from a field that supports multiline text
  /// editing.
  ///
  /// This option is only meaningful when `textField` is true to indicate
  /// whether it's a single-line or multiline text field.
  ///
  /// This option is null when `textField` is false.
  ///
  /// **Dart Source:** `semantics.dart:1749-1756`
  public let multiline: Bool?

  /// If non-null, whether the node corresponds to the root of a subtree for
  /// which a route name should be announced.
  ///
  /// Generally, this is set in combination with
  /// `SemanticsConfiguration.explicitChildNodes`, since nodes with this flag
  /// are not considered focusable by Android or iOS.
  ///
  /// **Dart Source:** `semantics.dart:1758-1769`
  public let scopesRoute: Bool?

  /// If non-null, whether the node contains the semantic label for a route.
  ///
  /// **Dart Source:** `semantics.dart:1771-1776`
  public let namesRoute: Bool?

  /// If non-null, whether the node represents an image.
  ///
  /// **Dart Source:** `semantics.dart:1778-1783`
  public let image: Bool?

  /// If non-null, whether the node should be considered a live region.
  ///
  /// A live region indicates that updates to semantics node are important.
  /// Platforms may use this information to make polite announcements to the
  /// user to inform them of updates to this node.
  ///
  /// An example of a live region is a `SnackBar` widget. On Android and iOS,
  /// live region causes a polite announcement to be generated automatically,
  /// even if the widget does not have accessibility focus. This announcement
  /// may not be spoken if the OS accessibility services are already
  /// announcing something else, such as reading the label of a focused widget
  /// or providing a system announcement.
  ///
  /// **Dart Source:** `semantics.dart:1785-1802`
  public let liveRegion: Bool?

  /// If non-null, whether the node should be considered required.
  ///
  /// If true, user input is required on the semantics node before a form can
  /// be submitted. If false, the node is optional before a form can be
  /// submitted. If null, the node does not have a required semantics.
  ///
  /// For example, a login form requires its email text field to be non-empty.
  ///
  /// On web, this will set a `aria-required` attribute on the DOM element
  /// that corresponds to the semantics node.
  ///
  /// **Dart Source:** `semantics.dart:1804-1818`
  public let isRequired: Bool?

  // MARK: - Int Properties

  /// The maximum number of characters that can be entered into an editable
  /// text field.
  ///
  /// For the purpose of this function a character is defined as one Unicode
  /// scalar value.
  ///
  /// This should only be set when `textField` is true. Defaults to null,
  /// which means no limit is imposed on the text field.
  ///
  /// **Dart Source:** `semantics.dart:1820-1828`
  public let maxValueLength: Int?

  /// The current number of characters that have been entered into an editable
  /// text field.
  ///
  /// For the purpose of this function a character is defined as one Unicode
  /// scalar value.
  ///
  /// This should only be set when `textField` is true. Must be set when
  /// `maxValueLength` is set.
  ///
  /// **Dart Source:** `semantics.dart:1830-1838`
  public let currentValueLength: Int?

  /// The heading level in the DOM document structure.
  ///
  /// This is only applied to web semantics and is ignored on other platforms.
  ///
  /// Screen readers will use this value to determine which part of the page
  /// structure this heading represents. A level 1 heading, indicated
  /// with aria-level="1", usually indicates the main heading of a page,
  /// a level 2 heading, defined with aria-level="2" the first subsection,
  /// a level 3 is a subsection of that, and so on.
  ///
  /// **Dart Source:** `semantics.dart:2032-2041`
  public let headingLevel: Int?

  // MARK: - String Properties

  /// Provides an identifier for the semantics node in native accessibility hierarchy.
  ///
  /// This value is not exposed to the users of the app.
  ///
  /// It's usually used for UI testing with tools that work by querying the
  /// native accessibility, like UIAutomator, XCUITest, or Appium. It can be
  /// matched with `CommonFinders.bySemanticsIdentifier`.
  ///
  /// On Android, this is used for `AccessibilityNodeInfo.setViewIdResourceName`.
  /// It'll appear in accessibility hierarchy as `resource-id`.
  ///
  /// On iOS, this will set `UIAccessibilityElement.accessibilityIdentifier`.
  ///
  /// On web, this will set a `flt-semantics-identifier` attribute on the DOM element
  /// that corresponds to the semantics node.
  ///
  /// **Dart Source:** `semantics.dart:1840-1857`
  public let identifier: String?

  /// Provides a textual description of the widget.
  ///
  /// If a label is provided, there must either be an ambient `Directionality`
  /// or an explicit `textDirection` should be provided.
  ///
  /// Callers must not provide both `label` and `attributedLabel`. One or both
  /// must be null.
  ///
  /// **Dart Source:** `semantics.dart:1859-1872`
  public let label: String?

  /// Provides a textual description of the value of the widget.
  ///
  /// If a value is provided, there must either be an ambient `Directionality`
  /// or an explicit `textDirection` should be provided.
  ///
  /// Callers must not provide both `value` and `attributedValue`. One or both
  /// must be null.
  ///
  /// **Dart Source:** `semantics.dart:1889-1902`
  public let value: String?

  /// The value that `value` or `attributedValue` will become after a
  /// `SemanticsAction.increase` action has been performed on this widget.
  ///
  /// If a value is provided, `onIncrease` must also be set and there must
  /// either be an ambient `Directionality` or an explicit `textDirection`
  /// must be provided.
  ///
  /// Callers must not provide both `increasedValue` and
  /// `attributedIncreasedValue`. One or both must be null.
  ///
  /// **Dart Source:** `semantics.dart:1920-1936`
  public let increasedValue: String?

  /// The value that `value` or `attributedValue` will become after a
  /// `SemanticsAction.decrease` action has been performed on this widget.
  ///
  /// If a value is provided, `onDecrease` must also be set and there must
  /// either be an ambient `Directionality` or an explicit `textDirection`
  /// must be provided.
  ///
  /// Callers must not provide both `decreasedValue` and
  /// `attributedDecreasedValue`. One or both must be null.
  ///
  /// **Dart Source:** `semantics.dart:1955-1971`
  public let decreasedValue: String?

  /// Provides a brief textual description of the result of an action performed
  /// on the widget.
  ///
  /// If a hint is provided, there must either be an ambient `Directionality`
  /// or an explicit `textDirection` should be provided.
  ///
  /// Callers must not provide both `hint` and `attributedHint`. One or both
  /// must be null.
  ///
  /// **Dart Source:** `semantics.dart:1990-2004`
  public let hint: String?

  /// Provides a textual description of the widget's tooltip.
  ///
  /// In Android, this property sets the `AccessibilityNodeInfo.setTooltipText`.
  /// In iOS, this property is appended to the end of the
  /// `UIAccessibilityElement.accessibilityLabel`.
  ///
  /// If a `tooltip` is provided, there must either be an ambient
  /// `Directionality` or an explicit `textDirection` should be provided.
  ///
  /// **Dart Source:** `semantics.dart:2022-2030`
  public let tooltip: String?

  // MARK: - AttributedString Properties

  /// Provides an `AttributedString` version of textual description of the widget.
  ///
  /// If an `attributedLabel` is provided, there must either be an ambient
  /// `Directionality` or an explicit `textDirection` should be provided.
  ///
  /// Callers must not provide both `label` and `attributedLabel`. One or both
  /// must be null.
  ///
  /// **Dart Source:** `semantics.dart:1874-1887`
  public let attributedLabel: AttributedString?

  /// Provides an `AttributedString` version of textual description of the value
  /// of the widget.
  ///
  /// If an `attributedValue` is provided, there must either be an ambient
  /// `Directionality` or an explicit `textDirection` should be provided.
  ///
  /// Callers must not provide both `value` and `attributedValue`. One or both
  /// must be null.
  ///
  /// **Dart Source:** `semantics.dart:1904-1918`
  public let attributedValue: AttributedString?

  /// The `AttributedString` that `value` or `attributedValue` will become after
  /// a `SemanticsAction.increase` action has been performed on this widget.
  ///
  /// If an `attributedIncreasedValue` is provided, `onIncrease` must also be set
  /// and there must either be an ambient `Directionality` or an explicit
  /// `textDirection` must be provided.
  ///
  /// Callers must not provide both `increasedValue` and
  /// `attributedIncreasedValue`. One or both must be null.
  ///
  /// **Dart Source:** `semantics.dart:1938-1953`
  public let attributedIncreasedValue: AttributedString?

  /// The `AttributedString` that `value` or `attributedValue` will become after
  /// a `SemanticsAction.decrease` action has been performed on this widget.
  ///
  /// If an `attributedDecreasedValue` is provided, `onDecrease` must also be set
  /// and there must either be an ambient `Directionality` or an explicit
  /// `textDirection` must be provided.
  ///
  /// Callers must not provide both `decreasedValue` and
  /// `attributedDecreasedValue`. One or both must be null.
  ///
  /// **Dart Source:** `semantics.dart:1973-1988`
  public let attributedDecreasedValue: AttributedString?

  /// Provides an `AttributedString` version of brief textual description of the
  /// result of an action performed on the widget.
  ///
  /// If an `attributedHint` is provided, there must either be an ambient
  /// `Directionality` or an explicit `textDirection` should be provided.
  ///
  /// Callers must not provide both `hint` and `attributedHint`. One or both
  /// must be null.
  ///
  /// **Dart Source:** `semantics.dart:2006-2020`
  public let attributedHint: AttributedString?

  // MARK: - Other Properties

  /// Overrides the default accessibility hints provided by the platform.
  ///
  /// This `hintOverrides` property does not affect how the platform processes hints;
  /// it only sets the custom text that will be read by assistive technology.
  ///
  /// On Android, these overrides replace the default hints for semantics nodes
  /// with tap or long-press actions. For example, if `SemanticsHintOverrides.onTapHint`
  /// is provided, instead of saying `Double tap to activate`, the screen reader
  /// will say `Double tap to <onTapHint>`.
  ///
  /// On iOS, this property is ignored, and default platform behavior applies.
  ///
  /// **Dart Source:** `semantics.dart:2043-2066`
  public let hintOverrides: SemanticsHintOverrides?

  /// The reading direction of the `label`, `value`, `increasedValue`,
  /// `decreasedValue`, and `hint`.
  ///
  /// Defaults to the ambient `Directionality`.
  ///
  /// **Dart Source:** `semantics.dart:2068-2072`
  public let textDirection: TextDirection?

  /// Determines the position of this node among its siblings in the traversal
  /// sort order.
  ///
  /// This is used to describe the order in which the semantic node should be
  /// traversed by the accessibility services on the platform (e.g. VoiceOver
  /// on iOS and TalkBack on Android).
  ///
  /// **Dart Source:** `semantics.dart:2074-2080`
  public let sortKey: SemanticsSortKey?

  /// A tag to be applied to the child `SemanticsNode`s of this widget.
  ///
  /// The tag is added to all child `SemanticsNode`s that pass through the
  /// `RenderObject` corresponding to this widget while looking to be attached
  /// to a parent SemanticsNode.
  ///
  /// Tags are used to communicate to a parent SemanticsNode that a child
  /// SemanticsNode was passed through a particular RenderObject. The parent can
  /// use this information to determine the shape of the semantics tree.
  ///
  /// **Dart Source:** `semantics.dart:2082-2096`
  public let tagForChildren: SemanticsTag?

  /// The URL that this node links to.
  ///
  /// On the web, this is used to set the `href` attribute of the DOM element.
  ///
  /// **Dart Source:** `semantics.dart:2098-2105`
  ///
  /// DIFFERENCE FROM DART: Uses Swift `URL` instead of Dart `Uri`.
  /// REASON: Swift's `URL` (from Foundation) is the idiomatic equivalent of Dart's `Uri`.
  public let linkUrl: URL?

  /// A enum to describe what role the subtree represents.
  ///
  /// Setting the role for a widget subtree helps assistive technologies, such
  /// as screen readers, to understand and interact with the UI correctly.
  ///
  /// Defaults to `SemanticsRole.none` if not set, which means the subtree does
  /// not represent any complex UI or controls.
  ///
  /// For a list of available roles, see `SemanticsRole`.
  ///
  /// **Dart Source:** `semantics.dart:2398-2409`
  public let role: SemanticsRole?

  /// The `SemanticsNode.identifier`s of widgets controlled by this subtree.
  ///
  /// If a widget is controlling the visibility or content of another widget,
  /// for example, `Tab`s control child visibilities of `TabBarView` or
  /// `ExpansionTile` controls visibility of its expanded content, one must
  /// assign a `SemanticsNode.identifier` to the content and also provide a set
  /// of identifiers including the content's identifier to this property.
  ///
  /// **Dart Source:** `semantics.dart:2411-2420`
  public let controlsNodes: Set<String>?

  /// Describes the validation result for a form field represented by this
  /// widget.
  ///
  /// Providing a validation result helps assistive technologies, such as screen
  /// readers, to communicate to the user whether they provided correct
  /// information in a form.
  ///
  /// Defaults to `SemanticsValidationResult.none` if not set, which means no
  /// validation information is available for the respective semantics node.
  ///
  /// **Dart Source:** `semantics.dart:2422-2435`
  public let validationResult: SemanticsValidationResult

  /// The input type for an editable widget.
  ///
  /// This property is only used when the subtree represents a text field.
  ///
  /// Assistive technologies use this property to provide better information to
  /// users. For example, screen reader reads out the input type of text field
  /// when focused.
  ///
  /// **Dart Source:** `semantics.dart:2437-2446`
  public let inputType: SemanticsInputType?

  // MARK: - Action Handler Properties

  /// The handler for `SemanticsAction.tap`.
  ///
  /// This is the semantic equivalent of a user briefly tapping the screen with
  /// the finger without moving it. For example, a button should implement this
  /// action.
  ///
  /// VoiceOver users on iOS and TalkBack users on Android *may* trigger this
  /// action by double-tapping the screen while an element is focused.
  ///
  /// **Dart Source:** `semantics.dart:2107-2120`
  public let onTap: VoidCallback?

  /// The handler for `SemanticsAction.longPress`.
  ///
  /// This is the semantic equivalent of a user pressing and holding the screen
  /// with the finger for a few seconds without moving it.
  ///
  /// VoiceOver users on iOS and TalkBack users on Android *may* trigger this
  /// action by double-tapping the screen without lifting the finger after the
  /// second tap.
  ///
  /// **Dart Source:** `semantics.dart:2122-2136`
  public let onLongPress: VoidCallback?

  /// The handler for `SemanticsAction.scrollLeft`.
  ///
  /// This is the semantic equivalent of a user moving their finger across the
  /// screen from right to left. It should be recognized by controls that are
  /// horizontally scrollable.
  ///
  /// VoiceOver users on iOS can trigger this action by swiping left with three
  /// fingers. TalkBack users on Android can trigger this action by swiping
  /// right and then left in one motion path. On Android, `onScrollUp` and
  /// `onScrollLeft` share the same gesture. Therefore, only one of them should
  /// be provided.
  ///
  /// **Dart Source:** `semantics.dart:2138-2149`
  public let onScrollLeft: VoidCallback?

  /// The handler for `SemanticsAction.scrollRight`.
  ///
  /// This is the semantic equivalent of a user moving their finger across the
  /// screen from left to right. It should be recognized by controls that are
  /// horizontally scrollable.
  ///
  /// VoiceOver users on iOS can trigger this action by swiping right with three
  /// fingers. TalkBack users on Android can trigger this action by swiping
  /// left and then right in one motion path. On Android, `onScrollDown` and
  /// `onScrollRight` share the same gesture. Therefore, only one of them should
  /// be provided.
  ///
  /// **Dart Source:** `semantics.dart:2151-2162`
  public let onScrollRight: VoidCallback?

  /// The handler for `SemanticsAction.scrollUp`.
  ///
  /// This is the semantic equivalent of a user moving their finger across the
  /// screen from bottom to top. It should be recognized by controls that are
  /// vertically scrollable.
  ///
  /// VoiceOver users on iOS can trigger this action by swiping up with three
  /// fingers. TalkBack users on Android can trigger this action by swiping
  /// right and then left in one motion path. On Android, `onScrollUp` and
  /// `onScrollLeft` share the same gesture. Therefore, only one of them should
  /// be provided.
  ///
  /// **Dart Source:** `semantics.dart:2164-2175`
  public let onScrollUp: VoidCallback?

  /// The handler for `SemanticsAction.scrollDown`.
  ///
  /// This is the semantic equivalent of a user moving their finger across the
  /// screen from top to bottom. It should be recognized by controls that are
  /// vertically scrollable.
  ///
  /// VoiceOver users on iOS can trigger this action by swiping down with three
  /// fingers. TalkBack users on Android can trigger this action by swiping
  /// left and then right in one motion path. On Android, `onScrollDown` and
  /// `onScrollRight` share the same gesture. Therefore, only one of them should
  /// be provided.
  ///
  /// **Dart Source:** `semantics.dart:2177-2188`
  public let onScrollDown: VoidCallback?

  /// The handler for `SemanticsAction.increase`.
  ///
  /// This is a request to increase the value represented by the widget. For
  /// example, this action might be recognized by a slider control.
  ///
  /// If a `value` is set, `increasedValue` must also be provided and
  /// `onIncrease` must ensure that `value` will be set to `increasedValue`.
  ///
  /// VoiceOver users on iOS can trigger this action by swiping up with one
  /// finger. TalkBack users on Android can trigger this action by pressing the
  /// volume up button.
  ///
  /// **Dart Source:** `semantics.dart:2190-2201`
  public let onIncrease: VoidCallback?

  /// The handler for `SemanticsAction.decrease`.
  ///
  /// This is a request to decrease the value represented by the widget. For
  /// example, this action might be recognized by a slider control.
  ///
  /// If a `value` is set, `decreasedValue` must also be provided and
  /// `onDecrease` must ensure that `value` will be set to `decreasedValue`.
  ///
  /// VoiceOver users on iOS can trigger this action by swiping down with one
  /// finger. TalkBack users on Android can trigger this action by pressing the
  /// volume down button.
  ///
  /// **Dart Source:** `semantics.dart:2203-2214`
  public let onDecrease: VoidCallback?

  /// The handler for `SemanticsAction.copy`.
  ///
  /// This is a request to copy the current selection to the clipboard.
  ///
  /// TalkBack users on Android can trigger this action from the local context
  /// menu of a text field, for example.
  ///
  /// **Dart Source:** `semantics.dart:2216-2222`
  public let onCopy: VoidCallback?

  /// The handler for `SemanticsAction.cut`.
  ///
  /// This is a request to cut the current selection and place it in the
  /// clipboard.
  ///
  /// TalkBack users on Android can trigger this action from the local context
  /// menu of a text field, for example.
  ///
  /// **Dart Source:** `semantics.dart:2224-2231`
  public let onCut: VoidCallback?

  /// The handler for `SemanticsAction.paste`.
  ///
  /// This is a request to paste the current content of the clipboard.
  ///
  /// TalkBack users on Android can trigger this action from the local context
  /// menu of a text field, for example.
  ///
  /// **Dart Source:** `semantics.dart:2233-2239`
  public let onPaste: VoidCallback?

  /// The handler for `SemanticsAction.moveCursorForwardByCharacter`.
  ///
  /// This handler is invoked when the user wants to move the cursor in a
  /// text field forward by one character.
  ///
  /// TalkBack users can trigger this by pressing the volume up key while the
  /// input focus is in a text field.
  ///
  /// **Dart Source:** `semantics.dart:2241-2248`
  public let onMoveCursorForwardByCharacter: MoveCursorHandler?

  /// The handler for `SemanticsAction.moveCursorBackwardByCharacter`.
  ///
  /// This handler is invoked when the user wants to move the cursor in a
  /// text field backward by one character.
  ///
  /// TalkBack users can trigger this by pressing the volume down key while the
  /// input focus is in a text field.
  ///
  /// **Dart Source:** `semantics.dart:2250-2257`
  public let onMoveCursorBackwardByCharacter: MoveCursorHandler?

  /// The handler for `SemanticsAction.moveCursorForwardByWord`.
  ///
  /// This handler is invoked when the user wants to move the cursor in a
  /// text field forward by one word.
  ///
  /// TalkBack users can trigger this by pressing the volume up key while the
  /// input focus is in a text field.
  ///
  /// **Dart Source:** `semantics.dart:2259-2266`
  public let onMoveCursorForwardByWord: MoveCursorHandler?

  /// The handler for `SemanticsAction.moveCursorBackwardByWord`.
  ///
  /// This handler is invoked when the user wants to move the cursor in a
  /// text field backward by one word.
  ///
  /// TalkBack users can trigger this by pressing the volume down key while the
  /// input focus is in a text field.
  ///
  /// **Dart Source:** `semantics.dart:2268-2275`
  public let onMoveCursorBackwardByWord: MoveCursorHandler?

  /// The handler for `SemanticsAction.setSelection`.
  ///
  /// This handler is invoked when the user either wants to change the currently
  /// selected text in a text field or change the position of the cursor.
  ///
  /// TalkBack users can trigger this handler by selecting "Move cursor to
  /// beginning/end" or "Select all" from the local context menu.
  ///
  /// **Dart Source:** `semantics.dart:2277-2284`
  public let onSetSelection: SetSelectionHandler?

  /// The handler for `SemanticsAction.setText`.
  ///
  /// This handler is invoked when the user wants to replace the current text in
  /// the text field with a new text.
  ///
  /// Voice access users can trigger this handler by speaking `type <text>` to
  /// their Android devices.
  ///
  /// **Dart Source:** `semantics.dart:2286-2293`
  public let onSetText: SetTextHandler?

  /// The handler for `SemanticsAction.didGainAccessibilityFocus`.
  ///
  /// This handler is invoked when the node annotated with this handler gains
  /// the accessibility focus. The accessibility focus is the
  /// green (on Android with TalkBack) or black (on iOS with VoiceOver)
  /// rectangle shown on screen to indicate what element an accessibility
  /// user is currently interacting with.
  ///
  /// The accessibility focus is different from the input focus. The input focus
  /// is usually held by the element that currently responds to keyboard inputs.
  /// Accessibility focus and input focus can be held by two different nodes!
  ///
  /// **Dart Source:** `semantics.dart:2295-2314`
  public let onDidGainAccessibilityFocus: VoidCallback?

  /// The handler for `SemanticsAction.didLoseAccessibilityFocus`.
  ///
  /// This handler is invoked when the node annotated with this handler
  /// loses the accessibility focus. The accessibility focus is
  /// the green (on Android with TalkBack) or black (on iOS with VoiceOver)
  /// rectangle shown on screen to indicate what element an accessibility
  /// user is currently interacting with.
  ///
  /// The accessibility focus is different from the input focus. The input focus
  /// is usually held by the element that currently responds to keyboard inputs.
  /// Accessibility focus and input focus can be held by two different nodes!
  ///
  /// **Dart Source:** `semantics.dart:2316-2333`
  public let onDidLoseAccessibilityFocus: VoidCallback?

  /// The handler for `SemanticsAction.focus`.
  ///
  /// This handler is invoked when the assistive technology requests that the
  /// focusable widget corresponding to this semantics node gain input focus.
  /// The `FocusNode` that manages the focus of the widget must gain focus. The
  /// widget must begin responding to relevant key events.
  ///
  /// Focus behavior is specific to the platform and to the assistive technology
  /// used. See the documentation of `SemanticsAction.focus` for more detail.
  ///
  /// **Dart Source:** `semantics.dart:2335-2357`
  public let onFocus: VoidCallback?

  /// The handler for `SemanticsAction.dismiss`.
  ///
  /// This is a request to dismiss the currently focused node.
  ///
  /// TalkBack users on Android can trigger this action in the local context
  /// menu, and VoiceOver users on iOS can trigger this action with a standard
  /// gesture or menu option.
  ///
  /// **Dart Source:** `semantics.dart:2359-2366`
  public let onDismiss: VoidCallback?

  /// The handler for `SemanticsAction.expand`.
  ///
  /// This is a request to expand the currently focused node. For example, this
  /// action might be recognized by a dropdown.
  ///
  /// This handler should only be set when the node is in a collapsed state
  /// (i.e., `expanded` is false).
  ///
  /// **Dart Source:** `semantics.dart:2368-2375`
  public let onExpand: VoidCallback?

  /// The handler for `SemanticsAction.collapse`.
  ///
  /// This is a request to collapse the currently focused node. For example,
  /// this action might be recognized by a dropdown.
  ///
  /// This handler should only be set when the node is in an expanded state
  /// (i.e., `expanded` is true).
  ///
  /// **Dart Source:** `semantics.dart:2377-2384`
  public let onCollapse: VoidCallback?

  /// A map from each supported `CustomSemanticsAction` to a provided handler.
  ///
  /// The handler associated with each custom action is called whenever a
  /// semantics action of type `SemanticsAction.customAction` is received. The
  /// provided argument will be an identifier used to retrieve an instance of
  /// a custom action which can then retrieve the correct handler from this map.
  ///
  /// **Dart Source:** `semantics.dart:2386-2396`
  public let customSemanticsActions: [CustomSemanticsAction: VoidCallback]?

  // MARK: - Debug

  /// Add additional properties associated with the node for debugging.
  ///
  /// **Dart Source:** `semantics.dart:2449-2501`
  /// **Original:** `void debugFillProperties(DiagnosticPropertiesBuilder properties)`
  ///
  /// DIFFERENCE FROM DART: This is a regular method instead of an override of
  /// `DiagnosticableTree.debugFillProperties`, because `SemanticsProperties` is a struct
  /// and cannot conform to the `Diagnosticable` protocol (which requires `AnyObject`).
  /// REASON: Swift structs cannot conform to class-constrained protocols.
  public func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
    properties.add(DiagnosticsProperty<Bool>("checked", checked, defaultValue: nil))
    properties.add(DiagnosticsProperty<Bool>("mixed", mixed, defaultValue: nil))
    properties.add(DiagnosticsProperty<Bool>("expanded", expanded, defaultValue: nil))
    properties.add(DiagnosticsProperty<Bool>("selected", selected, defaultValue: nil))
    properties.add(DiagnosticsProperty<Bool>("isRequired", isRequired, defaultValue: nil))
    properties.add(StringProperty("identifier", identifier, defaultValue: nil))
    properties.add(StringProperty("label", label, defaultValue: nil))
    properties.add(
      AttributedStringProperty("attributedLabel", attributedLabel, defaultValue: nil)
    )
    properties.add(StringProperty("value", value, defaultValue: nil))
    properties.add(
      AttributedStringProperty("attributedValue", attributedValue, defaultValue: nil)
    )
    properties.add(StringProperty("increasedValue", increasedValue, defaultValue: nil))
    properties.add(
      AttributedStringProperty(
        "attributedIncreasedValue",
        attributedIncreasedValue,
        defaultValue: nil
      )
    )
    properties.add(StringProperty("decreasedValue", decreasedValue, defaultValue: nil))
    properties.add(
      AttributedStringProperty(
        "attributedDecreasedValue",
        attributedDecreasedValue,
        defaultValue: nil
      )
    )
    properties.add(StringProperty("hint", hint, defaultValue: nil))
    properties.add(
      AttributedStringProperty("attributedHint", attributedHint, defaultValue: nil)
    )
    properties.add(StringProperty("tooltip", tooltip, defaultValue: nil))
    properties.add(
      DiagnosticsProperty<TextDirection>("textDirection", textDirection, defaultValue: nil)
    )
    properties.add(DiagnosticsProperty<SemanticsRole>("role", role, defaultValue: nil))
    properties.add(
      DiagnosticsProperty<SemanticsValidationResult>(
        "validationResult",
        validationResult,
        defaultValue: SemanticsValidationResult.none
      )
    )
    properties.add(
      DiagnosticsProperty<SemanticsSortKey>("sortKey", sortKey, defaultValue: nil)
    )
    properties.add(
      DiagnosticsProperty<SemanticsHintOverrides>(
        "hintOverrides",
        hintOverrides,
        defaultValue: nil
      )
    )
  }

  /// Returns a short string representation.
  ///
  /// **Dart Source:** `semantics.dart:2504`
  /// **Original:** `String toStringShort() => objectRuntimeType(this, 'SemanticsProperties');`
  public func toStringShort() -> String {
    "SemanticsProperties"
  }
}
