// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Debug role validation checks and utility functions for semantics.
///
/// **Dart Source:** `packages/flutter/lib/src/semantics/semantics.dart`

import FlutterSwiftBridge

// MARK: - DebugSemanticsRoleChecks

/// Debug-only role validation system that validates which semantics
/// flags/actions are valid for each `SemanticsRole`.
///
/// **Dart Source:** `semantics.dart:122-495`
/// **Original Name:** `_DebugSemanticsRoleChecks`
///
/// DIFFERENCE FROM DART: Using a caseless enum namespace instead of a sealed class.
/// REASON: Swift uses caseless enums as namespaces for grouping static methods,
/// which is the idiomatic equivalent of Dart's sealed class used as a namespace.
///
/// DIFFERENCE FROM DART: Role validation checks are stubbed with a TODO.
/// REASON: The full implementation depends on `SemanticsNode` and
/// `SemanticsConfiguration` which are not yet fully migrated. The method
/// signature is preserved for when those types become available.
enum DebugSemanticsRoleChecks {
  /// Validates that the semantics data for the given role is correct.
  ///
  /// Returns `true` if the role checks pass. Currently always returns `true`
  /// as a stub until `SemanticsNode` and `SemanticsConfiguration` are fully migrated.
  ///
  /// **Dart Source:** `semantics.dart:123-167`
  /// **Original Name:** `_checkSemanticsData`
  ///
  /// In Dart, this method takes a `SemanticsNode`, inspects its role, and
  /// dispatches to the appropriate role-specific validation method. Each
  /// role-specific method checks that the node's flags and actions are
  /// consistent with that role.
  ///
  /// The roles and their validation methods are:
  /// - `alertDialog`, `dialog`, `none`, `tabPanel`, `list`, `form`: no check required
  /// - `tab`: must have selected state; if enabled, must have tap action
  /// - `tabBar`: must have children, all must have tab role
  /// - `table`: children must have row role
  /// - `cell`: must be child of row or another cell
  /// - `row`: must be child of table; children must be cell or columnHeader
  /// - `columnHeader`: must be child of row or cell
  /// - `radioGroup`: validates mutually exclusive children
  /// - `menu`: must not be empty
  /// - `menuBar`: must not be empty
  /// - `menuItem`: must be descendant of menu or menuBar
  /// - `menuItemCheckbox`: must be checkable and descendant of menu/menuBar
  /// - `menuItemRadio`: must be checkable and descendant of menu/menuBar
  /// - `alert`, `status`: must not be live region
  /// - `listItem`: must have parent with list role
  /// - `complementary`, `contentInfo`, `main`: landmark checks
  /// - `navigation`: landmark duplicate label check
  /// - `region`: must have a label
  /// - `dragHandle`, `spinButton`, `comboBox`, `tooltip`, `loadingSpinner`,
  ///   `progressBar`, `hotKey`: unimplemented (TODO in Dart)
  /// - General: expand/collapse action consistency
  // TODO: Implement role validation checks when SemanticsNode and SemanticsConfiguration are fully migrated.
  // See Dart source semantics.dart:122-495 for the full validation logic.
  static func checkSemanticsData(role: SemanticsRole) -> Bool {
    return true
  }
}

// MARK: - _concatAttributedString

/// Concatenates two `AttributedString` values with a newline separator,
/// respecting text direction.
///
/// If `otherAttributedString` is empty, returns `thisAttributedString`.
/// If the text directions differ, wraps `otherAttributedString` in the
/// appropriate Unicode directional embedding characters (LRE/RLE + PDF).
/// If `thisAttributedString` is empty, returns the (possibly wrapped)
/// `otherAttributedString`.
/// Otherwise, returns the two strings joined by a newline.
///
/// **Dart Source:** `semantics.dart:6212-6234`
/// **Original Name:** `_concatAttributedString`
///
/// DIFFERENCE FROM DART: Uses named parameters via a Swift-style function signature.
/// REASON: Swift does not have Dart's `required` keyword syntax; we use labeled parameters instead.
func concatAttributedString(
  thisAttributedString: AttributedString,
  otherAttributedString: AttributedString,
  thisTextDirection: TextDirection?,
  otherTextDirection: TextDirection?
) -> AttributedString {
  if otherAttributedString.string.isEmpty {
    return thisAttributedString
  }

  var other = otherAttributedString
  if thisTextDirection != otherTextDirection, let otherDir = otherTextDirection {
    let directionEmbedding: AttributedString
    switch otherDir {
    case .rtl:
      directionEmbedding = AttributedString(UnicodeConstants.RLE)
    case .ltr:
      directionEmbedding = AttributedString(UnicodeConstants.LRE)
    }
    other = directionEmbedding + other + AttributedString(UnicodeConstants.PDF)
  }

  if thisAttributedString.string.isEmpty {
    return other
  }

  return thisAttributedString + AttributedString("\n") + other
}

// MARK: - _mergeHeadingLevels

/// Merges heading levels when two semantics nodes with different heading
/// levels are merged.
///
/// If the target node (`targetLevel`) is not a heading (level 0), the source
/// heading level is used. Otherwise, the target heading level is used
/// irrespective of the source heading level.
///
/// **Dart Source:** `semantics.dart:6368-6370`
/// **Original Name:** `_mergeHeadingLevels`
func mergeHeadingLevels(sourceLevel: Int, targetLevel: Int) -> Int {
  return targetLevel == 0 ? sourceLevel : targetLevel
}

// MARK: - _tristateFromBoolOrNull

/// Converts an optional `Bool` to a `Tristate` value.
///
/// - `nil` maps to `.none` (property not applicable)
/// - `true` maps to `.isTrue`
/// - `false` maps to `.isFalse`
///
/// **Dart Source:** `semantics.dart:6372-6381`
/// **Original Name:** `_tristateFromBoolOrNull`
func tristateFromBoolOrNull(_ value: Bool?) -> Tristate {
  guard let value = value else {
    return .none
  }
  if value {
    return .isTrue
  }
  return .isFalse
}

// MARK: - _toBitMask

/// Converts a `SemanticsFlags` instance to a legacy integer bitmask.
///
/// This is for backward compatibility with the legacy bitmask-based semantics
/// flag system. It supports flags 0-30; new flags do not need to be in the
/// bitmask.
///
/// The bitmask layout is:
/// - Bit 0: `isChecked != .none` (has checked state)
/// - Bit 1: `isChecked == .isTrue`
/// - Bit 2: `isSelected == .isTrue`
/// - Bit 3: `isButton`
/// - Bit 4: `isTextField`
/// - Bit 5: `isFocused == .isTrue`
/// - Bit 6: `isEnabled != .none` (has enabled state)
/// - Bit 7: `isEnabled == .isTrue`
/// - Bit 8: `isInMutuallyExclusiveGroup`
/// - Bit 9: `isHeader`
/// - Bit 10: `isObscured`
/// - Bit 11: `scopesRoute`
/// - Bit 12: `namesRoute`
/// - Bit 13: `isHidden`
/// - Bit 14: `isImage`
/// - Bit 15: `isLiveRegion`
/// - Bit 16: `isToggled != .none` (has toggled state)
/// - Bit 17: `isToggled == .isTrue`
/// - Bit 18: `hasImplicitScrolling`
/// - Bit 19: `isMultiline`
/// - Bit 20: `isReadOnly`
/// - Bit 21: `isFocused != .none` (has focused state)
/// - Bit 22: `isLink`
/// - Bit 23: `isSlider`
/// - Bit 24: `isKeyboardKey`
/// - Bit 25: `isChecked == .mixed`
/// - Bit 26: `isExpanded != .none` (has expanded state)
/// - Bit 27: `isExpanded == .isTrue`
/// - Bit 28: `isSelected != .none` (has selected state)
/// - Bit 29: `isRequired != .none` (has required state)
/// - Bit 30: `isRequired == .isTrue`
///
/// **Dart Source:** `semantics.dart:6384-6480`
/// **Original Name:** `_toBitMask`
func toBitMask(_ flags: SemanticsFlags) -> Int {
  var bitmask = 0
  if flags.isChecked != .none {
    bitmask |= 1 << 0
  }
  if flags.isChecked == .isTrue {
    bitmask |= 1 << 1
  }
  if flags.isSelected == .isTrue {
    bitmask |= 1 << 2
  }
  if flags.isButton {
    bitmask |= 1 << 3
  }
  if flags.isTextField {
    bitmask |= 1 << 4
  }
  if flags.isFocused == .isTrue {
    bitmask |= 1 << 5
  }
  if flags.isEnabled != .none {
    bitmask |= 1 << 6
  }
  if flags.isEnabled == .isTrue {
    bitmask |= 1 << 7
  }
  if flags.isInMutuallyExclusiveGroup {
    bitmask |= 1 << 8
  }
  if flags.isHeader {
    bitmask |= 1 << 9
  }
  if flags.isObscured {
    bitmask |= 1 << 10
  }
  if flags.scopesRoute {
    bitmask |= 1 << 11
  }
  if flags.namesRoute {
    bitmask |= 1 << 12
  }
  if flags.isHidden {
    bitmask |= 1 << 13
  }
  if flags.isImage {
    bitmask |= 1 << 14
  }
  if flags.isLiveRegion {
    bitmask |= 1 << 15
  }
  if flags.isToggled != .none {
    bitmask |= 1 << 16
  }
  if flags.isToggled == .isTrue {
    bitmask |= 1 << 17
  }
  if flags.hasImplicitScrolling {
    bitmask |= 1 << 18
  }
  if flags.isMultiline {
    bitmask |= 1 << 19
  }
  if flags.isReadOnly {
    bitmask |= 1 << 20
  }
  if flags.isFocused != .none {
    bitmask |= 1 << 21
  }
  if flags.isLink {
    bitmask |= 1 << 22
  }
  if flags.isSlider {
    bitmask |= 1 << 23
  }
  if flags.isKeyboardKey {
    bitmask |= 1 << 24
  }
  if flags.isChecked == .mixed {
    bitmask |= 1 << 25
  }
  if flags.isExpanded != .none {
    bitmask |= 1 << 26
  }
  if flags.isExpanded == .isTrue {
    bitmask |= 1 << 27
  }
  if flags.isSelected != .none {
    bitmask |= 1 << 28
  }
  if flags.isRequired != .none {
    bitmask |= 1 << 29
  }
  if flags.isRequired == .isTrue {
    bitmask |= 1 << 30
  }
  return bitmask
}
