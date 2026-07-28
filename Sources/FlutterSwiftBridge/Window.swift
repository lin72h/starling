// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Swift implementation of window.dart types from Flutter's dart:ui library.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/window.dart`
///
/// This file contains the Swift implementations of:
/// - FlutterView: A view into which a Flutter Scene is drawn
/// - Display: A configurable display that a FlutterView renders on
/// - Brightness: Describes the contrast of a theme or color palette
/// - GestureSettings: Platform specific configuration for gesture behavior
/// - AccessibilityFeatures: Additional accessibility features enabled by the platform

import FlutterSwiftBridgeCxx

// MARK: - FlutterView

/// A view into which a Flutter [Scene] is drawn.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/window.dart:41-405`
/// **Original Name:** `FlutterView`
///
/// Each [FlutterView] has its own layer tree that is rendered
/// whenever [render] is called on it with a [Scene].
///
/// References to [FlutterView] objects are obtained via the [PlatformDispatcher].
///
/// ## Insets and Padding
///
/// The [viewInsets] are the physical pixels which the operating
/// system reserves for system UI, such as the keyboard, which would fully
/// obscure any content drawn in that area.
///
/// The [viewPadding] are the physical pixels on each side of the
/// display that may be partially obscured by system UI or by physical
/// intrusions into the display, such as an overscan region on a television or a
/// "notch" on a phone.
///
/// The [padding] property is computed from both [viewInsets] and [viewPadding].
/// It will allow a view inset to consume view padding where appropriate.
public class FlutterView: CustomStringConvertible {
  /// The opaque ID for this view.
  ///
  /// **Dart Source:** `window.dart:94-95`
  /// **Original:** `final int viewId;`
  public let viewId: Int

  /// The platform dispatcher that this view is registered with, and gets its
  /// information from.
  ///
  /// **Dart Source:** `window.dart:97-99`
  /// **Original:** `final PlatformDispatcher platformDispatcher;`
  public unowned let platformDispatcher: PlatformDispatcher

  /// The configuration of this view.
  ///
  /// **Dart Source:** `window.dart:101-102`
  /// **Original:** `_ViewConfiguration _viewConfiguration;`
  ///
  /// DIFFERENCE FROM DART: Named `viewConfiguration` (no underscore prefix).
  /// REASON: Swift uses `internal` access control instead of underscore prefix.
  internal var viewConfiguration: ViewConfiguration

  /// Creates a FlutterView.
  ///
  /// **Dart Source:** `window.dart:92`
  /// **Original:** `FlutterView._(this.viewId, this.platformDispatcher, this._viewConfiguration);`
  ///
  /// DIFFERENCE FROM DART: Uses internal access instead of private constructor (FlutterView._).
  /// REASON: Swift doesn't have named private constructors. Using internal provides
  /// the same encapsulation (framework-internal construction only).
  internal init(
    viewId: Int,
    platformDispatcher: PlatformDispatcher,
    viewConfiguration: ViewConfiguration
  ) {
    self.viewId = viewId
    self.platformDispatcher = platformDispatcher
    self.viewConfiguration = viewConfiguration
  }

  /// The [Display] this view is drawn in.
  ///
  /// **Dart Source:** `window.dart:104-108`
  /// **Original:**
  /// ```dart
  /// Display get display {
  ///   assert(platformDispatcher._displays.containsKey(_viewConfiguration.displayId));
  ///   return platformDispatcher._displays[_viewConfiguration.displayId]!;
  /// }
  /// ```
  public var display: Display {
    guard let display = platformDispatcher._display(id: viewConfiguration.displayId) else {
      fatalError(
        "Display \(viewConfiguration.displayId) not found in platformDispatcher._displays")
    }
    return display
  }

  /// The number of device pixels for each logical pixel for the screen this
  /// view is displayed on.
  ///
  /// **Dart Source:** `window.dart:110-142`
  /// **Original:** `double get devicePixelRatio => _viewConfiguration.devicePixelRatio;`
  ///
  /// This number might not be a power of two. Indeed, it might not even be an
  /// integer. For example, the Nexus 6 has a device pixel ratio of 3.5.
  ///
  /// Device pixels are also referred to as physical pixels. Logical pixels are
  /// also referred to as device-independent or resolution-independent pixels.
  ///
  /// By definition, there are roughly 38 logical pixels per centimeter, or
  /// about 96 logical pixels per inch, of the physical display. The value
  /// returned by [devicePixelRatio] is ultimately obtained either from the
  /// hardware itself, the device drivers, or a hard-coded value stored in the
  /// operating system or firmware, and may be inaccurate, sometimes by a
  /// significant margin.
  ///
  /// The Flutter framework operates in logical pixels, so it is rarely
  /// necessary to directly deal with this property.
  ///
  /// When this changes, [PlatformDispatcher.onMetricsChanged] is called.
  public var devicePixelRatio: Double {
    viewConfiguration.devicePixelRatio
  }

  /// The sizing constraints in physical pixels for this view.
  ///
  /// **Dart Source:** `window.dart:144-167`
  /// **Original:** `ViewConstraints get physicalConstraints => _viewConfiguration.viewConstraints;`
  ///
  /// The view can take on any [Size] that fulfills these constraints. These
  /// constraints are typically used by a UI framework as the input for its
  /// layout algorithm to determine an appropriate size for the view.
  ///
  /// When this changes, [PlatformDispatcher.onMetricsChanged] is called.
  public var physicalConstraints: ViewConstraints {
    viewConfiguration.viewConstraints
  }

  /// The current dimensions of the rectangle as last reported by the platform
  /// into which scenes rendered in this view are drawn.
  ///
  /// **Dart Source:** `window.dart:169-197`
  /// **Original:** `Size get physicalSize => _viewConfiguration.size;`
  ///
  /// If the view is configured with loose [physicalConstraints] this value
  /// may be outdated by a few frames as it only updates when the size chosen
  /// for a frame (as provided to the [render] method) is processed by the
  /// platform.
  ///
  /// At startup, the size of the view may not be known before Dart code runs.
  /// If this value is observed early in the application lifecycle, it may
  /// report [Size.zero].
  ///
  /// When this changes, [PlatformDispatcher.onMetricsChanged] is called.
  public var physicalSize: Size {
    viewConfiguration.size
  }

  /// The number of physical pixels on each side of the display rectangle into
  /// which the view can render, but over which the operating system will likely
  /// place system UI, such as the keyboard, that fully obscures any content.
  ///
  /// **Dart Source:** `window.dart:199-221`
  /// **Original:** `ViewPadding get viewInsets => _viewConfiguration.viewInsets;`
  ///
  /// When this property changes, [PlatformDispatcher.onMetricsChanged] is called.
  public var viewInsets: ViewPadding {
    viewConfiguration.viewInsets
  }

  /// The number of physical pixels on each side of the display rectangle into
  /// which the view can render, but which may be partially obscured by system
  /// UI (such as the system notification area), or physical intrusions in
  /// the display (e.g. overscan regions on television screens or phone sensor
  /// housings).
  ///
  /// **Dart Source:** `window.dart:223-252`
  /// **Original:** `ViewPadding get viewPadding => _viewConfiguration.viewPadding;`
  ///
  /// Unlike [padding], this value does not change relative to
  /// [viewInsets]. For example, on an iPhone X, it will not
  /// change in response to the soft keyboard being visible or hidden.
  ///
  /// When this property changes, [PlatformDispatcher.onMetricsChanged] is called.
  public var viewPadding: ViewPadding {
    viewConfiguration.viewPadding
  }

  /// The number of physical pixels on each side of the display rectangle into
  /// which the view can render, but where the operating system will consume
  /// input gestures for the sake of system navigation.
  ///
  /// **Dart Source:** `window.dart:254-269`
  /// **Original:** `ViewPadding get systemGestureInsets => _viewConfiguration.systemGestureInsets;`
  ///
  /// For example, an operating system might use the vertical edges of the
  /// screen, where swiping inwards from the edges takes users backward
  /// through the history of screens they previously visited.
  ///
  /// When this property changes, [PlatformDispatcher.onMetricsChanged] is called.
  public var systemGestureInsets: ViewPadding {
    viewConfiguration.systemGestureInsets
  }

  /// The number of physical pixels on each side of the display rectangle into
  /// which the view can render, but which may be partially obscured by system
  /// UI (such as the system notification area), or physical intrusions in
  /// the display.
  ///
  /// **Dart Source:** `window.dart:271-302`
  /// **Original:** `ViewPadding get padding => _viewConfiguration.padding;`
  ///
  /// This value is calculated by taking `max(0.0, FlutterView.viewPadding -
  /// FlutterView.viewInsets)`. This will treat a system IME that increases the
  /// bottom inset as consuming that much of the bottom padding.
  ///
  /// When this changes, [PlatformDispatcher.onMetricsChanged] is called.
  public var padding: ViewPadding {
    viewConfiguration.padding
  }

  /// Additional configuration for touch gestures performed on this view.
  ///
  /// **Dart Source:** `window.dart:304-309`
  /// **Original:** `GestureSettings get gestureSettings => _viewConfiguration.gestureSettings;`
  ///
  /// For example, the touch slop defined in physical pixels may be provided
  /// by the gesture settings and should be preferred over the framework
  /// touch slop constant.
  public var gestureSettings: GestureSettings {
    viewConfiguration.gestureSettings
  }

  /// Areas of the display that are obstructed by hardware features.
  ///
  /// **Dart Source:** `window.dart:311-337`
  /// **Original:** `List<DisplayFeature> get displayFeatures => _viewConfiguration.displayFeatures;`
  ///
  /// This list is populated only on Android. If the device has no display
  /// features, this list is empty.
  ///
  /// The coordinate space in which the [DisplayFeature.bounds] are defined spans
  /// across the screens currently in use. This means that the space between the screens
  /// is virtually part of the Flutter view space, with the [DisplayFeature.bounds]
  /// of the display feature as an obstructed area.
  ///
  /// When this changes, [PlatformDispatcher.onMetricsChanged] is called.
  public var displayFeatures: [DisplayFeature] {
    viewConfiguration.displayFeatures
  }

  /// Updates the view's rendering on the GPU with the newly provided [Scene].
  ///
  /// **Dart Source:** `window.dart:339-381`
  /// **Original:**
  /// ```dart
  /// void render(Scene scene, {Size? size}) {
  ///   _render(
  ///     viewId,
  ///     scene as _NativeScene,
  ///     size?.width ?? physicalSize.width,
  ///     size?.height ?? physicalSize.height,
  ///   );
  /// }
  /// ```
  ///
  /// This function must be called within the scope of the
  /// [PlatformDispatcher.onBeginFrame] or [PlatformDispatcher.onDrawFrame]
  /// callbacks being invoked.
  ///
  /// If this function is called a second time during a single
  /// [PlatformDispatcher.onBeginFrame]/[PlatformDispatcher.onDrawFrame]
  /// callback sequence or called outside the scope of those callbacks, the call
  /// will be ignored.
  ///
  /// If the view is configured with loose [physicalConstraints] (i.e.
  /// [ViewConstraints.isTight] returns false) a `size` satisfying those
  /// constraints must be provided. This method does not check that the provided
  /// `size` actually meets the constraints.
  ///
  /// **Status:** STUB - Calls C++ bridge but actual rendering is not yet connected.
  /// REASON: Full engine integration requires UIDartState alternative in Swift bridge.
  public func render(_ scene: Scene, size: Size? = nil) {
    guard let nativeScene = scene as? NativeScene else {
      fatalError("Scene must be a NativeScene")
    }

    let width = size?.width ?? physicalSize.width
    let height = size?.height ?? physicalSize.height

    // Call C++ free function via view_bridge.h
    flutter.swift_bridge.RenderView(
      Int64(viewId),
      nativeScene.bridge,
      width,
      height
    )
  }

  /// Change the retained semantics data about this [FlutterView].
  ///
  /// **Dart Source:** `window.dart:388-396`
  /// **Original:**
  /// ```dart
  /// void updateSemantics(SemanticsUpdate update) =>
  ///     _updateSemantics(viewId, update as _NativeSemanticsUpdate);
  /// ```
  ///
  /// [PlatformDispatcher.setSemanticsTreeEnabled] must be called with true
  /// before sending update through this method.
  ///
  /// This function disposes the given update, which means the semantics update
  /// cannot be used further.
  ///
  /// **Status:** STUB - Calls C++ bridge but actual semantics update is not yet connected.
  /// REASON: Full engine integration requires UIDartState alternative in Swift bridge.
  public func updateSemantics(_ update: SemanticsUpdate) {
    guard let nativeUpdate = update as? NativeSemanticsUpdate else {
      fatalError("SemanticsUpdate must be a NativeSemanticsUpdate")
    }

    // Call C++ free function via view_bridge.h
    flutter.swift_bridge.UpdateViewSemantics(
      Int64(viewId),
      nativeUpdate.bridge
    )
  }

  /// Returns a string representation of this FlutterView.
  ///
  /// **Dart Source:** `window.dart:403-404`
  /// **Original:** `String toString() => 'FlutterView(id: $viewId)';`
  public var description: String {
    "FlutterView(id: \(viewId))"
  }
}

// MARK: - Display

/// A configurable display that a [FlutterView] renders on.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/window.dart:6-39`
/// **Original Name:** `Display`
///
/// Use [FlutterView.display] to get the current display for that view.
public struct Display: CustomStringConvertible, Sendable {
    /// A unique identifier for this display.
    ///
    /// **Dart Source:** `window.dart:17-22`
    ///
    /// This identifier is unique among a list of displays the Flutter framework
    /// is aware of, and is not derived from any platform specific identifiers for
    /// displays.
    public let id: Int

    /// The device pixel ratio of this display.
    ///
    /// **Dart Source:** `window.dart:24-28`
    ///
    /// This value is the same as the value of [FlutterView.devicePixelRatio] for
    /// all view objects attached to this display.
    public let devicePixelRatio: Double

    /// The physical size of this display.
    ///
    /// **Dart Source:** `window.dart:30-31`
    public let size: Size

    /// The refresh rate in FPS of this display.
    ///
    /// **Dart Source:** `window.dart:33-34`
    public let refreshRate: Double

    /// Creates a Display with the given properties.
    ///
    /// **Dart Source:** `window.dart:10-15`
    /// **Original:** `const Display._({required this.id, required this.devicePixelRatio, required this.size, required this.refreshRate})`
    ///
    /// DIFFERENCE FROM DART: Uses internal access instead of private constructor (Display._).
    /// REASON: Swift doesn't have named private constructors. Using internal provides
    /// the same encapsulation (framework-internal construction only).
    package init(id: Int, devicePixelRatio: Double, size: Size, refreshRate: Double) {
        self.id = id
        self.devicePixelRatio = devicePixelRatio
        self.size = size
        self.refreshRate = refreshRate
    }

    /// Returns a string representation of this Display.
    ///
    /// **Dart Source:** `window.dart:36-38`
    /// **Original:** `String toString() => 'Display(id: $id, size: $size, devicePixelRatio: $devicePixelRatio, refreshRate: $refreshRate)';`
    public var description: String {
        "Display(id: \(id), size: \(size), devicePixelRatio: \(devicePixelRatio), refreshRate: \(refreshRate))"
    }
}

// MARK: - Brightness

/// Describes the contrast of a theme or color palette.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/window.dart:1030-1043`
/// **Original Name:** `Brightness` (enum)
public enum Brightness: CaseIterable, Sendable {
    /// The color is dark and will require a light text color to achieve readable
    /// contrast.
    ///
    /// **Dart Source:** `window.dart:1032-1036`
    ///
    /// For example, the color might be dark grey, requiring white text.
    case dark

    /// The color is light and will require a dark text color to achieve readable
    /// contrast.
    ///
    /// **Dart Source:** `window.dart:1038-1042`
    ///
    /// For example, the color might be bright white, requiring black text.
    case light
}

// MARK: - GestureSettings

/// Platform specific configuration for gesture behavior, such as touch slop.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/window.dart:1112-1166`
/// **Original Name:** `GestureSettings`
///
/// These settings are provided via [FlutterView.gestureSettings] to each
/// view, and should be favored for configuring gesture behavior over the
/// framework constants.
///
/// A `nil` field indicates that the platform or view does not have a preference
/// and the fallback constants should be used instead.
public struct GestureSettings: Hashable, CustomStringConvertible, Sendable {
    /// The number of physical pixels a pointer is allowed to drift before it is
    /// considered an intentional movement.
    ///
    /// **Dart Source:** `window.dart:1127-1132`
    ///
    /// If `nil`, the framework's default touch slop configuration should be used
    /// instead.
    public let physicalTouchSlop: Double?

    /// The number of physical pixels that the first and second tap of a double tap
    /// can drift apart to still be recognized as a double tap.
    ///
    /// **Dart Source:** `window.dart:1134-1139`
    ///
    /// If `nil`, the framework's default double tap slop configuration should be used
    /// instead.
    public let physicalDoubleTapSlop: Double?

    /// Create a new GestureSettings value.
    ///
    /// **Dart Source:** `window.dart:1121-1125`
    /// **Original:** `const GestureSettings({this.physicalTouchSlop, this.physicalDoubleTapSlop})`
    ///
    /// Consider using `copyWith` on an existing settings object
    /// to ensure that newly added fields are correctly set.
    public init(physicalTouchSlop: Double? = nil, physicalDoubleTapSlop: Double? = nil) {
        self.physicalTouchSlop = physicalTouchSlop
        self.physicalDoubleTapSlop = physicalDoubleTapSlop
    }

    /// Create a new GestureSettings object from an existing value, overwriting
    /// all of the provided fields.
    ///
    /// **Dart Source:** `window.dart:1141-1148`
    /// **Original:** `GestureSettings copyWith({double? physicalTouchSlop, double? physicalDoubleTapSlop})`
    public func copyWith(
        physicalTouchSlop: Double?? = nil,
        physicalDoubleTapSlop: Double?? = nil
    ) -> GestureSettings {
        GestureSettings(
            physicalTouchSlop: physicalTouchSlop ?? self.physicalTouchSlop,
            physicalDoubleTapSlop: physicalDoubleTapSlop ?? self.physicalDoubleTapSlop
        )
    }

    /// Returns a string representation of this GestureSettings.
    ///
    /// **Dart Source:** `window.dart:1163-1165`
    /// **Original:** `String toString() => 'GestureSettings(physicalTouchSlop: $physicalTouchSlop, physicalDoubleTapSlop: $physicalDoubleTapSlop)';`
    public var description: String {
        "GestureSettings(physicalTouchSlop: \(physicalTouchSlop.map { String($0) } ?? "nil"), physicalDoubleTapSlop: \(physicalDoubleTapSlop.map { String($0) } ?? "nil"))"
    }

    // MARK: - Hashable conformance
    // **Dart Source:** `window.dart:1150-1161`
    //
    // DIFFERENCE FROM DART: Using Swift's synthesized Hashable conformance.
    // REASON: Swift automatically synthesizes Equatable and Hashable for structs
    // with all Hashable stored properties. The behavior is equivalent to Dart's
    // `operator ==` and `Object.hash()` implementations.
}

// MARK: - AccessibilityFeatures

/// Additional accessibility features that may be enabled by the platform.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/window.dart:912-1028`
/// **Original Name:** `AccessibilityFeatures`
///
/// It is not possible to enable these settings from Flutter, instead they are
/// used by the platform to indicate that additional accessibility features are
/// enabled.
///
/// When changes are made to this struct, the equivalent APIs in each of the
/// embedders *must* be updated.
public struct AccessibilityFeatures: Hashable, CustomStringConvertible, Sendable {
    // MARK: Bit indices

    /// **Dart Source:** `window.dart:923`
    private static let accessibleNavigationIndex: Int = 1 << 0

    /// **Dart Source:** `window.dart:924`
    private static let invertColorsIndex: Int = 1 << 1

    /// **Dart Source:** `window.dart:925`
    private static let disableAnimationsIndex: Int = 1 << 2

    /// **Dart Source:** `window.dart:926`
    private static let boldTextIndex: Int = 1 << 3

    /// **Dart Source:** `window.dart:927`
    private static let reduceMotionIndex: Int = 1 << 4

    /// **Dart Source:** `window.dart:928`
    private static let highContrastIndex: Int = 1 << 5

    /// **Dart Source:** `window.dart:929`
    private static let onOffSwitchLabelsIndex: Int = 1 << 6

    /// **Dart Source:** `window.dart:930`
    private static let noAnnounceIndex: Int = 1 << 7

    // MARK: Storage

    /// A bitfield which represents each enabled feature.
    ///
    /// **Dart Source:** `window.dart:932-933`
    private let index: Int

    /// Creates an AccessibilityFeatures from a bitfield.
    ///
    /// **Dart Source:** `window.dart:921`
    /// **Original:** `const AccessibilityFeatures._(this._index)`
    ///
    /// DIFFERENCE FROM DART: Uses internal access instead of private constructor (AccessibilityFeatures._).
    /// REASON: Swift doesn't have named private constructors. Using internal provides
    /// the same encapsulation (framework-internal construction only).
    internal init(_ index: Int) {
        self.index = index
    }

    // MARK: Feature getters

    /// Whether there is a running accessibility service which is changing the
    /// interaction model of the device.
    ///
    /// **Dart Source:** `window.dart:935-939`
    ///
    /// For example, TalkBack on Android and VoiceOver on iOS enable this flag.
    public var accessibleNavigation: Bool {
        Self.accessibleNavigationIndex & index != 0
    }

    /// The platform is inverting the colors of the application.
    ///
    /// **Dart Source:** `window.dart:941-942`
    public var invertColors: Bool {
        Self.invertColorsIndex & index != 0
    }

    /// The platform is requesting that animations be disabled or simplified.
    ///
    /// **Dart Source:** `window.dart:944-945`
    public var disableAnimations: Bool {
        Self.disableAnimationsIndex & index != 0
    }

    /// The platform is requesting that text be rendered at a bold font weight.
    ///
    /// **Dart Source:** `window.dart:947-950`
    ///
    /// Only supported on iOS and Android API 31+.
    public var boldText: Bool {
        Self.boldTextIndex & index != 0
    }

    /// The platform is requesting that certain animations be simplified and
    /// parallax effects removed.
    ///
    /// **Dart Source:** `window.dart:952-956`
    ///
    /// Only supported on iOS.
    public var reduceMotion: Bool {
        Self.reduceMotionIndex & index != 0
    }

    /// The platform is requesting that UI be rendered with darker colors.
    ///
    /// **Dart Source:** `window.dart:958-961`
    ///
    /// Only supported on iOS.
    public var highContrast: Bool {
        Self.highContrastIndex & index != 0
    }

    /// The platform is requesting to show on/off labels inside switches.
    ///
    /// **Dart Source:** `window.dart:963-966`
    ///
    /// Only supported on iOS.
    public var onOffSwitchLabels: Bool {
        Self.onOffSwitchLabelsIndex & index != 0
    }

    /// Whether the platform supports accessibility announcement API,
    /// i.e. [SemanticsService.announce].
    ///
    /// **Dart Source:** `window.dart:968-986`
    ///
    /// Some platforms do not support or discourage the use of
    /// announcement. Using [SemanticsService.announce] on those platform
    /// may be ignored. Consider using other ways to convey message to the
    /// user. For example, Android discourages the uses of direct message
    /// announcement, and rather encourages using other semantic
    /// properties such as [SemanticsProperties.liveRegion] to convey
    /// message to the user.
    ///
    /// Returns `false` on platforms where announcements are deprecated or
    /// unsupported by the underlying platform.
    ///
    /// Returns `true` on platforms where such announcements are
    /// generally supported without discouragement. (iOS, web etc)
    ///
    /// Note: This index check is inverted (== 0 vs != 0); far more platforms support
    /// "announce" than discourage it.
    public var supportsAnnounce: Bool {
        Self.noAnnounceIndex & index == 0
    }

    // MARK: CustomStringConvertible conformance

    /// Returns a string representation of this AccessibilityFeatures.
    ///
    /// **Dart Source:** `window.dart:988-1016`
    public var description: String {
        var features: [String] = []
        if accessibleNavigation {
            features.append("accessibleNavigation")
        }
        if invertColors {
            features.append("invertColors")
        }
        if disableAnimations {
            features.append("disableAnimations")
        }
        if boldText {
            features.append("boldText")
        }
        if reduceMotion {
            features.append("reduceMotion")
        }
        if highContrast {
            features.append("highContrast")
        }
        if onOffSwitchLabels {
            features.append("onOffSwitchLabels")
        }
        if supportsAnnounce {
            features.append("supportsAnnounce")
        }
        return "AccessibilityFeatures\(features)"
    }

    // MARK: Hashable conformance

    /// **Dart Source:** `window.dart:1018-1024`
    ///
    /// DIFFERENCE FROM DART: Using explicit Equatable implementation instead of operator ==.
    /// REASON: Swift uses the Equatable protocol pattern. The behavior is identical to
    /// Dart's `operator ==` checking `runtimeType` and `_index` equality.
    public static func == (lhs: AccessibilityFeatures, rhs: AccessibilityFeatures) -> Bool {
        lhs.index == rhs.index
    }

    /// **Dart Source:** `window.dart:1026-1027`
    /// **Original:** `int get hashCode => _index.hashCode;`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(index)
    }
}
