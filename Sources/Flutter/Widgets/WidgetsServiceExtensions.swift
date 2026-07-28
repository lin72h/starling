// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// MARK: - WidgetsServiceExtensions

/// Service extension constants for the widgets library.
///
/// These constants will be used when registering service extensions in the
/// framework, and they will also be used by tools and services that call these
/// service extensions.
///
/// The String value for each of these extension names should be accessed by
/// using the `rawValue` property on the enum value.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/service_extensions.dart:24-116`
public enum WidgetsServiceExtensions: String, Sendable {
    /// Name of service extension that, when called, will output a string
    /// representation of this app's widget tree to console.
    ///
    /// **Dart Source:** `service_extensions.dart:32`
    case debugDumpApp

    /// Name of service extension that, when called, will output a string
    /// representation of the focus tree to the console.
    ///
    /// **Dart Source:** `service_extensions.dart:41`
    case debugDumpFocusTree

    /// Name of service extension that, when called, will overlay a performance
    /// graph on top of this app.
    ///
    /// **Dart Source:** `service_extensions.dart:52`
    case showPerformanceOverlay

    /// Name of service extension that, when called, will return whether the first
    /// `Flutter.Frame` event has been reported on the Extension stream.
    ///
    /// **Dart Source:** `service_extensions.dart:61`
    case didSendFirstFrameEvent

    /// Name of service extension that, when called, will return whether the first
    /// frame has been rasterized and the trace event `Rasterized first useful
    /// frame` has been sent out.
    ///
    /// **Dart Source:** `service_extensions.dart:71`
    case didSendFirstFrameRasterizedEvent

    /// Name of service extension that, when called, will reassemble the
    /// application.
    ///
    /// **Dart Source:** `service_extensions.dart:80`
    case fastReassemble

    /// Name of service extension that, when called, will change the value of
    /// `debugProfileBuildsEnabled`, which adds `Timeline` events for every widget
    /// built.
    ///
    /// **Dart Source:** `service_extensions.dart:92`
    case profileWidgetBuilds

    /// Name of service extension that, when called, will change the value of
    /// `debugProfileBuildsEnabledUserWidgets`, which adds `Timeline` events for
    /// every user-created widget built.
    ///
    /// **Dart Source:** `service_extensions.dart:103`
    case profileUserWidgetBuilds

    /// Name of service extension that, when called, will change the value of
    /// `WidgetsApp.debugAllowBannerOverride`, which controls the visibility of the
    /// debug banner for debug mode apps.
    ///
    /// **Dart Source:** `service_extensions.dart:115`
    case debugAllowBanner
}

// MARK: - WidgetInspectorServiceExtensions

/// Service extension constants for the Widget Inspector.
///
/// These constants will be used when registering service extensions in the
/// framework, and they will also be used by tools and services that call these
/// service extensions.
///
/// The String value for each of these extension names should be accessed by
/// using the `rawValue` property on the enum value.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/service_extensions.dart:126-530`
public enum WidgetInspectorServiceExtensions: String, Sendable {
    /// Name of service extension that, when called, will determine whether
    /// `FlutterError` messages will be presented using a structured format.
    ///
    /// **Dart Source:** `service_extensions.dart:134`
    case structuredErrors

    /// Name of service extension that, when called, will change the value of
    /// `WidgetsBinding.debugShowWidgetInspectorOverride`, which controls whether the
    /// on-device widget inspector is visible.
    ///
    /// **Dart Source:** `service_extensions.dart:145`
    case show

    /// Name of service extension that, when called, determines
    /// whether a callback is invoked for every dirty `Widget` built each frame.
    ///
    /// **Dart Source:** `service_extensions.dart:156`
    case trackRebuildDirtyWidgets

    /// Name of service extension that, when called, returns the mapping of
    /// widget locations to ids.
    ///
    /// **Dart Source:** `service_extensions.dart:170`
    case widgetLocationIdMap

    /// Name of service extension that, when called, determines whether
    /// a callback is invoked for every `RenderObject` painted each frame.
    ///
    /// **Dart Source:** `service_extensions.dart:182`
    case trackRepaintWidgets

    /// Name of service extension that, when called, will clear all
    /// `WidgetInspectorService` object references in all groups.
    ///
    /// **Dart Source:** `service_extensions.dart:193`
    case disposeAllGroups

    /// Name of service extension that, when called, will clear all
    /// `WidgetInspectorService` object references in a group.
    ///
    /// **Dart Source:** `service_extensions.dart:204`
    case disposeGroup

    /// Name of service extension that, when called, returns whether it is
    /// appropriate to display the Widget tree in the inspector, which is only
    /// true after the application has rendered its first frame.
    ///
    /// **Dart Source:** `service_extensions.dart:218`
    case isWidgetTreeReady

    /// Name of service extension that, when called, will remove the object with
    /// the specified `id` from the specified object group.
    ///
    /// **Dart Source:** `service_extensions.dart:229`
    case disposeId

    // Note: setPubRootDirectories (Dart line 247) is skipped because it is deprecated.

    /// Name of service extension that, when called, will add a list of
    /// directories that should be considered part of the local project for the
    /// Widget inspector summary tree.
    ///
    /// **Dart Source:** `service_extensions.dart:263`
    case addPubRootDirectories

    /// Name of service extension that, when called, will remove a list of
    /// directories that should no longer be considered part of the local project
    /// for the Widget inspector summary tree.
    ///
    /// **Dart Source:** `service_extensions.dart:279`
    case removePubRootDirectories

    /// Name of service extension that, when called, will return the list of
    /// directories that are considered part of the local project
    /// for the Widget inspector summary tree.
    ///
    /// **Dart Source:** `service_extensions.dart:295`
    case getPubRootDirectories

    /// Name of service extension that, when called, will set the
    /// `WidgetInspector` selection to the object matching the specified id and
    /// will return whether the selection was changed.
    ///
    /// **Dart Source:** `service_extensions.dart:307`
    case setSelectionById

    /// Name of service extension that, when called, will retrieve the chain of
    /// `DiagnosticsNode` instances from the root of the tree to the `Element` or
    /// `RenderObject` matching the specified id, passed as an argument.
    ///
    /// **Dart Source:** `service_extensions.dart:319`
    case getParentChain

    /// Name of service extension that, when called, will return the properties
    /// for the `DiagnosticsNode` object matching the specified id, passed as an
    /// argument.
    ///
    /// **Dart Source:** `service_extensions.dart:331`
    case getProperties

    /// Name of service extension that, when called, will return the children
    /// for the `DiagnosticsNode` object matching the specified id, passed as an
    /// argument.
    ///
    /// **Dart Source:** `service_extensions.dart:343`
    case getChildren

    /// Name of service extension that, when called, will return the children
    /// created by user code for the `DiagnosticsNode` object matching the
    /// specified id, passed as an argument.
    ///
    /// **Dart Source:** `service_extensions.dart:355`
    case getChildrenSummaryTree

    /// Name of service extension that, when called, will return all children and
    /// their properties for the `DiagnosticsNode` object matching the specified
    /// id, passed as an argument.
    ///
    /// **Dart Source:** `service_extensions.dart:367`
    case getChildrenDetailsSubtree

    /// Name of service extension that, when called, will return the
    /// `DiagnosticsNode` data for the root `Element`.
    ///
    /// **Dart Source:** `service_extensions.dart:378`
    case getRootWidget

    /// Name of service extension that, when called, will return the
    /// `DiagnosticsNode` data for the root `Element` of the widget tree.
    ///
    /// **Dart Source:** `service_extensions.dart:394`
    case getRootWidgetTree

    /// Name of service extension that, when called, will return the
    /// `DiagnosticsNode` data for the root `Element` of the summary tree, which
    /// only includes `Element`s that were created by user code.
    ///
    /// **Dart Source:** `service_extensions.dart:406`
    case getRootWidgetSummaryTree

    /// Name of service extension that, when called, will return the
    /// `DiagnosticsNode` data for the root `Element` of the summary tree with
    /// text previews included.
    ///
    /// **Dart Source:** `service_extensions.dart:420`
    case getRootWidgetSummaryTreeWithPreviews

    /// Name of service extension that, when called, will return the details
    /// subtree, which includes properties, rooted at the `DiagnosticsNode` object
    /// matching the specified id and the having a size matching the specified
    /// subtree depth, both passed as arguments.
    ///
    /// **Dart Source:** `service_extensions.dart:435`
    case getDetailsSubtree

    /// Name of service extension that, when called, will return the
    /// `DiagnosticsNode` data for the currently selected `Element`.
    ///
    /// **Dart Source:** `service_extensions.dart:446`
    case getSelectedWidget

    /// Name of service extension that, when called, will return the
    /// `DiagnosticsNode` data for the currently selected `Element` in the summary
    /// tree, which only includes `Element`s created in user code.
    ///
    /// **Dart Source:** `service_extensions.dart:462`
    case getSelectedSummaryWidget

    /// Name of service extension that, when called, will return whether `Widget`
    /// creation locations are available.
    ///
    /// **Dart Source:** `service_extensions.dart:473`
    case isWidgetCreationTracked

    /// Name of service extension that, when called, will return a base64 encoded
    /// image of the `RenderObject` or `Element` matching the specified `id`,
    /// passed as an argument, and sized at the specified `width` and `height`
    /// values, also passed as arguments.
    ///
    /// **Dart Source:** `service_extensions.dart:486`
    case screenshot

    /// Name of service extension that, when called, will return the
    /// `DiagnosticsNode` data for the currently selected `Element` and will
    /// include information about the `Element`'s layout properties.
    ///
    /// **Dart Source:** `service_extensions.dart:496`
    case getLayoutExplorerNode

    /// Name of service extension that, when called, will set the `FlexFit` value
    /// for the `FlexParentData` of the `RenderObject` matching the specified
    /// `id`, passed as an argument.
    ///
    /// **Dart Source:** `service_extensions.dart:506`
    case setFlexFit

    /// Name of service extension that, when called, will set the flex value
    /// for the `FlexParentData` of the `RenderObject` matching the specified
    /// `id`, passed as an argument.
    ///
    /// **Dart Source:** `service_extensions.dart:516`
    case setFlexFactor

    /// Name of service extension that, when called, will set the
    /// `MainAxisAlignment` and `CrossAxisAlignment` values for the `RenderFlex`
    /// matching the specified `id`, passed as an argument.
    ///
    /// **Dart Source:** `service_extensions.dart:529`
    case setFlexProperties
}
