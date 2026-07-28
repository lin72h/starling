// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Testing
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for ImageFiltered widget and _ImageFilterRenderObject.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/image_filter.dart`

// MARK: - Test Helpers

/// A minimal concrete ImageFilter for testing purposes.
/// Note: toNativeImageFilter() is not called in tests since it requires the C++ bridge.
private struct TestImageFilter: ImageFilter {
    var sigmaX: Double
    var sigmaY: Double

    init(sigmaX: Double = 1.0, sigmaY: Double = 1.0) {
        self.sigmaX = sigmaX
        self.sigmaY = sigmaY
    }

    func toNativeImageFilter() -> NativeImageFilter {
        fatalError("TestImageFilter.toNativeImageFilter() should not be called in tests")
    }

    public var shortDescription: String {
        return "testBlur(\(sigmaX), \(sigmaY))"
    }

    var description: String {
        return "TestImageFilter(\(sigmaX), \(sigmaY))"
    }

    static func == (lhs: TestImageFilter, rhs: TestImageFilter) -> Bool {
        return lhs.sigmaX == rhs.sigmaX && lhs.sigmaY == rhs.sigmaY
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(sigmaX)
        hasher.combine(sigmaY)
    }
}

/// A dummy Widget for use as a child.
private class DummyWidget: Widget {
    init() { super.init(key: nil) }
    override func createElement() -> Element {
        return Element(self)
    }
}

/// A mock BuildContext for use with createRenderObject.
private class MockBuildContext: Element {
    init() { super.init(Widget()) }
}

// MARK: - ImageFiltered Construction Tests

@Suite("ImageFiltered Construction")
struct ImageFilteredConstructionTests {

    @Test("Construction with all parameters")
    func constructionWithAllParameters() {
        let key = ValueKey<String>("test-key")
        let filter = TestImageFilter(sigmaX: 2.0, sigmaY: 3.0)
        let child = DummyWidget()
        let widget = ImageFiltered(key: key, imageFilter: filter, child: child, enabled: false)

        #expect(widget.key != nil)
        #expect(widget.enabled == false)
        #expect(widget.child != nil)
        #expect(widget.child === child)
    }

    @Test("Construction with defaults (enabled=true, child=nil)")
    func constructionWithDefaults() {
        let filter = TestImageFilter()
        let widget = ImageFiltered(imageFilter: filter)

        #expect(widget.key == nil)
        #expect(widget.enabled == true)
        #expect(widget.child == nil)
    }

    @Test("imageFilter property stores correct filter")
    func imageFilterProperty() {
        let filter = TestImageFilter(sigmaX: 5.0, sigmaY: 10.0)
        let widget = ImageFiltered(imageFilter: filter)

        // Verify by converting to AnyHashable and comparing
        #expect(AnyHashable(widget.imageFilter) == AnyHashable(filter))
    }

    @Test("enabled property returns true by default")
    func enabledDefaultTrue() {
        let filter = TestImageFilter()
        let widget = ImageFiltered(imageFilter: filter)
        #expect(widget.enabled == true)
    }

    @Test("enabled property returns false when explicitly set")
    func enabledExplicitlyFalse() {
        let filter = TestImageFilter()
        let widget = ImageFiltered(imageFilter: filter, enabled: false)
        #expect(widget.enabled == false)
    }

    @Test("child property inherited from SingleChildRenderObjectWidget")
    func childProperty() {
        let filter = TestImageFilter()
        let child = DummyWidget()
        let widget = ImageFiltered(imageFilter: filter, child: child)
        #expect(widget.child === child)
    }

    @Test("key property stores value key")
    func keyProperty() {
        let key = ValueKey<String>("image-filter-key")
        let filter = TestImageFilter()
        let widget = ImageFiltered(key: key, imageFilter: filter)
        #expect(widget.key != nil)
    }

    @Test("key property is nil when not provided")
    func keyNilWhenNotProvided() {
        let filter = TestImageFilter()
        let widget = ImageFiltered(imageFilter: filter)
        #expect(widget.key == nil)
    }
}

// MARK: - ImageFiltered Inheritance Tests

@Suite("ImageFiltered Inheritance")
struct ImageFilteredInheritanceTests {

    @Test("ImageFiltered is a SingleChildRenderObjectWidget")
    func isSingleChildRenderObjectWidget() {
        let filter = TestImageFilter()
        let widget = ImageFiltered(imageFilter: filter)
        #expect(widget is SingleChildRenderObjectWidget)
    }

    @Test("ImageFiltered is a RenderObjectWidget")
    func isRenderObjectWidget() {
        let filter = TestImageFilter()
        let widget = ImageFiltered(imageFilter: filter)
        #expect(widget is RenderObjectWidget)
    }

    @Test("ImageFiltered is a Widget")
    func isWidget() {
        let filter = TestImageFilter()
        let widget = ImageFiltered(imageFilter: filter)
        #expect(widget is Widget)
    }
}

// MARK: - ImageFiltered createRenderObject Tests

@Suite("ImageFiltered createRenderObject")
struct ImageFilteredCreateRenderObjectTests {

    @Test("createRenderObject returns a RenderObject")
    func createRenderObjectReturnsRenderObject() {
        let filter = TestImageFilter()
        let widget = ImageFiltered(imageFilter: filter)
        let context = MockBuildContext()
        let renderObject = widget.createRenderObject(context)
        #expect(renderObject is RenderObject)
    }

    @Test("createRenderObject returns _ImageFilterRenderObject")
    func createRenderObjectReturnsImageFilterRenderObject() {
        let filter = TestImageFilter()
        let widget = ImageFiltered(imageFilter: filter)
        let context = MockBuildContext()
        let renderObject = widget.createRenderObject(context)
        #expect(renderObject is _ImageFilterRenderObject)
    }

    @Test("createRenderObject passes enabled=true by default")
    func createRenderObjectDefaultEnabled() {
        let filter = TestImageFilter()
        let widget = ImageFiltered(imageFilter: filter)
        let context = MockBuildContext()
        let renderObject = widget.createRenderObject(context) as! _ImageFilterRenderObject
        #expect(renderObject.enabled == true)
    }

    @Test("createRenderObject passes enabled=false when set")
    func createRenderObjectDisabled() {
        let filter = TestImageFilter()
        let widget = ImageFiltered(imageFilter: filter, enabled: false)
        let context = MockBuildContext()
        let renderObject = widget.createRenderObject(context) as! _ImageFilterRenderObject
        #expect(renderObject.enabled == false)
    }

    @Test("createRenderObject passes the imageFilter")
    func createRenderObjectPassesFilter() {
        let filter = TestImageFilter(sigmaX: 7.0, sigmaY: 8.0)
        let widget = ImageFiltered(imageFilter: filter)
        let context = MockBuildContext()
        let renderObject = widget.createRenderObject(context) as! _ImageFilterRenderObject
        #expect(AnyHashable(renderObject.imageFilter) == AnyHashable(filter))
    }
}

// MARK: - _ImageFilterRenderObject Tests

@Suite("_ImageFilterRenderObject")
struct ImageFilterRenderObjectTests {

    @Test("Construction and property access")
    func constructionAndPropertyAccess() {
        let filter = TestImageFilter(sigmaX: 3.0, sigmaY: 4.0)
        let renderObject = _ImageFilterRenderObject(filter, true)
        #expect(renderObject.enabled == true)
        #expect(AnyHashable(renderObject.imageFilter) == AnyHashable(filter))
    }

    @Test("enabled getter returns initial value")
    func enabledGetterTrue() {
        let filter = TestImageFilter()
        let renderObject = _ImageFilterRenderObject(filter, true)
        #expect(renderObject.enabled == true)
    }

    @Test("enabled getter returns false when constructed disabled")
    func enabledGetterFalse() {
        let filter = TestImageFilter()
        let renderObject = _ImageFilterRenderObject(filter, false)
        #expect(renderObject.enabled == false)
    }

    @Test("enabled setter updates value")
    func enabledSetter() {
        let filter = TestImageFilter()
        let renderObject = _ImageFilterRenderObject(filter, true)
        #expect(renderObject.enabled == true)
        renderObject.enabled = false
        #expect(renderObject.enabled == false)
    }

    @Test("enabled setter with same value does not change")
    func enabledSetterSameValue() {
        let filter = TestImageFilter()
        let renderObject = _ImageFilterRenderObject(filter, true)
        renderObject.enabled = true // same value, should be no-op
        #expect(renderObject.enabled == true)
    }

    @Test("imageFilter getter returns initial value")
    func imageFilterGetter() {
        let filter = TestImageFilter(sigmaX: 5.0, sigmaY: 6.0)
        let renderObject = _ImageFilterRenderObject(filter, true)
        #expect(AnyHashable(renderObject.imageFilter) == AnyHashable(filter))
    }

    @Test("imageFilter setter updates value")
    func imageFilterSetter() {
        let filter1 = TestImageFilter(sigmaX: 1.0, sigmaY: 1.0)
        let filter2 = TestImageFilter(sigmaX: 2.0, sigmaY: 2.0)
        let renderObject = _ImageFilterRenderObject(filter1, true)
        renderObject.imageFilter = filter2
        #expect(AnyHashable(renderObject.imageFilter) == AnyHashable(filter2))
    }

    @Test("imageFilter setter with same value does not change")
    func imageFilterSetterSameValue() {
        let filter = TestImageFilter(sigmaX: 3.0, sigmaY: 3.0)
        let renderObject = _ImageFilterRenderObject(filter, true)
        renderObject.imageFilter = TestImageFilter(sigmaX: 3.0, sigmaY: 3.0) // equal value
        #expect(AnyHashable(renderObject.imageFilter) == AnyHashable(filter))
    }

    @Test("alwaysNeedsCompositing is false when no child and enabled")
    func alwaysNeedsCompositingNoChildEnabled() {
        let filter = TestImageFilter()
        let renderObject = _ImageFilterRenderObject(filter, true)
        // No child set, so alwaysNeedsCompositing should be false
        #expect(renderObject.alwaysNeedsCompositing == false)
    }

    @Test("alwaysNeedsCompositing is false when not enabled")
    func alwaysNeedsCompositingDisabled() {
        let filter = TestImageFilter()
        let renderObject = _ImageFilterRenderObject(filter, false)
        #expect(renderObject.alwaysNeedsCompositing == false)
    }

    @Test("isRepaintBoundary matches alwaysNeedsCompositing")
    func isRepaintBoundaryMatchesAlwaysNeedsCompositing() {
        let filter = TestImageFilter()
        let renderObject = _ImageFilterRenderObject(filter, true)
        #expect(renderObject.isRepaintBoundary == renderObject.alwaysNeedsCompositing)
    }

    @Test("isRepaintBoundary is false when no child")
    func isRepaintBoundaryFalseNoChild() {
        let filter = TestImageFilter()
        let renderObject = _ImageFilterRenderObject(filter, true)
        #expect(renderObject.isRepaintBoundary == false)
    }

    @Test("isRepaintBoundary is false when disabled")
    func isRepaintBoundaryFalseDisabled() {
        let filter = TestImageFilter()
        let renderObject = _ImageFilterRenderObject(filter, false)
        #expect(renderObject.isRepaintBoundary == false)
    }

    @Test("_ImageFilterRenderObject is a RenderProxyBox")
    func isRenderProxyBox() {
        let filter = TestImageFilter()
        let renderObject = _ImageFilterRenderObject(filter, true)
        #expect(renderObject is RenderProxyBox)
    }

    @Test("_ImageFilterRenderObject is a RenderObject")
    func isRenderObject() {
        let filter = TestImageFilter()
        let renderObject = _ImageFilterRenderObject(filter, true)
        #expect(renderObject is RenderObject)
    }
}

// MARK: - ImageFiltered updateRenderObject Tests

@Suite("ImageFiltered updateRenderObject")
struct ImageFilteredUpdateRenderObjectTests {

    @Test("updateRenderObject updates enabled on render object")
    func updateEnabled() {
        let filter = TestImageFilter()
        let widget1 = ImageFiltered(imageFilter: filter, enabled: true)
        let widget2 = ImageFiltered(imageFilter: filter, enabled: false)
        let context = MockBuildContext()

        let renderObject = widget1.createRenderObject(context) as! _ImageFilterRenderObject
        #expect(renderObject.enabled == true)

        widget2.updateRenderObject(context, renderObject: renderObject)
        #expect(renderObject.enabled == false)
    }

    @Test("updateRenderObject updates imageFilter on render object")
    func updateImageFilter() {
        let filter1 = TestImageFilter(sigmaX: 1.0, sigmaY: 1.0)
        let filter2 = TestImageFilter(sigmaX: 5.0, sigmaY: 5.0)
        let widget1 = ImageFiltered(imageFilter: filter1)
        let widget2 = ImageFiltered(imageFilter: filter2)
        let context = MockBuildContext()

        let renderObject = widget1.createRenderObject(context) as! _ImageFilterRenderObject
        #expect(AnyHashable(renderObject.imageFilter) == AnyHashable(filter1))

        widget2.updateRenderObject(context, renderObject: renderObject)
        #expect(AnyHashable(renderObject.imageFilter) == AnyHashable(filter2))
    }
}

// MARK: - ImageFiltered with GaussianBlurImageFilter Tests

@Suite("ImageFiltered with GaussianBlurImageFilter")
struct ImageFilteredWithGaussianBlurTests {

    @Test("Construction with GaussianBlurImageFilter")
    func constructionWithGaussianBlur() {
        let blur = GaussianBlurImageFilter(sigmaX: 5.0, sigmaY: 5.0, tileMode: nil)
        let widget = ImageFiltered(imageFilter: blur)
        #expect(widget.enabled == true)
        #expect(AnyHashable(widget.imageFilter) == AnyHashable(blur))
    }

    @Test("createRenderObject with GaussianBlurImageFilter")
    func createRenderObjectWithGaussianBlur() {
        let blur = GaussianBlurImageFilter(sigmaX: 2.0, sigmaY: 3.0, tileMode: nil)
        let widget = ImageFiltered(imageFilter: blur)
        let context = MockBuildContext()
        let renderObject = widget.createRenderObject(context)
        #expect(renderObject is _ImageFilterRenderObject)
        let filterRO = renderObject as! _ImageFilterRenderObject
        #expect(AnyHashable(filterRO.imageFilter) == AnyHashable(blur))
    }
}

// MARK: - ImageFiltered with DilateImageFilter Tests

@Suite("ImageFiltered with DilateImageFilter")
struct ImageFilteredWithDilateTests {

    @Test("Construction with DilateImageFilter")
    func constructionWithDilate() {
        let dilate = DilateImageFilter(radiusX: 3.0, radiusY: 4.0)
        let widget = ImageFiltered(imageFilter: dilate)
        #expect(AnyHashable(widget.imageFilter) == AnyHashable(dilate))
    }
}
