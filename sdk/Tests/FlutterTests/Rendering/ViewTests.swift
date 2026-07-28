// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for View types from the Rendering layer.
///
/// **Swift Source:** `Sources/Flutter/Rendering/View.swift`
///
/// These tests cover:
///   - RenderViewConfiguration (init, properties, equality, hashing, description,
///     fromView, toMatrix, shouldUpdateMatrix, toPhysicalSize)
///   - RenderView (construction, configuration, child management, size,
///     isRepaintBoundary, hasConfiguration, constraints, paintBounds)

import Testing
@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - Test Helpers

/// Ensures a FlutterView with viewId 0 is registered on PlatformDispatcher.
/// In a test environment there is no running engine, so `implicitView` is nil
/// by default. This helper registers a view so tests can use it.
private func ensureImplicitView() -> FlutterView {
    let pd = PlatformDispatcher.instance
    if let view = pd.implicitView { return view }
    let config = ViewConfiguration(
        devicePixelRatio: 2.0,
        size: Size(800, 600),
        viewConstraints: ViewConstraints(
            minWidth: 0, maxWidth: 800,
            minHeight: 0, maxHeight: 600
        )
    )
    pd._addView(0, config)
    return pd.implicitView!
}

/// A concrete RenderBox subclass with a configurable fixed size.
private class FixedSizeRenderBox: RenderBox {
    var fixedWidth: Double
    var fixedHeight: Double

    init(width: Double = 200.0, height: Double = 300.0) {
        self.fixedWidth = width
        self.fixedHeight = height
        super.init()
    }

    override func performLayout() {
        size = boxConstraints.constrain(Size(fixedWidth, fixedHeight))
    }

    override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        return constraints.constrain(Size(fixedWidth, fixedHeight))
    }
}

// =============================================================================
// MARK: - RenderViewConfiguration Init Tests
// =============================================================================

@Suite("RenderViewConfiguration Init Tests")
struct RenderViewConfigurationInitTests {

    @Test("Default init produces zero constraints and dpr 1.0")
    func testDefaultInit() {
        let config = RenderViewConfiguration()
        #expect(config.devicePixelRatio == 1.0)
        #expect(config.logicalConstraints.maxWidth == 0)
        #expect(config.logicalConstraints.maxHeight == 0)
        #expect(config.physicalConstraints.maxWidth == 0)
        #expect(config.physicalConstraints.maxHeight == 0)
    }

    @Test("Init stores all properties")
    func testInitStoresProperties() {
        let logical = BoxConstraints(
            minWidth: 0, maxWidth: 400, minHeight: 0, maxHeight: 800
        )
        let physical = BoxConstraints(
            minWidth: 0, maxWidth: 800, minHeight: 0, maxHeight: 1600
        )
        let config = RenderViewConfiguration(
            physicalConstraints: physical,
            logicalConstraints: logical,
            devicePixelRatio: 2.0
        )
        #expect(config.logicalConstraints == logical)
        #expect(config.physicalConstraints == physical)
        #expect(config.devicePixelRatio == 2.0)
    }

    @Test("Init with custom device pixel ratio")
    func testInitCustomDPR() {
        let config = RenderViewConfiguration(devicePixelRatio: 3.5)
        #expect(config.devicePixelRatio == 3.5)
    }
}

// =============================================================================
// MARK: - RenderViewConfiguration Equality Tests
// =============================================================================

@Suite("RenderViewConfiguration Equality Tests")
struct RenderViewConfigurationEqualityTests {

    @Test("Equal configurations are equal")
    func testEquality() {
        let logical = BoxConstraints(minWidth: 0, maxWidth: 400, minHeight: 0, maxHeight: 800)
        let physical = BoxConstraints(minWidth: 0, maxWidth: 800, minHeight: 0, maxHeight: 1600)
        let a = RenderViewConfiguration(
            physicalConstraints: physical,
            logicalConstraints: logical,
            devicePixelRatio: 2.0
        )
        let b = RenderViewConfiguration(
            physicalConstraints: physical,
            logicalConstraints: logical,
            devicePixelRatio: 2.0
        )
        #expect(a == b)
    }

    @Test("Configurations with different devicePixelRatio are not equal")
    func testInequalityDPR() {
        let a = RenderViewConfiguration(devicePixelRatio: 1.0)
        let b = RenderViewConfiguration(devicePixelRatio: 2.0)
        #expect(a != b)
    }

    @Test("Configurations with different logicalConstraints are not equal")
    func testInequalityLogical() {
        let a = RenderViewConfiguration(
            logicalConstraints: BoxConstraints(maxWidth: 100, maxHeight: 200)
        )
        let b = RenderViewConfiguration(
            logicalConstraints: BoxConstraints(maxWidth: 200, maxHeight: 400)
        )
        #expect(a != b)
    }

    @Test("Configurations with different physicalConstraints are not equal")
    func testInequalityPhysical() {
        let a = RenderViewConfiguration(
            physicalConstraints: BoxConstraints(maxWidth: 100, maxHeight: 200)
        )
        let b = RenderViewConfiguration(
            physicalConstraints: BoxConstraints(maxWidth: 200, maxHeight: 400)
        )
        #expect(a != b)
    }

    @Test("Default configurations are equal")
    func testDefaultEquality() {
        let a = RenderViewConfiguration()
        let b = RenderViewConfiguration()
        #expect(a == b)
    }
}

// =============================================================================
// MARK: - RenderViewConfiguration Hashable Tests
// =============================================================================

@Suite("RenderViewConfiguration Hashable Tests")
struct RenderViewConfigurationHashableTests {

    @Test("Equal configurations have same hash")
    func testEqualHash() {
        let logical = BoxConstraints(minWidth: 0, maxWidth: 400, minHeight: 0, maxHeight: 800)
        let physical = BoxConstraints(minWidth: 0, maxWidth: 800, minHeight: 0, maxHeight: 1600)
        let a = RenderViewConfiguration(
            physicalConstraints: physical,
            logicalConstraints: logical,
            devicePixelRatio: 2.0
        )
        let b = RenderViewConfiguration(
            physicalConstraints: physical,
            logicalConstraints: logical,
            devicePixelRatio: 2.0
        )
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Can be used in a Set")
    func testInSet() {
        let a = RenderViewConfiguration(devicePixelRatio: 1.0)
        let b = RenderViewConfiguration(devicePixelRatio: 2.0)
        let c = RenderViewConfiguration(devicePixelRatio: 1.0)
        let set: Set<RenderViewConfiguration> = [a, b, c]
        #expect(set.count == 2) // a and c are equal
    }

    @Test("Can be used as Dictionary key")
    func testAsDictionaryKey() {
        let config = RenderViewConfiguration(devicePixelRatio: 2.0)
        var dict: [RenderViewConfiguration: String] = [:]
        dict[config] = "test"
        #expect(dict[config] == "test")
    }
}

// =============================================================================
// MARK: - RenderViewConfiguration toMatrix Tests
// =============================================================================

@Suite("RenderViewConfiguration toMatrix Tests")
struct RenderViewConfigurationToMatrixTests {

    @Test("toMatrix with dpr 1.0 is identity-like")
    func testToMatrixIdentity() {
        let config = RenderViewConfiguration(devicePixelRatio: 1.0)
        let matrix = config.toMatrix()
        // diagonal3Values(1.0, 1.0, 1.0) should be close to identity
        #expect(matrix.entry(0, 0) == 1.0)
        #expect(matrix.entry(1, 1) == 1.0)
        #expect(matrix.entry(2, 2) == 1.0)
    }

    @Test("toMatrix with dpr 2.0 scales by 2")
    func testToMatrixScale2() {
        let config = RenderViewConfiguration(devicePixelRatio: 2.0)
        let matrix = config.toMatrix()
        #expect(matrix.entry(0, 0) == 2.0)
        #expect(matrix.entry(1, 1) == 2.0)
        #expect(matrix.entry(2, 2) == 1.0) // z is always 1
    }

    @Test("toMatrix with dpr 3.5 scales by 3.5")
    func testToMatrixScale3_5() {
        let config = RenderViewConfiguration(devicePixelRatio: 3.5)
        let matrix = config.toMatrix()
        #expect(matrix.entry(0, 0) == 3.5)
        #expect(matrix.entry(1, 1) == 3.5)
    }
}

// =============================================================================
// MARK: - RenderViewConfiguration shouldUpdateMatrix Tests
// =============================================================================

@Suite("RenderViewConfiguration shouldUpdateMatrix Tests")
struct RenderViewConfigurationShouldUpdateMatrixTests {

    @Test("shouldUpdateMatrix returns false for same dpr")
    func testShouldNotUpdate() {
        let a = RenderViewConfiguration(devicePixelRatio: 2.0)
        let b = RenderViewConfiguration(devicePixelRatio: 2.0)
        #expect(a.shouldUpdateMatrix(b) == false)
    }

    @Test("shouldUpdateMatrix returns true for different dpr")
    func testShouldUpdate() {
        let a = RenderViewConfiguration(devicePixelRatio: 2.0)
        let b = RenderViewConfiguration(devicePixelRatio: 3.0)
        #expect(a.shouldUpdateMatrix(b) == true)
    }

    @Test("shouldUpdateMatrix ignores constraint differences")
    func testShouldNotUpdateDifferentConstraints() {
        let a = RenderViewConfiguration(
            logicalConstraints: BoxConstraints(maxWidth: 100, maxHeight: 200),
            devicePixelRatio: 2.0
        )
        let b = RenderViewConfiguration(
            logicalConstraints: BoxConstraints(maxWidth: 400, maxHeight: 800),
            devicePixelRatio: 2.0
        )
        // Same dpr, different constraints => no matrix update needed
        #expect(a.shouldUpdateMatrix(b) == false)
    }
}

// =============================================================================
// MARK: - RenderViewConfiguration toPhysicalSize Tests
// =============================================================================

@Suite("RenderViewConfiguration toPhysicalSize Tests")
struct RenderViewConfigurationToPhysicalSizeTests {

    @Test("toPhysicalSize multiplies by dpr")
    func testToPhysicalSize() {
        let physical = BoxConstraints(
            minWidth: 0, maxWidth: 800, minHeight: 0, maxHeight: 1600
        )
        let config = RenderViewConfiguration(
            physicalConstraints: physical,
            devicePixelRatio: 2.0
        )
        let result = config.toPhysicalSize(Size(200, 300))
        // 200 * 2 = 400, 300 * 2 = 600 (both within physical constraints)
        #expect(result.width == 400.0)
        #expect(result.height == 600.0)
    }

    @Test("toPhysicalSize constrains to physical constraints")
    func testToPhysicalSizeConstrained() {
        let physical = BoxConstraints(
            minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 200
        )
        let config = RenderViewConfiguration(
            physicalConstraints: physical,
            devicePixelRatio: 2.0
        )
        // 200 * 2 = 400 which exceeds maxWidth=100
        let result = config.toPhysicalSize(Size(200, 300))
        #expect(result.width == 100.0)
        #expect(result.height == 200.0)
    }

    @Test("toPhysicalSize with dpr 1.0")
    func testToPhysicalSizeDPR1() {
        let physical = BoxConstraints(
            minWidth: 0, maxWidth: 1000, minHeight: 0, maxHeight: 1000
        )
        let config = RenderViewConfiguration(
            physicalConstraints: physical,
            devicePixelRatio: 1.0
        )
        let result = config.toPhysicalSize(Size(300, 400))
        #expect(result.width == 300.0)
        #expect(result.height == 400.0)
    }
}

// =============================================================================
// MARK: - RenderViewConfiguration Description Tests
// =============================================================================

@Suite("RenderViewConfiguration Description Tests")
struct RenderViewConfigurationDescriptionTests {

    @Test("Description contains constraints and dpr")
    func testDescription() {
        let config = RenderViewConfiguration(devicePixelRatio: 2.0)
        let desc = config.description
        #expect(desc.contains("2"))
        #expect(desc.contains("x"))
    }

    @Test("Description for default configuration")
    func testDefaultDescription() {
        let config = RenderViewConfiguration()
        let desc = config.description
        // Should contain "1" for the 1.0x dpr and "x"
        #expect(desc.contains("x"))
    }
}

// =============================================================================
// MARK: - RenderView Construction Tests
// =============================================================================

@Suite("RenderView Construction Tests")
struct RenderViewConstructionTests {

    @Test("Construction with FlutterView")
    func testConstruction() {
        let view = ensureImplicitView()
        let renderView = RenderView(view: view)
        #expect(renderView.flutterView === view)
        #expect(renderView.child == nil)
    }

    @Test("Construction with configuration")
    func testConstructionWithConfiguration() {
        let view = ensureImplicitView()
        let config = RenderViewConfiguration(devicePixelRatio: 2.0)
        let renderView = RenderView(configuration: config, view: view)
        #expect(renderView.hasConfiguration == true)
        #expect(renderView.configuration.devicePixelRatio == 2.0)
    }

    @Test("Construction without configuration")
    func testConstructionWithoutConfiguration() {
        let view = ensureImplicitView()
        let renderView = RenderView(view: view)
        #expect(renderView.hasConfiguration == false)
    }

    @Test("Construction with child")
    func testConstructionWithChild() {
        let view = ensureImplicitView()
        let child = FixedSizeRenderBox()
        let renderView = RenderView(child: child, view: view)
        #expect(renderView.child === child)
    }
}

// =============================================================================
// MARK: - RenderView Configuration Property Tests
// =============================================================================

@Suite("RenderView Configuration Property Tests")
struct RenderViewConfigurationPropertyTests {

    @Test("Setting configuration updates hasConfiguration")
    func testSetConfiguration() {
        let view = ensureImplicitView()
        let renderView = RenderView(view: view)
        #expect(renderView.hasConfiguration == false)
        renderView.configuration = RenderViewConfiguration(devicePixelRatio: 2.0)
        #expect(renderView.hasConfiguration == true)
    }

    @Test("Setting same configuration is no-op")
    func testSetSameConfiguration() {
        let view = ensureImplicitView()
        let config = RenderViewConfiguration(devicePixelRatio: 2.0)
        let renderView = RenderView(configuration: config, view: view)
        renderView.configuration = config // same value
        #expect(renderView.configuration == config)
    }

    @Test("Configuration getter returns set value")
    func testConfigurationGetter() {
        let view = ensureImplicitView()
        let config = RenderViewConfiguration(
            physicalConstraints: BoxConstraints(maxWidth: 800, maxHeight: 1200),
            logicalConstraints: BoxConstraints(maxWidth: 400, maxHeight: 600),
            devicePixelRatio: 2.0
        )
        let renderView = RenderView(configuration: config, view: view)
        #expect(renderView.configuration.devicePixelRatio == 2.0)
        #expect(renderView.configuration.logicalConstraints.maxWidth == 400)
    }
}

// =============================================================================
// MARK: - RenderView Child Management Tests
// =============================================================================

@Suite("RenderView Child Management Tests")
struct RenderViewChildManagementTests {

    @Test("Setting child to a new RenderBox")
    func testSetChild() {
        let view = ensureImplicitView()
        let renderView = RenderView(view: view)
        let child = FixedSizeRenderBox()
        renderView.child = child
        #expect(renderView.child === child)
    }

    @Test("Setting child to nil removes child")
    func testRemoveChild() {
        let view = ensureImplicitView()
        let child = FixedSizeRenderBox()
        let renderView = RenderView(child: child, view: view)
        #expect(renderView.child != nil)
        renderView.child = nil
        #expect(renderView.child == nil)
    }

    @Test("Replacing child updates child reference")
    func testReplaceChild() {
        let view = ensureImplicitView()
        let child1 = FixedSizeRenderBox(width: 100, height: 200)
        let child2 = FixedSizeRenderBox(width: 300, height: 400)
        let renderView = RenderView(child: child1, view: view)
        #expect(renderView.child === child1)
        renderView.child = child2
        #expect(renderView.child === child2)
    }

    @Test("Setting child marks needs layout")
    func testChildMarksNeedsLayout() {
        let view = ensureImplicitView()
        let renderView = RenderView(view: view)
        renderView.child = FixedSizeRenderBox()
        #expect(renderView.needsLayout == true)
    }
}

// =============================================================================
// MARK: - RenderView Size Tests
// =============================================================================

@Suite("RenderView Size Tests")
struct RenderViewSizeTests {

    @Test("Initial size is zero")
    func testInitialSize() {
        let view = ensureImplicitView()
        let renderView = RenderView(view: view)
        #expect(renderView.size == .zero)
    }
}

// =============================================================================
// MARK: - RenderView isRepaintBoundary Tests
// =============================================================================

@Suite("RenderView isRepaintBoundary Tests")
struct RenderViewRepaintBoundaryTests {

    @Test("isRepaintBoundary is always true")
    func testIsRepaintBoundary() {
        let view = ensureImplicitView()
        let renderView = RenderView(view: view)
        #expect(renderView.isRepaintBoundary == true)
    }
}

// =============================================================================
// MARK: - RenderView FlutterView Tests
// =============================================================================

@Suite("RenderView FlutterView Tests")
struct RenderViewFlutterViewTests {

    @Test("flutterView returns the view passed to constructor")
    func testFlutterView() {
        let view = ensureImplicitView()
        let renderView = RenderView(view: view)
        #expect(renderView.flutterView === view)
    }
}

// =============================================================================
// MARK: - RenderView automaticSystemUiAdjustment Tests
// =============================================================================

@Suite("RenderView automaticSystemUiAdjustment Tests")
struct RenderViewAutomaticSystemUiAdjustmentTests {

    @Test("automaticSystemUiAdjustment defaults to true")
    func testDefault() {
        let view = ensureImplicitView()
        let renderView = RenderView(view: view)
        #expect(renderView.automaticSystemUiAdjustment == true)
    }

    @Test("automaticSystemUiAdjustment can be set to false")
    func testSetFalse() {
        let view = ensureImplicitView()
        let renderView = RenderView(view: view)
        renderView.automaticSystemUiAdjustment = false
        #expect(renderView.automaticSystemUiAdjustment == false)
    }
}

// =============================================================================
// MARK: - RenderView Layer Tests
// =============================================================================

@Suite("RenderView Layer Tests")
struct RenderViewLayerTests {

    @Test("Layer is nil before prepareInitialFrame")
    func testLayerNilInitially() {
        let view = ensureImplicitView()
        let renderView = RenderView(view: view)
        #expect(renderView.layer == nil)
    }
}

// =============================================================================
// MARK: - RenderViewConfiguration fromView Tests
// =============================================================================

@Suite("RenderViewConfiguration fromView Tests")
struct RenderViewConfigurationFromViewTests {

    @Test("fromView creates configuration from FlutterView")
    func testFromView() {
        let view = ensureImplicitView()
        let config = RenderViewConfiguration.fromView(view)
        #expect(config.devicePixelRatio == view.devicePixelRatio)
    }

    @Test("fromView physical constraints match view constraints")
    func testFromViewPhysicalConstraints() {
        let view = ensureImplicitView()
        let config = RenderViewConfiguration.fromView(view)
        let expected = BoxConstraints.fromViewConstraints(view.physicalConstraints)
        #expect(config.physicalConstraints == expected)
    }

    @Test("fromView logical constraints are physical divided by dpr")
    func testFromViewLogicalConstraints() {
        let view = ensureImplicitView()
        let config = RenderViewConfiguration.fromView(view)
        let physicalConstraints = BoxConstraints.fromViewConstraints(view.physicalConstraints)
        let expectedLogical = physicalConstraints / view.devicePixelRatio
        #expect(config.logicalConstraints == expectedLogical)
    }
}
