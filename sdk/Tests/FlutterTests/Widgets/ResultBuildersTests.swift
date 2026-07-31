// Tests for the trailing-closure widget-composition overlay.
//
// This file has no Dart counterpart — `ResultBuilders.swift` is a Swift-only
// addition (see the header there). The property under test throughout is that
// the builder spelling produces exactly the tree the ported `children:` /
// `child:` spelling produces, so both can coexist indefinitely.

import XCTest
@testable import Flutter

final class ResultBuildersTests: XCTestCase {

    // MARK: - Test helpers

    private class A: Widget {}
    private class B: Widget {}
    private class C: Widget {}

    /// Compares two child lists by concrete widget type, which is what
    /// `Widget.canUpdate` keys on alongside the key.
    private func types(_ widgets: [Widget]) -> [String] {
        return widgets.map { String(describing: type(of: $0)) }
    }

    // MARK: - ChildrenBuilder: the array form and the block form agree

    func testBlockMatchesArrayForm() {
        let viaArray = Column(children: [A(), B(), C()])
        let viaBlock = Column {
            A()
            B()
            C()
        }
        XCTAssertEqual(types(viaArray.children), types(viaBlock.children))
        XCTAssertEqual(viaBlock.children.count, 3)
    }

    func testBuilderPreservesNonChildParameters() {
        let column = Column(
            mainAxisAlignment: .spaceBetween,
            mainAxisSize: .min,
            crossAxisAlignment: .end,
            spacing: 7.0
        ) {
            A()
        }
        XCTAssertEqual(column.mainAxisAlignment, .spaceBetween)
        XCTAssertEqual(column.mainAxisSize, .min)
        XCTAssertEqual(column.crossAxisAlignment, .end)
        XCTAssertEqual(column.spacing, 7.0)
        XCTAssertEqual(column.direction, .vertical)
        XCTAssertEqual(column.children.count, 1)
    }

    func testKeyIsForwarded() {
        let key = ValueKey("k")
        let column = Column(key: key) { A() }
        XCTAssertNotNil(column.key)
    }

    // MARK: - Conditionals

    func testIfIncludesChildWhenTrue() {
        let column = Column {
            A()
            if true { B() }
        }
        XCTAssertEqual(types(column.children), ["A", "B"])
    }

    /// The point of the exercise: a false `if` contributes *no* child, rather
    /// than a placeholder that stays in the tree as a live element.
    func testIfOmitsChildEntirelyWhenFalse() {
        let column = Column {
            A()
            if false { B() }
        }
        XCTAssertEqual(types(column.children), ["A"])
        XCTAssertEqual(column.children.count, 1)
    }

    func testIfElseSelectsBranch() {
        func build(_ flag: Bool) -> Column {
            return Column {
                if flag { A() } else { B() }
            }
        }
        XCTAssertEqual(types(build(true).children), ["A"])
        XCTAssertEqual(types(build(false).children), ["B"])
    }

    func testSwitchSelectsBranch() {
        func build(_ n: Int) -> Column {
            return Column {
                switch n {
                case 0: A()
                case 1: B()
                default: C()
                }
            }
        }
        XCTAssertEqual(types(build(0).children), ["A"])
        XCTAssertEqual(types(build(1).children), ["B"])
        XCTAssertEqual(types(build(9).children), ["C"])
    }

    func testNestedConditionals() {
        func build(_ outer: Bool, _ inner: Bool) -> Column {
            return Column {
                if outer {
                    A()
                    if inner { B() }
                }
                C()
            }
        }
        XCTAssertEqual(types(build(true, true).children), ["A", "B", "C"])
        XCTAssertEqual(types(build(true, false).children), ["A", "C"])
        XCTAssertEqual(types(build(false, false).children), ["C"])
    }

    // MARK: - Loops

    func testForLoopContributesOneChildPerIteration() {
        let column = Column {
            for _ in 0..<3 { A() }
        }
        XCTAssertEqual(types(column.children), ["A", "A", "A"])
    }

    func testEmptyLoopContributesNothing() {
        let column = Column {
            for _ in 0..<0 { A() }
        }
        XCTAssertTrue(column.children.isEmpty)
    }

    /// The separator idiom that previously forced an imperative `var rows`
    /// above the tree.
    func testLoopWithInterleavedSeparators() {
        let items = ["x", "y", "z"]
        let column = Column {
            for (i, _) in items.enumerated() {
                if i > 0 { B() }
                A()
            }
        }
        XCTAssertEqual(types(column.children), ["A", "B", "A", "B", "A"])
    }

    func testLoopBodyWithConditional() {
        let column = Column {
            for i in 0..<4 {
                if i.isMultiple(of: 2) { A() } else { B() }
            }
        }
        XCTAssertEqual(types(column.children), ["A", "B", "A", "B"])
    }

    // MARK: - Splicing existing helpers

    func testArrayExpressionSplicesInPlace() {
        let existing: [Widget] = [A(), B()]
        let column = Column {
            C()
            existing
            C()
        }
        XCTAssertEqual(types(column.children), ["C", "A", "B", "C"])
    }

    func testEmptyArraySplicesNothing() {
        let empty: [Widget] = []
        let column = Column {
            A()
            empty
        }
        XCTAssertEqual(types(column.children), ["A"])
    }

    func testOptionalWidgetExpression() {
        let present: Widget? = A()
        let absent: Widget? = nil
        let column = Column {
            present
            absent
            B()
        }
        XCTAssertEqual(types(column.children), ["A", "B"])
    }

    func testEmptyBlockProducesNoChildren() {
        let column = Column {}
        XCTAssertTrue(column.children.isEmpty)
    }

    /// `map` over a model list yields `[ConcreteWidget]`, not `[Widget]`. This
    /// is the single most common shape in the app code the feature is for, so
    /// the array-splicing overload has to accept it through covariance.
    func testMapProducingSubclassArraySplices() {
        let items = [1, 2, 3]
        let column = Column {
            items.map { _ in A() }
        }
        XCTAssertEqual(types(column.children), ["A", "A", "A"])
    }

    func testMapMixedWithLiteralChildren() {
        let items = [1, 2]
        let column = Column {
            C()
            items.map { _ in A() }
            C()
        }
        XCTAssertEqual(types(column.children), ["C", "A", "A", "C"])
    }

    func testFlatMapProducingInterleavedSeparators() {
        let items = [1, 2, 3]
        let column = Column {
            items.enumerated().flatMap { (i, _) -> [Widget] in
                return i > 0 ? [B(), A()] : [A()]
            }
        }
        XCTAssertEqual(types(column.children), ["A", "B", "A", "B", "A"])
    }

    // MARK: - Coverage across multi-child widgets

    func testRowBuilder() {
        let row = Row(mainAxisAlignment: .center) { A(); B() }
        XCTAssertEqual(types(row.children), ["A", "B"])
        XCTAssertEqual(row.direction, .horizontal)
        XCTAssertEqual(row.mainAxisAlignment, .center)
    }

    func testFlexBuilderKeepsRequiredDirection() {
        let flex = Flex(direction: .horizontal) { A() }
        XCTAssertEqual(flex.direction, .horizontal)
        XCTAssertEqual(flex.children.count, 1)
    }

    func testStackBuilder() {
        let stack = Stack(fit: .expand) { A(); B() }
        XCTAssertEqual(types(stack.children), ["A", "B"])
        XCTAssertEqual(stack.fit, .expand)
    }

    func testIndexedStackBuilder() {
        let stack = IndexedStack(index: 1) { A(); B() }
        XCTAssertEqual(types(stack.stackChildren), ["A", "B"])
        XCTAssertEqual(stack.index, 1)
    }

    func testWrapBuilder() {
        let wrap = Wrap(spacing: 12, runSpacing: 4) { A(); B(); C() }
        XCTAssertEqual(types(wrap.children), ["A", "B", "C"])
        XCTAssertEqual(wrap.spacing, 12)
        XCTAssertEqual(wrap.runSpacing, 4)
    }

    func testListBodyBuilder() {
        let body = ListBody(mainAxis: .horizontal) { A() }
        XCTAssertEqual(body.mainAxis, .horizontal)
        XCTAssertEqual(body.children.count, 1)
    }

    // MARK: - ChildBuilder: single child

    func testSingleChildBlockMatchesChildParameter() {
        let viaParam = Center(child: A())
        let viaBlock = Center { A() }
        XCTAssertEqual(
            String(describing: type(of: viaParam.child!)),
            String(describing: type(of: viaBlock.child!))
        )
    }

    func testSingleChildPreservesOtherParameters() {
        let padded = Padding(padding: EdgeInsets(all: 8)) { A() }
        XCTAssertNotNil(padded.child)
        XCTAssertEqual(padded.padding as? EdgeInsets, EdgeInsets(all: 8))
    }

    func testSingleChildIfElse() {
        func build(_ flag: Bool) -> Center {
            return Center {
                if flag { A() } else { B() }
            }
        }
        XCTAssertEqual(String(describing: type(of: build(true).child!)), "A")
        XCTAssertEqual(String(describing: type(of: build(false).child!)), "B")
    }

    func testNestedSingleChildBuilders() {
        let tree = Center {
            Padding(padding: EdgeInsets(all: 4)) {
                Opacity(opacity: 0.5) {
                    A()
                }
            }
        }
        let padding = tree.child as? Padding
        XCTAssertNotNil(padding)
        let opacity = padding?.child as? Opacity
        XCTAssertNotNil(opacity)
        XCTAssertEqual(opacity?.opacity, 0.5)
        XCTAssertTrue(opacity?.child is A)
    }

    func testRequiredChildWidgetsAcceptBuilder() {
        let expanded = Expanded(flex: 3) { A() }
        XCTAssertEqual(expanded.flex, 3)

        let flexible = Flexible(flex: 2, fit: .tight) { B() }
        XCTAssertEqual(flexible.flex, 2)
        XCTAssertEqual(flexible.fit, .tight)

        let positioned = Positioned(left: 10, top: 20) { C() }
        XCTAssertEqual(positioned.left, 10)
        XCTAssertEqual(positioned.top, 20)
    }

    // MARK: - Mixed trees

    func testBuilderAndArrayFormsInteroperateInOneTree() {
        let tree = Column {
            Row(children: [A(), B()])
            Row { A(); B() }
        }
        XCTAssertEqual(tree.children.count, 2)
        XCTAssertTrue(tree.children.allSatisfy { $0 is Row })
    }

    func testDeeplyNestedMixedTree() {
        let showFooter = true
        let tree = Column(crossAxisAlignment: .start) {
            Center { A() }
            Expanded {
                Row(mainAxisAlignment: .spaceBetween) {
                    for _ in 0..<2 { A() }
                    if showFooter { B() }
                }
            }
        }
        XCTAssertEqual(tree.children.count, 2)
        let expanded = tree.children[1] as? Expanded
        XCTAssertNotNil(expanded)
        let row = expanded?.child as? Row
        XCTAssertEqual(row?.children.count, 3)
    }

    // MARK: - Regression: the ported spellings still resolve

    func testPortedArrayInitializerStillCompilesAndWorks() {
        let column = Column(
            key: ValueKey("c"),
            mainAxisAlignment: .center,
            children: [A(), B()]
        )
        XCTAssertEqual(column.children.count, 2)
        XCTAssertEqual(column.mainAxisAlignment, .center)
    }

    func testPortedChildInitializerStillCompilesAndWorks() {
        let center = Center(child: A())
        XCTAssertTrue(center.child is A)

        let empty = Center()
        XCTAssertNil(empty.child)
    }

    func testWidgetCanUpdateIsBlindToSpelling() {
        let fromArray = Column(children: [A()])
        let fromBlock = Column { A() }
        XCTAssertTrue(Widget.canUpdate(fromArray, fromBlock))
        XCTAssertTrue(Widget.canUpdate(fromArray.children[0], fromBlock.children[0]))
    }
}
