// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/// Regression tests for `_SliverMultiBoxAdaptorElement` — the child manager
/// behind `ListView`/`GridView` — laying out real widget-inflated children.
///
/// The critical contract (documented by `MockChildManager` in the rendering
/// tests): a child's `parentData.index` must be stamped *before* the sliver's
/// `insert()` finishes, because `insert()` verifies child order through
/// `indexOf`, which asserts on a nil index. The element used to stamp the
/// index only after `insert()` returned, so every ListView app crashed in
/// debug builds at `SliverMultiBoxAdaptor.swift`'s `indexOf` assert (release
/// builds skipped the verification and worked). The element now stamps the
/// index in `didAdoptChild`, which the sliver calls mid-`insert()` — these
/// tests run that whole path with asserts active.

import Testing
@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - Test Helpers

/// A fixed-size leaf row, standing in for a ListView row widget.
private class SliverTestRowWidget: LeafRenderObjectWidget {
    let height: Double

    init(key: (any Key)? = nil, height: Double = 50) {
        self.height = height
        super.init(key: key)
    }

    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return SliverTestRowRenderBox(height: height)
    }

    override func updateRenderObject(_ context: any BuildContext, renderObject: RenderObject) {
        let row = renderObject as! SliverTestRowRenderBox
        if row.fixedHeight != height {
            row.fixedHeight = height
            row.markNeedsLayout()
        }
    }
}

private class SliverTestRowRenderBox: RenderBox {
    var fixedHeight: Double

    init(height: Double) {
        self.fixedHeight = height
        super.init()
    }

    override func performLayout() {
        size = boxConstraints.constrain(Size(400, fixedHeight))
    }

    override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        return constraints.constrain(Size(400, fixedHeight))
    }
}

/// Root plumbing so the sliver element can mount: a host render object that
/// accepts the sliver as its child, and a root element carrying a BuildOwner
/// (the same shape MultiChildRenderObjectElementTests uses).
private class SliverTestHostRenderObject: RenderBox, ContainerRenderObjectHost {
    private(set) var children: [RenderBox] = []

    func insert(_ child: RenderBox, after: RenderBox?) {
        children.append(child)
    }

    func remove(_ child: RenderBox) {
        children.removeAll { $0 === child }
    }

    func move(_ child: RenderBox, after: RenderBox?) {}
}

private class SliverTestHostWidget: MultiChildRenderObjectWidget {
    override init(key: (any Key)? = nil, children: [Widget] = []) {
        super.init(key: key, children: children)
    }

    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return SliverTestHostRenderObject()
    }
}

private class SliverTestRootElement: RenderObjectElement {
    init() {
        super.init(SliverTestHostWidget())
    }

    func setupOwner() {
        self.owner = BuildOwner()
        self._lifecycleState = .active
        self.renderObject = (widget as! RenderObjectWidget).createRenderObject(self)
    }
}

private func makeSliverConstraints(scrollOffset: Double = 0) -> SliverConstraints {
    SliverConstraints(
        axisDirection: .down,
        growthDirection: .forward,
        userScrollDirection: .idle,
        scrollOffset: scrollOffset,
        precedingScrollExtent: 0,
        overlap: 0,
        remainingPaintExtent: 600,
        crossAxisExtent: 400,
        crossAxisDirection: .right,
        viewportMainAxisExtent: 600,
        remainingCacheExtent: 850,
        cacheOrigin: 0
    )
}

/// Mounts the sliver widget under a fresh root and returns its element and
/// render object.
private func mountSliver(
    _ widget: SliverMultiBoxAdaptorWidget
) -> (Element, RenderSliverMultiBoxAdaptor) {
    let root = SliverTestRootElement()
    root.setupOwner()
    let element = widget.createElement()
    element.mount(root, nil)
    let sliver = element.findRenderObject() as! RenderSliverMultiBoxAdaptor
    return (element, sliver)
}

/// The children's indices in child-list order, via the parentData directly
/// (not `indexOf`, which would assert on exactly the bug being tested).
private func childIndices(_ sliver: RenderSliverMultiBoxAdaptor) -> [Int?] {
    var indices: [Int?] = []
    var child = sliver.firstChild
    while let c = child {
        let parentData = c.parentData as? SliverMultiBoxAdaptorParentData
        indices.append(parentData?.index)
        child = sliver.childAfter(c)
    }
    return indices
}

// MARK: - Tests

@Suite("SliverMultiBoxAdaptorElement Layout")
struct SliverMultiBoxAdaptorElementLayoutTests {

    @Test("SliverList layout inflates children with indices stamped")
    func sliverListLayoutStampsIndices() {
        let widget = SliverList(children: [
            SliverTestRowWidget(height: 50),
            SliverTestRowWidget(height: 50),
            SliverTestRowWidget(height: 50),
        ])
        let (_, sliver) = mountSliver(widget)

        // This layout runs addInitialChild/insertAndLayoutChild with asserts
        // active — the path that used to die in insert()'s order check.
        sliver.layout(makeSliverConstraints())

        #expect(sliver.firstChild != nil)
        let indices = childIndices(sliver)
        #expect(indices == [0, 1, 2])
        #expect(sliver.geometry!.scrollExtent == 150)
    }

    @Test("SliverFixedExtentList layout inflates children with indices stamped")
    func fixedExtentLayoutStampsIndices() {
        let widget = SliverFixedExtentList(
            children: [
                SliverTestRowWidget(height: 24),
                SliverTestRowWidget(height: 24),
            ],
            itemExtent: 24
        )
        let (_, sliver) = mountSliver(widget)

        sliver.layout(makeSliverConstraints())

        #expect(sliver.firstChild != nil)
        #expect(childIndices(sliver) == [0, 1])
        #expect(sliver.geometry!.scrollExtent == 48)
    }

    @Test("Builder delegate stamps indices too")
    func builderDelegateStampsIndices() {
        let widget = SliverList(itemCount: 4) { _, index in
            index < 4 ? SliverTestRowWidget(height: 50) : nil
        }
        let (_, sliver) = mountSliver(widget)

        sliver.layout(makeSliverConstraints())

        #expect(childIndices(sliver) == [0, 1, 2, 3])
    }

    @Test("Delegate swap relays out with indices intact")
    func delegateSwapKeepsIndices() {
        let (element, sliver) = mountSliver(SliverList(children: [
            SliverTestRowWidget(height: 50),
            SliverTestRowWidget(height: 50),
        ]))
        sliver.layout(makeSliverConstraints())
        #expect(childIndices(sliver) == [0, 1])

        // The app-side rebuild pattern: a new widget with a new delegate
        // (what a bloc-driven setState hands the list every tick).
        element.update(SliverList(children: [
            SliverTestRowWidget(height: 60),
            SliverTestRowWidget(height: 60),
        ]))
        sliver.layout(makeSliverConstraints())

        #expect(childIndices(sliver) == [0, 1])
        #expect(sliver.geometry!.scrollExtent == 120)
    }
}
