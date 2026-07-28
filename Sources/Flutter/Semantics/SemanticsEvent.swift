// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

/// Semantics event types for accessibility announcements and notifications.
///
/// **Dart Source:** `packages/flutter/lib/src/semantics/semantics_event.dart`

// MARK: - Assertiveness

/// Determines the assertiveness level of the accessibility announcement.
///
/// It is used by `AnnounceSemanticsEvent` to determine the priority with which
/// assistive technology should treat announcements.
///
/// **Dart Source:** `semantics_event.dart:18-27`
/// **Original Name:** `Assertiveness`
// DIFFERENCE FROM DART: Uses `Int` raw value (polite=0, assertive=1) for C++ interop.
// REASON: Swift enums with raw values enable easy bridging and serialization.
public enum Assertiveness: Int, Sendable {
  /// The assistive technology will speak changes whenever the user is idle.
  ///
  /// **Dart Source:** `semantics_event.dart:20`
  case polite = 0

  /// The assistive technology will interrupt any announcement that it is
  /// currently making to notify the user about the change.
  ///
  /// It should only be used for time-sensitive/critical notifications.
  ///
  /// **Dart Source:** `semantics_event.dart:26`
  case assertive = 1
}

// MARK: - SemanticsEvent

/// An event sent by the application to notify interested listeners that
/// something happened to the user interface (e.g. a view scrolled).
///
/// These events are usually interpreted by assistive technologies to give the
/// user additional clues about the current state of the UI.
///
/// **Dart Source:** `semantics_event.dart:34-74`
/// **Original Name:** `SemanticsEvent`
///
// DIFFERENCE FROM DART: Abstract class converted to protocol with default
// implementations in an extension.
// REASON: Swift does not have abstract classes; protocol + extension provides
// equivalent functionality.
public protocol SemanticsEvent: CustomStringConvertible {
  /// The type of this event.
  ///
  /// The type is used by the engine to translate this event into the
  /// appropriate native event (`UIAccessibility*Notification` on iOS and
  /// `AccessibilityEvent` on Android).
  ///
  /// **Dart Source:** `semantics_event.dart:45`
  var type: String { get }

  /// Returns the event's data object.
  ///
  /// **Dart Source:** `semantics_event.dart:62`
  func getDataMap() -> [String: Any]
}

// MARK: - SemanticsEvent Default Implementations

extension SemanticsEvent {
  /// Converts this event to a Map that can be encoded with
  /// `StandardMessageCodec`.
  ///
  /// `nodeId` is the unique identifier of the semantics node associated with
  /// the event, or `nil` if the event is not associated with a semantics node.
  ///
  /// **Dart Source:** `semantics_event.dart:52-59`
  public func toMap(nodeId: Int? = nil) -> [String: Any] {
    var event: [String: Any] = ["type": type, "data": getDataMap()]
    if let nodeId {
      event["nodeId"] = nodeId
    }
    return event
  }

  /// A textual description of this event, including its type and data.
  ///
  /// **Dart Source:** `semantics_event.dart:64-73`
  // DIFFERENCE FROM DART: Uses Swift's `CustomStringConvertible` protocol
  // conformance instead of overriding `toString()`.
  // REASON: Swift convention for string representation is `description` via
  // `CustomStringConvertible`, not a `toString()` method.
  public var description: String {
    let dataMap = getDataMap()
    let sortedKeys = dataMap.keys.sorted()
    let pairs = sortedKeys.map { key in
      "\(key): \(dataMap[key]!)"
    }
    return "\(objectRuntimeType(self, "SemanticsEvent"))(\(pairs.joined(separator: ", ")))"
  }
}

// MARK: - AnnounceSemanticsEvent

/// An event for a semantic announcement.
///
/// This should be used for announcement that are not seamlessly announced by
/// the system as a result of a UI state change.
///
/// For example a camera application can use this method to make accessibility
/// announcements regarding objects in the viewfinder.
///
/// When possible, prefer using mechanisms like `Semantics` to implicitly
/// trigger announcements over using this event.
///
/// **Dart Source:** `semantics_event.dart:76-131`
/// **Original Name:** `AnnounceSemanticsEvent`
public struct AnnounceSemanticsEvent: SemanticsEvent, Sendable {
  /// **Dart Source:** `semantics_event.dart:95`
  public let type: String = "announce"

  /// The view that this announcement is on.
  ///
  /// **Dart Source:** `semantics_event.dart:106`
  public let viewId: Int

  /// The message to announce.
  ///
  /// **Dart Source:** `semantics_event.dart:109`
  public let message: String

  /// Text direction for `message`.
  ///
  /// **Dart Source:** `semantics_event.dart:112`
  public let textDirection: TextDirection

  /// Determines whether the announcement should interrupt any existing
  /// announcement, or queue after it.
  ///
  /// On the web this option uses the aria-live level to set the assertiveness
  /// of the announcement. On iOS, Android, Windows, Linux, macOS, and Fuchsia
  /// this option currently has no effect.
  ///
  /// **Dart Source:** `semantics_event.dart:120`
  public let assertiveness: Assertiveness

  /// Constructs an event that triggers an announcement by the platform
  /// for the provided view.
  ///
  /// **Dart Source:** `semantics_event.dart:98-103`
  public init(
    _ message: String,
    _ textDirection: TextDirection,
    _ viewId: Int,
    assertiveness: Assertiveness = .polite
  ) {
    self.message = message
    self.textDirection = textDirection
    self.viewId = viewId
    self.assertiveness = assertiveness
  }

  /// **Dart Source:** `semantics_event.dart:122-130`
  public func getDataMap() -> [String: Any] {
    var map: [String: Any] = [
      "viewId": viewId,
      "message": message,
      "textDirection": textDirection.rawValue,
    ]
    if assertiveness != .polite {
      map["assertiveness"] = assertiveness.rawValue
    }
    return map
  }
}

// MARK: - TooltipSemanticsEvent

/// An event for a semantic announcement of a tooltip.
///
/// This is only used by Android to announce tooltip values.
///
/// **Dart Source:** `semantics_event.dart:133-147`
/// **Original Name:** `TooltipSemanticsEvent`
public struct TooltipSemanticsEvent: SemanticsEvent, Sendable {
  /// **Dart Source:** `semantics_event.dart:136`
  public let type: String = "tooltip"

  /// The text content of the tooltip.
  ///
  /// **Dart Source:** `semantics_event.dart:140`
  public let message: String

  /// Constructs an event that triggers a tooltip announcement by the platform.
  ///
  /// **Dart Source:** `semantics_event.dart:138`
  public init(_ message: String) {
    self.message = message
  }

  /// **Dart Source:** `semantics_event.dart:143-146`
  public func getDataMap() -> [String: Any] {
    return ["message": message]
  }
}

// MARK: - LongPressSemanticsEvent

/// An event which triggers long press semantic feedback.
///
/// Currently only honored on Android. Triggers a long-press specific sound
/// when TalkBack is enabled.
///
/// **Dart Source:** `semantics_event.dart:149-159`
/// **Original Name:** `LongPressSemanticsEvent`
public struct LongPressSemanticsEvent: SemanticsEvent, Sendable {
  /// **Dart Source:** `semantics_event.dart:153`
  public let type: String = "longPress"

  /// Constructs an event that triggers a long-press semantic feedback by the
  /// platform.
  ///
  /// **Dart Source:** `semantics_event.dart:155`
  public init() {}

  /// **Dart Source:** `semantics_event.dart:157-158`
  public func getDataMap() -> [String: Any] {
    return [:]
  }
}

// MARK: - TapSemanticEvent

/// An event which triggers tap semantic feedback.
///
/// Currently only honored on Android. Triggers a tap specific sound when
/// TalkBack is enabled.
///
/// **Dart Source:** `semantics_event.dart:161-171`
/// **Original Name:** `TapSemanticEvent`
// DIFFERENCE FROM DART: Name preserved as `TapSemanticEvent` (no 's' in Semantic)
// to match the original Dart naming inconsistency.
// REASON: Maintaining exact parity with Dart API naming.
public struct TapSemanticEvent: SemanticsEvent, Sendable {
  /// **Dart Source:** `semantics_event.dart:165`
  public let type: String = "tap"

  /// Constructs an event that triggers a tap semantic feedback by the platform.
  ///
  /// **Dart Source:** `semantics_event.dart:167`
  public init() {}

  /// **Dart Source:** `semantics_event.dart:169-170`
  public func getDataMap() -> [String: Any] {
    return [:]
  }
}

// MARK: - FocusSemanticEvent

/// An event to move the accessibility focus.
///
/// Using this API is generally not recommended, as it may break a users'
/// expectation of how a11y focus works and therefore should be used very
/// carefully.
///
/// This currently only supports Android and iOS.
///
/// **Dart Source:** `semantics_event.dart:173-238`
/// **Original Name:** `FocusSemanticEvent`
public struct FocusSemanticEvent: SemanticsEvent, Sendable {
  /// **Dart Source:** `semantics_event.dart:232`
  public let type: String = "focus"

  /// Constructs an event that triggers a focus change by the platform.
  ///
  /// **Dart Source:** `semantics_event.dart:234`
  public init() {}

  /// **Dart Source:** `semantics_event.dart:236-237`
  public func getDataMap() -> [String: Any] {
    return [:]
  }
}
