// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// SwiftRuntimeDelegate Integration Tests — Step 1.7 Minimal Test Harness
///
/// These tests validate the full frame cycle and Shell-to-Framework call routing
/// through SwiftRuntimeDelegate -> PlatformDispatcher. This is the Swift-side
/// validation of the C++ -> Swift interop path:
///
///   SwiftRuntimeController::BeginFrame()
///     -> impl_->delegate.beginFrame()       [C++ -> Swift]
///     -> PlatformDispatcher._beginFrame()
///     -> PlatformDispatcher.onBeginFrame?()  [user callback]
///
/// These tests exercise SwiftRuntimeDelegate directly (without the C++ side)
/// to verify the Swift half of the integration pipeline.
///
/// **Important:** All tests are serialized under a single top-level suite
/// because they share the `PlatformDispatcher.instance` singleton. Concurrent
/// access to its mutable callback properties (onBeginFrame, onDrawFrame, etc.)
/// would cause data races and test flakiness.
///
/// **See also:** `plans/shell_without_dart_exploration.md` Section 9, Step 1.7

import Testing
@testable import SwiftRuntime
@testable import FlutterSwiftBridge

// All tests must be serialized because they share PlatformDispatcher.instance.
// Swift Testing's .serialized trait on a top-level suite ensures all nested
// suites and tests run one at a time, preventing concurrent mutation of the
// PlatformDispatcher singleton's callbacks and state.
@Suite("SwiftRuntimeDelegate Tests", .serialized)
struct SwiftRuntimeDelegateTests {

  // MARK: - Frame Cycle Tests

  @Suite("Frame Cycle")
  struct FrameCycleTests {

    /// Verifies that `beginFrame` routes through PlatformDispatcher.onBeginFrame.
    ///
    /// This validates the critical path:
    ///   SwiftRuntimeDelegate.beginFrame(microseconds, frameNumber)
    ///   -> PlatformDispatcher._updateFrameData(frameNumber)
    ///   -> PlatformDispatcher._beginFrame(microseconds)
    ///   -> PlatformDispatcher.onBeginFrame?(duration)
    @Test("beginFrame invokes PlatformDispatcher.onBeginFrame with correct duration")
    func testBeginFrameInvokesOnBeginFrame() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      var receivedDuration: Duration?
      pd.onBeginFrame = { duration in
        receivedDuration = duration
      }
      defer { pd.onBeginFrame = nil }

      // Call beginFrame with 16667 microseconds (~1 frame at 60fps) and frame number 1
      delegate.beginFrame(16667, 1)

      #expect(receivedDuration != nil, "onBeginFrame should have been called")
      #expect(receivedDuration == .microseconds(16667),
              "Duration should be 16667 microseconds")
    }

    /// Verifies that `drawFrame` routes through PlatformDispatcher.onDrawFrame.
    ///
    /// This validates:
    ///   SwiftRuntimeDelegate.drawFrame()
    ///   -> PlatformDispatcher._drawFrame()
    ///   -> PlatformDispatcher.onDrawFrame?()
    @Test("drawFrame invokes PlatformDispatcher.onDrawFrame")
    func testDrawFrameInvokesOnDrawFrame() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      var drawFrameCalled = false
      pd.onDrawFrame = {
        drawFrameCalled = true
      }
      defer { pd.onDrawFrame = nil }

      delegate.drawFrame()

      #expect(drawFrameCalled, "onDrawFrame should have been called")
    }

    /// Verifies the full beginFrame + drawFrame sequence as called by
    /// SwiftRuntimeController::BeginFrame in C++.
    ///
    /// The C++ code calls:
    ///   impl_->delegate.beginFrame(microseconds, frame_number)
    ///   impl_->delegate.drawFrame()
    ///
    /// This test simulates that exact sequence and verifies both callbacks fire
    /// in the correct order.
    @Test("Full beginFrame + drawFrame sequence fires callbacks in order")
    func testFullBeginDrawFrameSequence() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      var callOrder: [String] = []

      pd.onBeginFrame = { _ in
        callOrder.append("beginFrame")
      }
      pd.onDrawFrame = {
        callOrder.append("drawFrame")
      }
      defer {
        pd.onBeginFrame = nil
        pd.onDrawFrame = nil
      }

      // Simulate the C++ SwiftRuntimeController::BeginFrame sequence
      delegate.beginFrame(16667, 1)
      delegate.drawFrame()

      #expect(callOrder == ["beginFrame", "drawFrame"],
              "Callbacks should fire in order: beginFrame then drawFrame")
    }

    /// Verifies that beginFrame updates the PlatformDispatcher's frameData.
    ///
    /// The delegate calls `_updateFrameData(frameNumber)` before `_beginFrame`,
    /// which updates `PlatformDispatcher.frameData.frameNumber`.
    @Test("beginFrame updates PlatformDispatcher.frameData")
    func testBeginFrameUpdatesFrameData() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      // Set up a no-op callback so beginFrame proceeds
      pd.onBeginFrame = { _ in }
      defer { pd.onBeginFrame = nil }

      delegate.beginFrame(16667, 42)

      #expect(pd.frameData.frameNumber == 42,
              "Frame number should be updated to 42")
    }

    /// Verifies that multiple frames update frame data correctly.
    @Test("Multiple frames update frame data with increasing frame numbers")
    func testMultipleFramesUpdateFrameData() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      var frameNumbers: [Int] = []
      pd.onBeginFrame = { _ in
        frameNumbers.append(pd.frameData.frameNumber)
      }
      defer { pd.onBeginFrame = nil }

      delegate.beginFrame(16667, 1)
      delegate.beginFrame(33334, 2)
      delegate.beginFrame(50001, 3)

      #expect(frameNumbers == [1, 2, 3],
              "Frame numbers should increase monotonically")
    }

    /// Verifies that beginFrame works with zero microseconds (edge case).
    @Test("beginFrame with zero microseconds invokes callback with zero duration")
    func testBeginFrameZeroMicroseconds() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      var receivedDuration: Duration?
      pd.onBeginFrame = { duration in
        receivedDuration = duration
      }
      defer { pd.onBeginFrame = nil }

      delegate.beginFrame(0, 1)

      #expect(receivedDuration == .microseconds(0),
              "Duration should be zero microseconds")
    }

    /// Verifies that beginFrame with no callback set does not crash.
    ///
    /// This is an important safety check — the engine may call beginFrame before
    /// the Swift framework has registered its onBeginFrame callback.
    @Test("beginFrame with nil callback does not crash")
    func testBeginFrameNilCallbackDoesNotCrash() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      // Ensure callbacks are nil
      pd.onBeginFrame = nil
      pd.onDrawFrame = nil

      // This should not crash
      delegate.beginFrame(16667, 1)
      delegate.drawFrame()

      // If we get here, the test passed (no crash)
    }
  }

  // MARK: - Semantics Tests

  @Suite("Semantics")
  struct SemanticsTests {

    /// Verifies that setSemanticsEnabled updates the delegate's isSemanticsEnabled flag.
    @Test("setSemanticsEnabled updates delegate state")
    func testSetSemanticsEnabled() {
      let delegate = SwiftRuntimeDelegate()

      #expect(!delegate.isSemanticsEnabled,
              "Semantics should be disabled by default")

      delegate.setSemanticsEnabled(true)
      #expect(delegate.isSemanticsEnabled,
              "Semantics should be enabled after setSemanticsEnabled(true)")

      delegate.setSemanticsEnabled(false)
      #expect(!delegate.isSemanticsEnabled,
              "Semantics should be disabled after setSemanticsEnabled(false)")
    }

    /// Verifies that setSemanticsEnabled routes to PlatformDispatcher.
    @Test("setSemanticsEnabled routes through PlatformDispatcher")
    func testSetSemanticsEnabledRoutes() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      delegate.setSemanticsEnabled(true)
      #expect(pd.semanticsEnabled == true,
              "PlatformDispatcher.semanticsEnabled should be true")

      delegate.setSemanticsEnabled(false)
      #expect(pd.semanticsEnabled == false,
              "PlatformDispatcher.semanticsEnabled should be false")
    }
  }

  // MARK: - View Management Tests

  @Suite("View Management")
  struct ViewManagementTests {

    /// Verifies that addView creates a FlutterView accessible via PlatformDispatcher.
    @Test("addView creates accessible FlutterView")
    func testAddView() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      // Add a view with unique ID 100, 800x600 @2x on display 0
      delegate.addView(100, 800.0, 600.0, 2.0, 0)

      let view = pd.view(id: 100)
      #expect(view != nil, "View with ID 100 should exist after addView")
      #expect(view?.viewId == 100, "View ID should be 100")

      // Clean up
      delegate.removeView(100)
    }

    /// Verifies that removeView removes a previously added FlutterView.
    @Test("removeView removes FlutterView")
    func testRemoveView() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      delegate.addView(101, 800.0, 600.0, 2.0, 0)
      #expect(pd.view(id: 101) != nil, "View should exist after addView")

      delegate.removeView(101)
      #expect(pd.view(id: 101) == nil, "View should not exist after removeView")
    }

    /// Verifies that setViewportMetrics updates an existing view's configuration.
    @Test("setViewportMetrics updates view configuration")
    func testSetViewportMetrics() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      // Add a view first
      delegate.addView(102, 800.0, 600.0, 2.0, 0)

      var metricsChanged = false
      pd.onMetricsChanged = {
        metricsChanged = true
      }
      defer {
        pd.onMetricsChanged = nil
        delegate.removeView(102)
      }

      // Update viewport metrics with new size
      delegate.setViewportMetrics(
        102,    // viewId
        1920.0, // width
        1080.0, // height
        3.0,    // dpr
        0.0, 0.0, 0.0, 0.0,  // viewPadding (top, right, bottom, left)
        0.0, 0.0, 0.0, 0.0,  // viewInset (top, right, bottom, left)
        0.0, 0.0, 0.0, 0.0,  // systemGestureInset (top, right, bottom, left)
        -1.0,   // physicalTouchSlop (-1 = unset)
        0       // displayId
      )

      #expect(metricsChanged, "onMetricsChanged should have fired")
    }
  }

  // MARK: - Display Configuration Tests

  @Suite("Display Configuration")
  struct DisplayConfigurationTests {

    /// Verifies that updateDisplays updates PlatformDispatcher's display list.
    @Test("updateDisplays updates PlatformDispatcher.displays")
    func testUpdateDisplays() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      // Encode one display: [id=0, dpr=2.0, width=2560, height=1600, refreshRate=60]
      let encodedDisplays: [Double] = [0.0, 2.0, 2560.0, 1600.0, 60.0]
      delegate.updateDisplays(encodedDisplays)

      let displays = pd.displays
      #expect(displays.count == 1, "Should have one display")
      #expect(displays.first?.id == 0, "Display ID should be 0")
      #expect(displays.first?.devicePixelRatio == 2.0,
              "Display pixel ratio should be 2.0")
      #expect(displays.first?.refreshRate == 60.0,
              "Display refresh rate should be 60.0")
    }

    /// Verifies that multiple displays can be set.
    @Test("updateDisplays handles multiple displays")
    func testUpdateMultipleDisplays() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      // Encode two displays
      let encodedDisplays: [Double] = [
        0.0, 2.0, 2560.0, 1600.0, 60.0,  // Display 0
        1.0, 1.0, 1920.0, 1080.0, 144.0,  // Display 1
      ]
      delegate.updateDisplays(encodedDisplays)

      let displays = pd.displays
      #expect(displays.count == 2, "Should have two displays")
    }
  }

  // MARK: - Localization & Settings Tests

  @Suite("Localization & Settings")
  struct LocalizationSettingsTests {

    /// Verifies that updateLocales routes to PlatformDispatcher.
    @Test("updateLocales routes through PlatformDispatcher")
    func testUpdateLocales() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      var localeChanged = false
      pd.onLocaleChanged = {
        localeChanged = true
      }
      defer { pd.onLocaleChanged = nil }

      // Pass locale data: [languageCode, countryCode, scriptCode, variant]
      delegate.updateLocales(["en", "US", "", ""])

      #expect(localeChanged, "onLocaleChanged should have fired")
    }

    /// Verifies that updateInitialLifecycleState routes to PlatformDispatcher.
    @Test("updateInitialLifecycleState sets initial lifecycle state")
    func testUpdateInitialLifecycleState() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      delegate.updateInitialLifecycleState("AppLifecycleState.resumed")

      #expect(pd.initialLifecycleState == "AppLifecycleState.resumed",
              "Initial lifecycle state should be 'AppLifecycleState.resumed'")
    }
  }

  // MARK: - Error Handling Tests

  @Suite("Error Handling")
  struct ErrorHandlingTests {

    /// Verifies that onError returns false when no error handler is registered.
    @Test("onError returns false with no handler")
    func testOnErrorNoHandler() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      // Ensure no error handler
      pd.onError = nil

      let handled = delegate.onError("test error", "stack trace here")
      #expect(!handled, "onError should return false when no handler is registered")
    }

    /// Verifies that onError routes to PlatformDispatcher.onError.
    @Test("onError routes through PlatformDispatcher.onError")
    func testOnErrorRoutes() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      var receivedError: String?
      pd.onError = { error, stackTrace in
        receivedError = "\(error)"
        return true
      }
      defer { pd.onError = nil }

      let handled = delegate.onError("test error", "at line 42")
      #expect(handled, "onError should return true when handler returns true")
      #expect(receivedError != nil, "Error handler should have received the error")
    }
  }

  // MARK: - Construction Tests

  @Suite("Construction")
  struct ConstructionTests {

    /// Verifies that SwiftRuntimeDelegate can be constructed with default values.
    ///
    /// This is the most basic test — it validates that the Swift class can be
    /// instantiated, which is the prerequisite for C++ construction via
    /// `SwiftRuntime::SwiftRuntimeDelegate::init()`.
    @Test("SwiftRuntimeDelegate can be constructed")
    func testConstruction() {
      let delegate = SwiftRuntimeDelegate()

      // Verify default state
      #expect(!delegate.isSemanticsEnabled,
              "Semantics should be disabled by default")
    }

    /// Verifies that multiple delegates can coexist.
    ///
    /// In practice there should only be one, but this validates there are no
    /// singleton constraints in the delegate itself (the singleton is PlatformDispatcher).
    @Test("Multiple SwiftRuntimeDelegate instances can coexist")
    func testMultipleInstances() {
      let delegate1 = SwiftRuntimeDelegate()
      let delegate2 = SwiftRuntimeDelegate()

      delegate1.setSemanticsEnabled(true)
      delegate2.setSemanticsEnabled(false)

      // Both delegates route to the same PlatformDispatcher singleton,
      // so the last write wins
      #expect(!PlatformDispatcher.instance.semanticsEnabled,
              "Last setSemanticsEnabled(false) should win on shared PlatformDispatcher")
    }
  }

  // MARK: - Simulated Frame Cycle Integration Tests

  @Suite("Simulated Frame Cycle Integration")
  struct FrameCycleIntegrationTests {

    /// Simulates the full frame cycle as it would happen through the engine:
    ///
    /// 1. Swift sets up `onBeginFrame` to build a simple scene
    /// 2. Engine calls `beginFrame` -> triggers the onBeginFrame callback
    /// 3. Inside onBeginFrame, the user would build a Scene and render it
    /// 4. Engine calls `drawFrame` -> triggers the onDrawFrame callback
    ///
    /// This test validates the Swift-side half of the full frame cycle described
    /// in the exploration doc Section 9, Step 1.7. The C++ side
    /// (SwiftRuntimeController -> delegate) is validated separately.
    @Test("Simulated frame cycle: setup -> beginFrame -> build scene -> drawFrame")
    func testSimulatedFrameCycle() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      // Track the cycle phases
      var phases: [String] = []

      // Step 1: Set up onBeginFrame (like a Flutter app would)
      pd.onBeginFrame = { duration in
        phases.append("onBeginFrame(\(duration))")

        // In a real app, this is where SceneBuilder creates a Scene
        // and FlutterView.render() submits it to the engine.
        // We validate the scene building works in CompositingTests.
        // Here we just verify the callback was invoked.
      }

      pd.onDrawFrame = {
        phases.append("onDrawFrame")
      }

      defer {
        pd.onBeginFrame = nil
        pd.onDrawFrame = nil
      }

      // Step 2: Simulate the engine calling beginFrame (as SwiftRuntimeController would)
      delegate.beginFrame(16667, 1)

      // Step 3: Simulate the engine calling drawFrame (as SwiftRuntimeController would)
      delegate.drawFrame()

      // Step 4: Verify the full cycle completed
      #expect(phases.count == 2, "Both frame callbacks should have fired")
      if phases.count >= 1 {
        #expect(phases[0].hasPrefix("onBeginFrame"),
                "First callback should be onBeginFrame")
      }
      if phases.count >= 2 {
        #expect(phases[1] == "onDrawFrame",
                "Second callback should be onDrawFrame")
      }
      #expect(pd.frameData.frameNumber == 1,
              "Frame data should reflect frame number 1")
    }

    /// Verifies that the frame cycle works for multiple consecutive frames.
    ///
    /// This simulates a 3-frame animation loop where each frame:
    /// 1. Receives beginFrame with increasing timestamps
    /// 2. Processes the frame (onBeginFrame callback)
    /// 3. Completes the frame (drawFrame/onDrawFrame callback)
    @Test("Multiple consecutive frame cycles work correctly")
    func testMultipleConsecutiveFrameCycles() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      var beginFrameCount = 0
      var drawFrameCount = 0

      pd.onBeginFrame = { _ in
        beginFrameCount += 1
      }
      pd.onDrawFrame = {
        drawFrameCount += 1
      }
      defer {
        pd.onBeginFrame = nil
        pd.onDrawFrame = nil
      }

      // Simulate 3 frames at ~60fps (16.667ms apart)
      for i in 1...3 {
        let microseconds = Int64(i) * 16667
        delegate.beginFrame(microseconds, UInt64(i))
        delegate.drawFrame()
      }

      #expect(beginFrameCount == 3, "Should have processed 3 begin frames")
      #expect(drawFrameCount == 3, "Should have processed 3 draw frames")
      #expect(pd.frameData.frameNumber == 3,
              "Frame data should reflect last frame number")
    }

    /// Verifies that view management + frame cycle work together.
    ///
    /// This simulates:
    /// 1. Engine adds a view (like the implicit view)
    /// 2. Engine sends a frame
    /// 3. The frame callback can access the view
    @Test("View management and frame cycle work together")
    func testViewManagementWithFrameCycle() {
      let delegate = SwiftRuntimeDelegate()
      let pd = PlatformDispatcher.instance

      // Add a view with unique ID 200 (simulating what the engine does at startup)
      delegate.addView(200, 800.0, 600.0, 2.0, 0)

      var viewAccessible = false
      pd.onBeginFrame = { _ in
        // During a frame callback, the view should be accessible
        if pd.view(id: 200) != nil {
          viewAccessible = true
        }
      }
      defer {
        pd.onBeginFrame = nil
        delegate.removeView(200)
      }

      delegate.beginFrame(16667, 1)

      #expect(viewAccessible, "View should be accessible during frame callback")
    }
  }
}
