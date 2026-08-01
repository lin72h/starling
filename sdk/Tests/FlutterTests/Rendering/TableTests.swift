// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for Table layout types from the Rendering layer.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/table.dart`
///
/// These tests cover:
///   - FixedColumnWidth: returns fixed value for both min/max, nil flex
///   - FractionColumnWidth: fraction of container width, nil flex
///   - FlexColumnWidth: returns 0 for min/max, non-nil flex value
///   - IntrinsicColumnWidth: queries cells' intrinsic dimensions, optional flex
///   - MaxColumnWidth: maximum of two strategies
///   - MinColumnWidth: minimum of two strategies
///   - TableCellParentData: default values, property setting
///   - TableCellVerticalAlignment: all 6 enum cases
///   - RenderTable: construction, properties, child management, column/row resize

import XCTest
@testable import Flutter
import FlutterSwiftBridge

// MARK: - Test Helpers

/// A concrete RenderBox subclass with configurable intrinsic dimensions
/// and a fixed size for layout, used as a child in tests.
private class FixedSizeRenderBox: RenderBox {
    let fixedWidth: Double
    let fixedHeight: Double

    init(width: Double, height: Double) {
        self.fixedWidth = width
        self.fixedHeight = height
        super.init()
    }

    override func computeMinIntrinsicWidth(_ height: Double) -> Double {
        return fixedWidth
    }

    override func computeMaxIntrinsicWidth(_ height: Double) -> Double {
        return fixedWidth
    }

    override func computeMinIntrinsicHeight(_ width: Double) -> Double {
        return fixedHeight
    }

    override func computeMaxIntrinsicHeight(_ width: Double) -> Double {
        return fixedHeight
    }

    override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        return constraints.constrain(Size(fixedWidth, fixedHeight))
    }

    override func performLayout() {
        size = boxConstraints.constrain(Size(fixedWidth, fixedHeight))
    }
}

// MARK: - FixedColumnWidth Tests

final class FixedColumnWidthTests: XCTestCase {

    /// Test that FixedColumnWidth stores the provided value.
    func testStoresValue() {
        let width = FixedColumnWidth(100.0)
        XCTAssertEqual(width.value, 100.0)
    }

    /// Test that minIntrinsicWidth returns the fixed value regardless of cells or container.
    func testMinIntrinsicWidthReturnsFixedValue() {
        let width = FixedColumnWidth(150.0)
        let result = width.minIntrinsicWidth(cells: [], containerWidth: 800.0)
        XCTAssertEqual(result, 150.0)
    }

    /// Test that maxIntrinsicWidth returns the fixed value regardless of cells or container.
    func testMaxIntrinsicWidthReturnsFixedValue() {
        let width = FixedColumnWidth(150.0)
        let result = width.maxIntrinsicWidth(cells: [], containerWidth: 800.0)
        XCTAssertEqual(result, 150.0)
    }

    /// Test that minIntrinsicWidth ignores cells.
    func testMinIntrinsicWidthIgnoresCells() {
        let width = FixedColumnWidth(200.0)
        let cell = FixedSizeRenderBox(width: 500, height: 100)
        let result = width.minIntrinsicWidth(cells: [cell], containerWidth: 1000.0)
        XCTAssertEqual(result, 200.0)
    }

    /// Test that maxIntrinsicWidth ignores container width.
    func testMaxIntrinsicWidthIgnoresContainerWidth() {
        let width = FixedColumnWidth(200.0)
        let result = width.maxIntrinsicWidth(cells: [], containerWidth: .infinity)
        XCTAssertEqual(result, 200.0)
    }

    /// Test that flex returns nil (from the default extension).
    func testFlexReturnsNil() {
        let width = FixedColumnWidth(100.0)
        XCTAssertNil(width.flex(cells: []))
    }

    /// Test with zero value.
    func testZeroValue() {
        let width = FixedColumnWidth(0.0)
        XCTAssertEqual(width.minIntrinsicWidth(cells: [], containerWidth: 500.0), 0.0)
        XCTAssertEqual(width.maxIntrinsicWidth(cells: [], containerWidth: 500.0), 0.0)
    }
}

// MARK: - FractionColumnWidth Tests

final class FractionColumnWidthTests: XCTestCase {

    /// Test that FractionColumnWidth stores the provided value.
    func testStoresValue() {
        let width = FractionColumnWidth(0.25)
        XCTAssertEqual(width.value, 0.25)
    }

    /// Test that minIntrinsicWidth returns fraction of container width.
    func testMinIntrinsicWidthReturnsFractionOfContainer() {
        let width = FractionColumnWidth(0.5)
        let result = width.minIntrinsicWidth(cells: [], containerWidth: 800.0)
        XCTAssertEqual(result, 400.0)
    }

    /// Test that maxIntrinsicWidth returns fraction of container width.
    func testMaxIntrinsicWidthReturnsFractionOfContainer() {
        let width = FractionColumnWidth(0.25)
        let result = width.maxIntrinsicWidth(cells: [], containerWidth: 1000.0)
        XCTAssertEqual(result, 250.0)
    }

    /// Test that minIntrinsicWidth returns 0 when container width is infinite.
    func testMinIntrinsicWidthReturnsZeroForInfiniteContainer() {
        let width = FractionColumnWidth(0.5)
        let result = width.minIntrinsicWidth(cells: [], containerWidth: .infinity)
        XCTAssertEqual(result, 0.0)
    }

    /// Test that maxIntrinsicWidth returns 0 when container width is infinite.
    func testMaxIntrinsicWidthReturnsZeroForInfiniteContainer() {
        let width = FractionColumnWidth(0.5)
        let result = width.maxIntrinsicWidth(cells: [], containerWidth: .infinity)
        XCTAssertEqual(result, 0.0)
    }

    /// Test with 100% fraction.
    func testFullFraction() {
        let width = FractionColumnWidth(1.0)
        let result = width.minIntrinsicWidth(cells: [], containerWidth: 600.0)
        XCTAssertEqual(result, 600.0)
    }

    /// Test with zero fraction.
    func testZeroFraction() {
        let width = FractionColumnWidth(0.0)
        let result = width.minIntrinsicWidth(cells: [], containerWidth: 600.0)
        XCTAssertEqual(result, 0.0)
    }

    /// Test that flex returns nil.
    func testFlexReturnsNil() {
        let width = FractionColumnWidth(0.5)
        XCTAssertNil(width.flex(cells: []))
    }
}

// MARK: - FlexColumnWidth Tests

final class FlexColumnWidthTests: XCTestCase {

    /// Test that FlexColumnWidth defaults to value of 1.0.
    func testDefaultValue() {
        let width = FlexColumnWidth()
        XCTAssertEqual(width.value, 1.0)
    }

    /// Test that FlexColumnWidth stores a custom value.
    func testCustomValue() {
        let width = FlexColumnWidth(2.5)
        XCTAssertEqual(width.value, 2.5)
    }

    /// Test that minIntrinsicWidth always returns 0.
    func testMinIntrinsicWidthReturnsZero() {
        let width = FlexColumnWidth(3.0)
        let result = width.minIntrinsicWidth(cells: [], containerWidth: 800.0)
        XCTAssertEqual(result, 0.0)
    }

    /// Test that maxIntrinsicWidth always returns 0.
    func testMaxIntrinsicWidthReturnsZero() {
        let width = FlexColumnWidth(3.0)
        let result = width.maxIntrinsicWidth(cells: [], containerWidth: 800.0)
        XCTAssertEqual(result, 0.0)
    }

    /// Test that flex returns the stored value.
    func testFlexReturnsValue() {
        let width = FlexColumnWidth(2.0)
        let result = width.flex(cells: [])
        XCTAssertEqual(result, 2.0)
    }

    /// Test that default flex returns 1.0.
    func testDefaultFlexReturnsOne() {
        let width = FlexColumnWidth()
        let result = width.flex(cells: [])
        XCTAssertEqual(result, 1.0)
    }
}

// MARK: - IntrinsicColumnWidth Tests

final class IntrinsicColumnWidthTests: XCTestCase {

    /// Test default construction with nil flex.
    func testDefaultConstruction() {
        let width = IntrinsicColumnWidth()
        XCTAssertNil(width.flex(cells: []))
    }

    /// Test construction with custom flex value.
    func testConstructionWithFlex() {
        let width = IntrinsicColumnWidth(flex: 2.0)
        XCTAssertEqual(width.flex(cells: []), 2.0)
    }

    /// Test that minIntrinsicWidth returns max of cells' min intrinsic widths.
    func testMinIntrinsicWidthQueriesCells() {
        let cell1 = FixedSizeRenderBox(width: 50, height: 30)
        let cell2 = FixedSizeRenderBox(width: 100, height: 30)
        let cell3 = FixedSizeRenderBox(width: 75, height: 30)
        let width = IntrinsicColumnWidth()
        let result = width.minIntrinsicWidth(cells: [cell1, cell2, cell3], containerWidth: 800.0)
        XCTAssertEqual(result, 100.0)
    }

    /// Test that maxIntrinsicWidth returns max of cells' max intrinsic widths.
    func testMaxIntrinsicWidthQueriesCells() {
        let cell1 = FixedSizeRenderBox(width: 50, height: 30)
        let cell2 = FixedSizeRenderBox(width: 100, height: 30)
        let cell3 = FixedSizeRenderBox(width: 75, height: 30)
        let width = IntrinsicColumnWidth()
        let result = width.maxIntrinsicWidth(cells: [cell1, cell2, cell3], containerWidth: 800.0)
        XCTAssertEqual(result, 100.0)
    }

    /// Test that minIntrinsicWidth returns 0 for empty cells.
    func testMinIntrinsicWidthEmptyCells() {
        let width = IntrinsicColumnWidth()
        let result = width.minIntrinsicWidth(cells: [], containerWidth: 800.0)
        XCTAssertEqual(result, 0.0)
    }

    /// Test that maxIntrinsicWidth returns 0 for empty cells.
    func testMaxIntrinsicWidthEmptyCells() {
        let width = IntrinsicColumnWidth()
        let result = width.maxIntrinsicWidth(cells: [], containerWidth: 800.0)
        XCTAssertEqual(result, 0.0)
    }

    /// Test that minIntrinsicWidth with single cell returns that cell's min width.
    func testMinIntrinsicWidthSingleCell() {
        let cell = FixedSizeRenderBox(width: 120, height: 40)
        let width = IntrinsicColumnWidth()
        let result = width.minIntrinsicWidth(cells: [cell], containerWidth: 500.0)
        XCTAssertEqual(result, 120.0)
    }

    /// Test flex returns nil when not specified.
    func testFlexNilByDefault() {
        let width = IntrinsicColumnWidth()
        XCTAssertNil(width.flex(cells: []))
    }

    /// Test flex returns the specified value.
    func testFlexReturnsSpecifiedValue() {
        let width = IntrinsicColumnWidth(flex: 3.0)
        XCTAssertEqual(width.flex(cells: []), 3.0)
    }
}

// MARK: - MaxColumnWidth Tests

final class MaxColumnWidthTests: XCTestCase {

    /// Test that minIntrinsicWidth returns the max of two strategies.
    func testMinIntrinsicWidthReturnsMax() {
        let a = FixedColumnWidth(100.0)
        let b = FixedColumnWidth(200.0)
        let width = MaxColumnWidth(a, b)
        let result = width.minIntrinsicWidth(cells: [], containerWidth: 800.0)
        XCTAssertEqual(result, 200.0)
    }

    /// Test that maxIntrinsicWidth returns the max of two strategies.
    func testMaxIntrinsicWidthReturnsMax() {
        let a = FixedColumnWidth(300.0)
        let b = FixedColumnWidth(150.0)
        let width = MaxColumnWidth(a, b)
        let result = width.maxIntrinsicWidth(cells: [], containerWidth: 800.0)
        XCTAssertEqual(result, 300.0)
    }

    /// Test with FractionColumnWidth and FixedColumnWidth.
    func testMixedStrategies() {
        let fixed = FixedColumnWidth(100.0)
        let fraction = FractionColumnWidth(0.5)
        let width = MaxColumnWidth(fixed, fraction)
        // container = 800, fraction = 400, fixed = 100 => max = 400
        let result = width.minIntrinsicWidth(cells: [], containerWidth: 800.0)
        XCTAssertEqual(result, 400.0)
    }

    /// Test with small container where fixed wins.
    func testFixedWinsWithSmallContainer() {
        let fixed = FixedColumnWidth(100.0)
        let fraction = FractionColumnWidth(0.1)
        let width = MaxColumnWidth(fixed, fraction)
        // container = 200, fraction = 20, fixed = 100 => max = 100
        let result = width.minIntrinsicWidth(cells: [], containerWidth: 200.0)
        XCTAssertEqual(result, 100.0)
    }

    /// Test flex returns nil when both children have nil flex.
    func testFlexBothNil() {
        let a = FixedColumnWidth(100.0)
        let b = FixedColumnWidth(200.0)
        let width = MaxColumnWidth(a, b)
        XCTAssertNil(width.flex(cells: []))
    }

    /// Test flex returns b's flex when a is nil.
    func testFlexANilReturnsBFlex() {
        let a = FixedColumnWidth(100.0) // flex = nil
        let b = FlexColumnWidth(2.0)     // flex = 2.0
        let width = MaxColumnWidth(a, b)
        XCTAssertEqual(width.flex(cells: []), 2.0)
    }

    /// Test flex returns a's flex when b is nil.
    func testFlexBNilReturnsAFlex() {
        let a = FlexColumnWidth(3.0)      // flex = 3.0
        let b = FixedColumnWidth(200.0)   // flex = nil
        let width = MaxColumnWidth(a, b)
        XCTAssertEqual(width.flex(cells: []), 3.0)
    }

    /// Test flex returns max when both have flex.
    func testFlexBothPresentReturnsMax() {
        let a = FlexColumnWidth(2.0)
        let b = FlexColumnWidth(5.0)
        let width = MaxColumnWidth(a, b)
        XCTAssertEqual(width.flex(cells: []), 5.0)
    }

    /// Test flex returns max when a > b.
    func testFlexBothPresentAGreater() {
        let a = FlexColumnWidth(5.0)
        let b = FlexColumnWidth(2.0)
        let width = MaxColumnWidth(a, b)
        XCTAssertEqual(width.flex(cells: []), 5.0)
    }
}

// MARK: - MinColumnWidth Tests

final class MinColumnWidthTests: XCTestCase {

    /// Test that minIntrinsicWidth returns the min of two strategies.
    func testMinIntrinsicWidthReturnsMin() {
        let a = FixedColumnWidth(100.0)
        let b = FixedColumnWidth(200.0)
        let width = MinColumnWidth(a, b)
        let result = width.minIntrinsicWidth(cells: [], containerWidth: 800.0)
        XCTAssertEqual(result, 100.0)
    }

    /// Test that maxIntrinsicWidth returns the min of two strategies.
    func testMaxIntrinsicWidthReturnsMin() {
        let a = FixedColumnWidth(300.0)
        let b = FixedColumnWidth(150.0)
        let width = MinColumnWidth(a, b)
        let result = width.maxIntrinsicWidth(cells: [], containerWidth: 800.0)
        XCTAssertEqual(result, 150.0)
    }

    /// Test with FractionColumnWidth and FixedColumnWidth.
    func testMixedStrategies() {
        let fixed = FixedColumnWidth(100.0)
        let fraction = FractionColumnWidth(0.5)
        let width = MinColumnWidth(fixed, fraction)
        // container = 800, fraction = 400, fixed = 100 => min = 100
        let result = width.minIntrinsicWidth(cells: [], containerWidth: 800.0)
        XCTAssertEqual(result, 100.0)
    }

    /// Test with large container where fixed wins.
    func testFractionWinsWithSmallContainer() {
        let fixed = FixedColumnWidth(100.0)
        let fraction = FractionColumnWidth(0.1)
        let width = MinColumnWidth(fixed, fraction)
        // container = 200, fraction = 20, fixed = 100 => min = 20
        let result = width.minIntrinsicWidth(cells: [], containerWidth: 200.0)
        XCTAssertEqual(result, 20.0)
    }

    /// Test flex returns nil when both children have nil flex.
    func testFlexBothNil() {
        let a = FixedColumnWidth(100.0)
        let b = FixedColumnWidth(200.0)
        let width = MinColumnWidth(a, b)
        XCTAssertNil(width.flex(cells: []))
    }

    /// Test flex returns b's flex when a is nil.
    func testFlexANilReturnsBFlex() {
        let a = FixedColumnWidth(100.0)
        let b = FlexColumnWidth(2.0)
        let width = MinColumnWidth(a, b)
        XCTAssertEqual(width.flex(cells: []), 2.0)
    }

    /// Test flex returns a's flex when b is nil.
    func testFlexBNilReturnsAFlex() {
        let a = FlexColumnWidth(3.0)
        let b = FixedColumnWidth(200.0)
        let width = MinColumnWidth(a, b)
        XCTAssertEqual(width.flex(cells: []), 3.0)
    }

    /// Test flex returns min when both have flex.
    func testFlexBothPresentReturnsMin() {
        let a = FlexColumnWidth(2.0)
        let b = FlexColumnWidth(5.0)
        let width = MinColumnWidth(a, b)
        XCTAssertEqual(width.flex(cells: []), 2.0)
    }

    /// Test flex returns min when a > b.
    func testFlexBothPresentBSmaller() {
        let a = FlexColumnWidth(5.0)
        let b = FlexColumnWidth(2.0)
        let width = MinColumnWidth(a, b)
        XCTAssertEqual(width.flex(cells: []), 2.0)
    }
}

// MARK: - TableCellParentData Tests

final class TableCellParentDataTests: XCTestCase {

    /// Test default values are all nil.
    func testDefaultValues() {
        let data = TableCellParentData()
        XCTAssertNil(data.verticalAlignment)
        XCTAssertNil(data.x)
        XCTAssertNil(data.y)
    }

    /// Test setting verticalAlignment.
    func testSetVerticalAlignment() {
        let data = TableCellParentData()
        data.verticalAlignment = .middle
        XCTAssertEqual(data.verticalAlignment, .middle)
    }

    /// Test setting x and y coordinates.
    func testSetXAndY() {
        let data = TableCellParentData()
        data.x = 2
        data.y = 3
        XCTAssertEqual(data.x, 2)
        XCTAssertEqual(data.y, 3)
    }

    /// Test that TableCellParentData is a subclass of BoxParentData.
    func testIsBoxParentData() {
        let data = TableCellParentData()
        XCTAssertTrue(data is BoxParentData, "TableCellParentData should be a BoxParentData")
    }

    /// Test that the offset defaults to zero (inherited from BoxParentData).
    func testOffsetDefaultsToZero() {
        let data = TableCellParentData()
        XCTAssertEqual(data.offset.dx, 0.0)
        XCTAssertEqual(data.offset.dy, 0.0)
    }

    /// Test description with default alignment.
    func testDescriptionDefaultAlignment() {
        let data = TableCellParentData()
        let desc = data.description
        XCTAssertTrue(desc.contains("default vertical alignment"), "Description should mention default alignment, got: \(desc)")
    }

    /// Test description with specific alignment.
    func testDescriptionWithAlignment() {
        let data = TableCellParentData()
        data.verticalAlignment = .baseline
        let desc = data.description
        XCTAssertTrue(desc.contains("baseline"), "Description should mention baseline, got: \(desc)")
    }

    /// Test setting all properties.
    func testSetAllProperties() {
        let data = TableCellParentData()
        data.verticalAlignment = .fill
        data.x = 5
        data.y = 10
        data.offset = Offset(20.0, 30.0)
        XCTAssertEqual(data.verticalAlignment, .fill)
        XCTAssertEqual(data.x, 5)
        XCTAssertEqual(data.y, 10)
        XCTAssertEqual(data.offset.dx, 20.0)
        XCTAssertEqual(data.offset.dy, 30.0)
    }

    /// Test that each vertical alignment case can be assigned.
    func testAllVerticalAlignmentCases() {
        let data = TableCellParentData()
        let cases: [TableCellVerticalAlignment] = [.top, .middle, .bottom, .baseline, .fill, .intrinsicHeight]
        for alignment in cases {
            data.verticalAlignment = alignment
            XCTAssertEqual(data.verticalAlignment, alignment)
        }
    }
}

// MARK: - TableCellVerticalAlignment Tests

final class TableCellVerticalAlignmentTests: XCTestCase {

    /// Test that all six cases exist and are distinct.
    func testAllCasesExistAndAreDistinct() {
        let cases: [TableCellVerticalAlignment] = [
            .top, .middle, .bottom, .baseline, .fill, .intrinsicHeight
        ]
        // Verify there are exactly 6 unique cases.
        let uniqueCases = Set(cases.map { "\($0)" })
        XCTAssertEqual(uniqueCases.count, 6)
    }

    /// Test the .top case.
    func testTopCase() {
        let alignment: TableCellVerticalAlignment = .top
        XCTAssertNotNil(alignment)
    }

    /// Test the .middle case.
    func testMiddleCase() {
        let alignment: TableCellVerticalAlignment = .middle
        XCTAssertNotNil(alignment)
    }

    /// Test the .bottom case.
    func testBottomCase() {
        let alignment: TableCellVerticalAlignment = .bottom
        XCTAssertNotNil(alignment)
    }

    /// Test the .baseline case.
    func testBaselineCase() {
        let alignment: TableCellVerticalAlignment = .baseline
        XCTAssertNotNil(alignment)
    }

    /// Test the .fill case.
    func testFillCase() {
        let alignment: TableCellVerticalAlignment = .fill
        XCTAssertNotNil(alignment)
    }

    /// Test the .intrinsicHeight case.
    func testIntrinsicHeightCase() {
        let alignment: TableCellVerticalAlignment = .intrinsicHeight
        XCTAssertNotNil(alignment)
    }

    /// Test equality between same cases.
    func testEquality() {
        XCTAssertTrue(TableCellVerticalAlignment.top == .top)
        XCTAssertFalse(TableCellVerticalAlignment.top == .bottom)
    }
}

// MARK: - RenderTable Construction Tests

final class RenderTableConstructionTests: XCTestCase {

    /// Test default construction with required textDirection.
    func testDefaultConstruction() {
        let table = RenderTable(textDirection: .ltr)
        XCTAssertEqual(table.columns, 0)
        XCTAssertEqual(table.rows, 0)
        XCTAssertEqual(table.textDirection, .ltr)
        XCTAssertNil(table.border)
        XCTAssertEqual(table.defaultVerticalAlignment, .top)
        XCTAssertNil(table.textBaseline)
    }

    /// Test construction with explicit columns and rows.
    func testConstructionWithColumnsAndRows() {
        let table = RenderTable(columns: 3, rows: 2, textDirection: .ltr)
        XCTAssertEqual(table.columns, 3)
        XCTAssertEqual(table.rows, 2)
    }

    /// Test construction with custom defaultColumnWidth.
    func testConstructionWithCustomDefaultColumnWidth() {
        let fixedWidth = FixedColumnWidth(100.0)
        let table = RenderTable(defaultColumnWidth: fixedWidth, textDirection: .ltr)
        XCTAssertTrue(table.defaultColumnWidth is FixedColumnWidth)
    }

    /// Test construction with border.
    func testConstructionWithBorder() {
        let border = TableBorder.all()
        let table = RenderTable(textDirection: .ltr, border: border)
        XCTAssertEqual(table.border, border)
    }

    /// Test construction with custom vertical alignment.
    func testConstructionWithVerticalAlignment() {
        let table = RenderTable(
            textDirection: .ltr,
            defaultVerticalAlignment: .middle
        )
        XCTAssertEqual(table.defaultVerticalAlignment, .middle)
    }

    /// Test construction with text baseline.
    func testConstructionWithTextBaseline() {
        let table = RenderTable(
            textDirection: .ltr,
            textBaseline: .alphabetic
        )
        XCTAssertEqual(table.textBaseline, .alphabetic)
    }

    /// Test construction with RTL text direction.
    func testConstructionWithRTL() {
        let table = RenderTable(textDirection: .rtl)
        XCTAssertEqual(table.textDirection, .rtl)
    }

    /// Test construction with columnWidths dictionary.
    func testConstructionWithColumnWidths() {
        let widths: [Int: any TableColumnWidth] = [
            0: FixedColumnWidth(100.0),
            1: FlexColumnWidth(2.0),
        ]
        let table = RenderTable(columnWidths: widths, textDirection: .ltr)
        let colWidths = table.columnWidths
        XCTAssertNotNil(colWidths)
        XCTAssertEqual(colWidths?.count, 2)
    }

    /// Test construction with children 2D array infers columns.
    func testConstructionWithChildrenInfersColumns() {
        let row1: [RenderBox] = [
            FixedSizeRenderBox(width: 50, height: 30),
            FixedSizeRenderBox(width: 50, height: 30),
            FixedSizeRenderBox(width: 50, height: 30),
        ]
        let table = RenderTable(textDirection: .ltr, children: [row1])
        XCTAssertEqual(table.columns, 3)
        XCTAssertEqual(table.rows, 1)
    }

    /// Test construction with multiple rows of children.
    func testConstructionWithMultipleRows() {
        let row1: [RenderBox] = [
            FixedSizeRenderBox(width: 50, height: 30),
            FixedSizeRenderBox(width: 50, height: 30),
        ]
        let row2: [RenderBox] = [
            FixedSizeRenderBox(width: 50, height: 30),
            FixedSizeRenderBox(width: 50, height: 30),
        ]
        let table = RenderTable(textDirection: .ltr, children: [row1, row2])
        XCTAssertEqual(table.columns, 2)
        XCTAssertEqual(table.rows, 2)
    }

    /// Test construction with empty children array.
    func testConstructionWithEmptyChildren() {
        let table = RenderTable(textDirection: .ltr, children: [])
        XCTAssertEqual(table.columns, 0)
        XCTAssertEqual(table.rows, 0)
    }
}

// MARK: - RenderTable Property Setter Tests

final class RenderTablePropertySetterTests: XCTestCase {

    /// Test that setting columns to a new value triggers markNeedsLayout.
    func testColumnsSetterTriggersLayout() {
        let table = RenderTable(columns: 2, rows: 1, textDirection: .ltr)
        table.needsLayout = false

        table.columns = 3
        XCTAssertTrue(table.needsLayout)
        XCTAssertEqual(table.columns, 3)
    }

    /// Test that setting columns to the same value is a no-op.
    func testColumnsSetterNoOp() {
        let table = RenderTable(columns: 2, rows: 1, textDirection: .ltr)
        table.needsLayout = false

        table.columns = 2
        XCTAssertFalse(table.needsLayout)
    }

    /// Test that setting rows to a new value triggers markNeedsLayout.
    func testRowsSetterTriggersLayout() {
        let table = RenderTable(columns: 2, rows: 1, textDirection: .ltr)
        table.needsLayout = false

        table.rows = 3
        XCTAssertTrue(table.needsLayout)
        XCTAssertEqual(table.rows, 3)
    }

    /// Test that setting rows to the same value is a no-op.
    func testRowsSetterNoOp() {
        let table = RenderTable(columns: 2, rows: 1, textDirection: .ltr)
        table.needsLayout = false

        table.rows = 1
        XCTAssertFalse(table.needsLayout)
    }

    /// Test that setting textDirection to a new value triggers markNeedsLayout.
    func testTextDirectionSetterTriggersLayout() {
        let table = RenderTable(textDirection: .ltr)
        table.needsLayout = false

        table.textDirection = .rtl
        XCTAssertTrue(table.needsLayout)
        XCTAssertEqual(table.textDirection, .rtl)
    }

    /// Test that setting textDirection to the same value is a no-op.
    func testTextDirectionSetterNoOp() {
        let table = RenderTable(textDirection: .ltr)
        table.needsLayout = false

        table.textDirection = .ltr
        XCTAssertFalse(table.needsLayout)
    }

    /// Test that setting border to a new value triggers markNeedsPaint.
    func testBorderSetterTriggersPaint() {
        let table = RenderTable(textDirection: .ltr)
        table.needsPaint = false

        table.border = TableBorder.all()
        XCTAssertTrue(table.needsPaint)
    }

    /// Test that setting border to the same value is a no-op.
    func testBorderSetterNoOp() {
        let border = TableBorder.all()
        let table = RenderTable(textDirection: .ltr, border: border)
        table.needsPaint = false

        table.border = border
        XCTAssertFalse(table.needsPaint)
    }

    /// Test that setting border from nil to nil is a no-op.
    func testBorderSetterNilToNilNoOp() {
        let table = RenderTable(textDirection: .ltr)
        table.needsPaint = false

        table.border = nil
        XCTAssertFalse(table.needsPaint)
    }

    /// Test that setting defaultVerticalAlignment triggers markNeedsLayout.
    func testDefaultVerticalAlignmentSetterTriggersLayout() {
        let table = RenderTable(textDirection: .ltr, defaultVerticalAlignment: .top)
        table.needsLayout = false

        table.defaultVerticalAlignment = .middle
        XCTAssertTrue(table.needsLayout)
        XCTAssertEqual(table.defaultVerticalAlignment, .middle)
    }

    /// Test that setting defaultVerticalAlignment to the same value is a no-op.
    func testDefaultVerticalAlignmentSetterNoOp() {
        let table = RenderTable(textDirection: .ltr, defaultVerticalAlignment: .top)
        table.needsLayout = false

        table.defaultVerticalAlignment = .top
        XCTAssertFalse(table.needsLayout)
    }

    /// Test that setting textBaseline triggers markNeedsLayout.
    func testTextBaselineSetterTriggersLayout() {
        let table = RenderTable(textDirection: .ltr)
        table.needsLayout = false

        table.textBaseline = .alphabetic
        XCTAssertTrue(table.needsLayout)
        XCTAssertEqual(table.textBaseline, .alphabetic)
    }

    /// Test that setting textBaseline to the same value is a no-op.
    func testTextBaselineSetterNoOp() {
        let table = RenderTable(textDirection: .ltr, textBaseline: .alphabetic)
        table.needsLayout = false

        table.textBaseline = .alphabetic
        XCTAssertFalse(table.needsLayout)
    }

    /// Test that setting defaultColumnWidth triggers markNeedsLayout.
    func testDefaultColumnWidthSetterTriggersLayout() {
        let table = RenderTable(textDirection: .ltr)
        table.needsLayout = false

        table.defaultColumnWidth = FixedColumnWidth(200.0)
        XCTAssertTrue(table.needsLayout)
    }

    /// Test that setting columnWidths triggers markNeedsLayout.
    func testColumnWidthsSetterTriggersLayout() {
        let table = RenderTable(textDirection: .ltr)
        table.needsLayout = false

        table.columnWidths = [0: FixedColumnWidth(100.0)]
        XCTAssertTrue(table.needsLayout)
    }

    /// Test that setting columnWidths to nil from empty is a no-op.
    func testColumnWidthsSetterNilFromEmptyNoOp() {
        let table = RenderTable(textDirection: .ltr)
        table.needsLayout = false

        table.columnWidths = nil
        XCTAssertFalse(table.needsLayout)
    }

    /// Test setColumnWidth method triggers markNeedsLayout.
    func testSetColumnWidthTriggersLayout() {
        let table = RenderTable(columns: 2, rows: 1, textDirection: .ltr)
        table.needsLayout = false

        table.setColumnWidth(0, FixedColumnWidth(150.0))
        XCTAssertTrue(table.needsLayout)
    }
}

// MARK: - RenderTable Column/Row Resize Tests

final class RenderTableResizeTests: XCTestCase {

    /// Test that increasing columns preserves existing children.
    func testIncreaseColumnsPreservesChildren() {
        let child = FixedSizeRenderBox(width: 50, height: 30)
        let table = RenderTable(columns: 1, rows: 1, textDirection: .ltr)
        table.setChild(x: 0, y: 0, value: child)

        table.columns = 2
        XCTAssertEqual(table.columns, 2)
        XCTAssertEqual(table.rows, 1)
    }

    /// Test that decreasing columns drops children outside new bounds.
    func testDecreaseColumnsDropsChildren() {
        let child1 = FixedSizeRenderBox(width: 50, height: 30)
        let child2 = FixedSizeRenderBox(width: 50, height: 30)
        let table = RenderTable(columns: 2, rows: 1, textDirection: .ltr)
        table.setChild(x: 0, y: 0, value: child1)
        table.setChild(x: 1, y: 0, value: child2)

        table.columns = 1
        XCTAssertEqual(table.columns, 1)
        // child2 at column 1 should have been dropped
        XCTAssertNil(child2.parentData)
    }

    /// Test that increasing rows adds space for new children.
    func testIncreaseRows() {
        let table = RenderTable(columns: 2, rows: 1, textDirection: .ltr)
        table.rows = 3
        XCTAssertEqual(table.rows, 3)
    }

    /// Test that decreasing rows drops children outside new bounds.
    func testDecreaseRowsDropsChildren() {
        let child = FixedSizeRenderBox(width: 50, height: 30)
        let table = RenderTable(columns: 1, rows: 2, textDirection: .ltr)
        table.setChild(x: 0, y: 1, value: child)

        table.rows = 1
        XCTAssertEqual(table.rows, 1)
        // child at row 1 should have been dropped
        XCTAssertNil(child.parentData)
    }

    /// Test resizing columns to 0 drops all children.
    func testColumnsToZeroDropsAll() {
        let child = FixedSizeRenderBox(width: 50, height: 30)
        let table = RenderTable(columns: 1, rows: 1, textDirection: .ltr)
        table.setChild(x: 0, y: 0, value: child)

        table.columns = 0
        XCTAssertEqual(table.columns, 0)
        XCTAssertNil(child.parentData)
    }

    /// Test resizing rows to 0 drops all children.
    func testRowsToZeroDropsAll() {
        let child = FixedSizeRenderBox(width: 50, height: 30)
        let table = RenderTable(columns: 1, rows: 1, textDirection: .ltr)
        table.setChild(x: 0, y: 0, value: child)

        table.rows = 0
        XCTAssertEqual(table.rows, 0)
        XCTAssertNil(child.parentData)
    }
}

// MARK: - RenderTable setupParentData Tests

final class RenderTableSetupParentDataTests: XCTestCase {

    /// Test that setupParentData creates TableCellParentData.
    func testSetupParentDataCreatesTableCellParentData() {
        let table = RenderTable(textDirection: .ltr)
        let child = RenderBox()
        table.setupParentData(child)
        XCTAssertTrue(child.parentData is TableCellParentData)
    }

    /// Test that setupParentData does not replace existing TableCellParentData.
    func testSetupParentDataPreservesExisting() {
        let table = RenderTable(textDirection: .ltr)
        let child = RenderBox()
        let existingData = TableCellParentData()
        existingData.verticalAlignment = .fill
        existingData.x = 7
        child.parentData = existingData
        table.setupParentData(child)
        let data = child.parentData as! TableCellParentData
        XCTAssertEqual(data.verticalAlignment, .fill)
        XCTAssertEqual(data.x, 7)
    }

    /// Test that setupParentData replaces non-TableCellParentData.
    func testSetupParentDataReplacesNonTableCellParentData() {
        let table = RenderTable(textDirection: .ltr)
        let child = RenderBox()
        child.parentData = BoxParentData()
        table.setupParentData(child)
        XCTAssertTrue(child.parentData is TableCellParentData)
    }
}

// MARK: - RenderTable setChild Tests

final class RenderTableSetChildTests: XCTestCase {

    /// Test setting a child at a specific position.
    func testSetChildAtPosition() {
        let table = RenderTable(columns: 2, rows: 2, textDirection: .ltr)
        let child = FixedSizeRenderBox(width: 50, height: 30)
        table.setChild(x: 1, y: 0, value: child)
        // Child should have parentData set
        XCTAssertTrue(child.parentData is TableCellParentData)
    }

    /// Test that setting the same child again at the same position is a no-op.
    func testSetChildSameChildNoOp() {
        let table = RenderTable(columns: 2, rows: 2, textDirection: .ltr)
        let child = FixedSizeRenderBox(width: 50, height: 30)
        table.setChild(x: 0, y: 0, value: child)
        table.needsLayout = false

        // Setting same child again should be no-op (identity check)
        table.setChild(x: 0, y: 0, value: child)
        XCTAssertFalse(table.needsLayout)
    }

    /// Test replacing a child at a position drops the old child.
    func testSetChildReplacesOld() {
        let table = RenderTable(columns: 1, rows: 1, textDirection: .ltr)
        let oldChild = FixedSizeRenderBox(width: 50, height: 30)
        let newChild = FixedSizeRenderBox(width: 60, height: 40)
        table.setChild(x: 0, y: 0, value: oldChild)

        table.setChild(x: 0, y: 0, value: newChild)
        // Old child should have been dropped
        XCTAssertNil(oldChild.parentData)
        // New child should have parentData
        XCTAssertTrue(newChild.parentData is TableCellParentData)
    }

    /// Test setting a child to nil removes the existing child.
    func testSetChildToNil() {
        let table = RenderTable(columns: 1, rows: 1, textDirection: .ltr)
        let child = FixedSizeRenderBox(width: 50, height: 30)
        table.setChild(x: 0, y: 0, value: child)

        table.setChild(x: 0, y: 0, value: nil)
        XCTAssertNil(child.parentData)
    }
}

// MARK: - RenderTable addRow Tests

final class RenderTableAddRowTests: XCTestCase {

    /// Test adding a row increases row count.
    func testAddRowIncreasesRowCount() {
        let table = RenderTable(columns: 2, rows: 0, textDirection: .ltr)
        let cells: [RenderBox?] = [
            FixedSizeRenderBox(width: 50, height: 30),
            FixedSizeRenderBox(width: 50, height: 30),
        ]
        table.addRow(cells: cells)
        XCTAssertEqual(table.rows, 1)
    }

    /// Test adding multiple rows.
    func testAddMultipleRows() {
        let table = RenderTable(columns: 2, rows: 0, textDirection: .ltr)
        let row1: [RenderBox?] = [
            FixedSizeRenderBox(width: 50, height: 30),
            FixedSizeRenderBox(width: 50, height: 30),
        ]
        let row2: [RenderBox?] = [
            FixedSizeRenderBox(width: 50, height: 30),
            FixedSizeRenderBox(width: 50, height: 30),
        ]
        table.addRow(cells: row1)
        table.addRow(cells: row2)
        XCTAssertEqual(table.rows, 2)
    }

    /// Test adding a row with nil cells.
    func testAddRowWithNilCells() {
        let table = RenderTable(columns: 2, rows: 0, textDirection: .ltr)
        let cells: [RenderBox?] = [nil, nil]
        table.addRow(cells: cells)
        XCTAssertEqual(table.rows, 1)
    }

    /// Test adding a row with mixed nil and non-nil cells.
    func testAddRowWithMixedCells() {
        let table = RenderTable(columns: 3, rows: 0, textDirection: .ltr)
        let child = FixedSizeRenderBox(width: 50, height: 30)
        let cells: [RenderBox?] = [child, nil, FixedSizeRenderBox(width: 50, height: 30)]
        table.addRow(cells: cells)
        XCTAssertEqual(table.rows, 1)
        XCTAssertTrue(child.parentData is TableCellParentData)
    }

    /// Test that addRow triggers markNeedsLayout.
    func testAddRowTriggersLayout() {
        let table = RenderTable(columns: 1, rows: 0, textDirection: .ltr)
        table.needsLayout = false

        table.addRow(cells: [FixedSizeRenderBox(width: 50, height: 30)])
        XCTAssertTrue(table.needsLayout)
    }
}

// MARK: - RenderTable setFlatChildren Tests

final class RenderTableSetFlatChildrenTests: XCTestCase {

    /// Test setting flat children replaces all children.
    func testSetFlatChildrenReplacesAll() {
        let table = RenderTable(columns: 1, rows: 1, textDirection: .ltr)
        let oldChild = FixedSizeRenderBox(width: 50, height: 30)
        table.setChild(x: 0, y: 0, value: oldChild)

        let newChild1 = FixedSizeRenderBox(width: 60, height: 40)
        let newChild2 = FixedSizeRenderBox(width: 70, height: 50)
        table.setFlatChildren(columns: 2, cells: [newChild1, newChild2])

        XCTAssertEqual(table.columns, 2)
        XCTAssertEqual(table.rows, 1)
        XCTAssertNil(oldChild.parentData)
        XCTAssertTrue(newChild1.parentData is TableCellParentData)
        XCTAssertTrue(newChild2.parentData is TableCellParentData)
    }

    /// Test setting flat children with empty cells clears the table.
    func testSetFlatChildrenEmpty() {
        let table = RenderTable(columns: 2, rows: 1, textDirection: .ltr)
        let child = FixedSizeRenderBox(width: 50, height: 30)
        table.setChild(x: 0, y: 0, value: child)

        table.setFlatChildren(columns: 0, cells: [])
        XCTAssertEqual(table.columns, 0)
        XCTAssertEqual(table.rows, 0)
        XCTAssertNil(child.parentData)
    }

    /// Test setting flat children with proper column count sets rows correctly.
    func testSetFlatChildrenCalculatesRows() {
        let table = RenderTable(textDirection: .ltr)
        let cells: [RenderBox?] = [
            FixedSizeRenderBox(width: 50, height: 30),
            FixedSizeRenderBox(width: 50, height: 30),
            FixedSizeRenderBox(width: 50, height: 30),
            FixedSizeRenderBox(width: 50, height: 30),
            FixedSizeRenderBox(width: 50, height: 30),
            FixedSizeRenderBox(width: 50, height: 30),
        ]
        table.setFlatChildren(columns: 3, cells: cells)
        XCTAssertEqual(table.columns, 3)
        XCTAssertEqual(table.rows, 2)
    }

    /// Test that setFlatChildren triggers markNeedsLayout.
    func testSetFlatChildrenTriggersLayout() {
        let table = RenderTable(textDirection: .ltr)
        table.needsLayout = false

        let cells: [RenderBox?] = [
            FixedSizeRenderBox(width: 50, height: 30),
            FixedSizeRenderBox(width: 50, height: 30),
        ]
        table.setFlatChildren(columns: 2, cells: cells)
        XCTAssertTrue(table.needsLayout)
    }

    /// Test setFlatChildren with nil cells in the array.
    func testSetFlatChildrenWithNilCells() {
        let table = RenderTable(textDirection: .ltr)
        let cells: [RenderBox?] = [
            FixedSizeRenderBox(width: 50, height: 30),
            nil,
            nil,
            FixedSizeRenderBox(width: 50, height: 30),
        ]
        table.setFlatChildren(columns: 2, cells: cells)
        XCTAssertEqual(table.columns, 2)
        XCTAssertEqual(table.rows, 2)
    }

    /// Test that setFlatChildren handles moving existing children.
    func testSetFlatChildrenMovesExistingChildren() {
        let child1 = FixedSizeRenderBox(width: 50, height: 30)
        let child2 = FixedSizeRenderBox(width: 60, height: 40)
        let table = RenderTable(columns: 2, rows: 1, textDirection: .ltr)
        table.setChild(x: 0, y: 0, value: child1)
        table.setChild(x: 1, y: 0, value: child2)

        // Now rearrange: swap positions
        table.setFlatChildren(columns: 2, cells: [child2, child1])
        XCTAssertEqual(table.columns, 2)
        XCTAssertEqual(table.rows, 1)
        // Both children should still have parentData (not dropped)
        XCTAssertNotNil(child1.parentData)
        XCTAssertNotNil(child2.parentData)
    }

    /// Test setFlatChildren clearing to empty when already empty is a no-op.
    func testSetFlatChildrenEmptyToEmpty() {
        let table = RenderTable(textDirection: .ltr)
        table.needsLayout = false

        table.setFlatChildren(columns: 0, cells: [])
        // Should not trigger layout since it was already empty
        XCTAssertFalse(table.needsLayout)
    }
}

// MARK: - RenderTable setChildren Tests

final class RenderTableSetChildrenTests: XCTestCase {

    /// Test setChildren with nil clears the table.
    func testSetChildrenNilClearsTable() {
        let child = FixedSizeRenderBox(width: 50, height: 30)
        let table = RenderTable(columns: 1, rows: 1, textDirection: .ltr)
        table.setChild(x: 0, y: 0, value: child)

        table.setChildren(cells: nil)
        XCTAssertEqual(table.columns, 0)
        XCTAssertEqual(table.rows, 0)
        XCTAssertNil(child.parentData)
    }

    /// Test setChildren with empty array clears the table.
    func testSetChildrenEmptyArrayClearsTable() {
        let table = RenderTable(columns: 2, rows: 1, textDirection: .ltr)
        table.setChildren(cells: [])
        XCTAssertEqual(table.columns, 0)
        XCTAssertEqual(table.rows, 0)
    }

    /// Test setChildren with 2D array.
    func testSetChildrenWith2DArray() {
        let table = RenderTable(textDirection: .ltr)
        let row1: [RenderBox] = [
            FixedSizeRenderBox(width: 50, height: 30),
            FixedSizeRenderBox(width: 60, height: 40),
        ]
        let row2: [RenderBox] = [
            FixedSizeRenderBox(width: 70, height: 50),
            FixedSizeRenderBox(width: 80, height: 60),
        ]
        table.setChildren(cells: [row1, row2])
        XCTAssertEqual(table.columns, 2)
        XCTAssertEqual(table.rows, 2)
    }

    /// Test setChildren replaces previous children.
    func testSetChildrenReplacesExisting() {
        let oldChild = FixedSizeRenderBox(width: 50, height: 30)
        let table = RenderTable(columns: 1, rows: 1, textDirection: .ltr)
        table.setChild(x: 0, y: 0, value: oldChild)

        let newChild = FixedSizeRenderBox(width: 60, height: 40)
        table.setChildren(cells: [[newChild]])
        XCTAssertEqual(table.columns, 1)
        XCTAssertEqual(table.rows, 1)
        XCTAssertNil(oldChild.parentData)
        XCTAssertTrue(newChild.parentData is TableCellParentData)
    }

    /// Test setChildren with single row.
    func testSetChildrenSingleRow() {
        let table = RenderTable(textDirection: .ltr)
        let row: [RenderBox] = [
            FixedSizeRenderBox(width: 50, height: 30),
            FixedSizeRenderBox(width: 50, height: 30),
            FixedSizeRenderBox(width: 50, height: 30),
        ]
        table.setChildren(cells: [row])
        XCTAssertEqual(table.columns, 3)
        XCTAssertEqual(table.rows, 1)
    }
}

// MARK: - RenderTable visitChildren Tests

final class RenderTableVisitChildrenTests: XCTestCase {

    /// Test visitChildren visits all non-nil children.
    func testVisitChildrenVisitsAllNonNil() {
        let table = RenderTable(columns: 2, rows: 2, textDirection: .ltr)
        let child1 = FixedSizeRenderBox(width: 50, height: 30)
        let child2 = FixedSizeRenderBox(width: 60, height: 40)
        let child3 = FixedSizeRenderBox(width: 70, height: 50)
        table.setChild(x: 0, y: 0, value: child1)
        table.setChild(x: 1, y: 0, value: child2)
        table.setChild(x: 0, y: 1, value: child3)
        // (1,1) is nil

        var visited: [RenderObject] = []
        table.visitChildren { child in
            visited.append(child)
        }
        XCTAssertEqual(visited.count, 3)
    }

    /// Test visitChildren with no children visits nothing.
    func testVisitChildrenEmpty() {
        let table = RenderTable(columns: 2, rows: 2, textDirection: .ltr)
        var count = 0
        table.visitChildren { _ in
            count += 1
        }
        XCTAssertEqual(count, 0)
    }

    /// Test visitChildren with all nil cells visits nothing.
    func testVisitChildrenAllNil() {
        let table = RenderTable(columns: 2, rows: 1, textDirection: .ltr)
        table.addRow(cells: [nil, nil])
        // Table already has 1 row from construction (rows:1), we added another row but
        // the initial construction with rows:0 followed by addRow is the pattern.
        // Let's be explicit:
        let table2 = RenderTable(columns: 2, rows: 0, textDirection: .ltr)
        table2.addRow(cells: [nil, nil])
        var count = 0
        table2.visitChildren { _ in
            count += 1
        }
        XCTAssertEqual(count, 0)
    }
}

// MARK: - RenderTable Column/Row Helper Tests

final class RenderTableColumnRowHelperTests: XCTestCase {

    /// Test that column() returns cells in the given column.
    func testColumnHelper() {
        let table = RenderTable(columns: 2, rows: 2, textDirection: .ltr)
        let child00 = FixedSizeRenderBox(width: 50, height: 30)
        let child01 = FixedSizeRenderBox(width: 60, height: 40)
        let child10 = FixedSizeRenderBox(width: 70, height: 50)
        let child11 = FixedSizeRenderBox(width: 80, height: 60)
        table.setChild(x: 0, y: 0, value: child00)
        table.setChild(x: 1, y: 0, value: child01)
        table.setChild(x: 0, y: 1, value: child10)
        table.setChild(x: 1, y: 1, value: child11)

        let col0 = table.column(0)
        XCTAssertEqual(col0.count, 2)
        XCTAssertTrue(col0[0] === child00)
        XCTAssertTrue(col0[1] === child10)

        let col1 = table.column(1)
        XCTAssertEqual(col1.count, 2)
        XCTAssertTrue(col1[0] === child01)
        XCTAssertTrue(col1[1] === child11)
    }

    /// Test that row() returns cells in the given row.
    func testRowHelper() {
        let table = RenderTable(columns: 2, rows: 2, textDirection: .ltr)
        let child00 = FixedSizeRenderBox(width: 50, height: 30)
        let child01 = FixedSizeRenderBox(width: 60, height: 40)
        let child10 = FixedSizeRenderBox(width: 70, height: 50)
        let child11 = FixedSizeRenderBox(width: 80, height: 60)
        table.setChild(x: 0, y: 0, value: child00)
        table.setChild(x: 1, y: 0, value: child01)
        table.setChild(x: 0, y: 1, value: child10)
        table.setChild(x: 1, y: 1, value: child11)

        let row0 = table.row(0)
        XCTAssertEqual(row0.count, 2)
        XCTAssertTrue(row0[0] === child00)
        XCTAssertTrue(row0[1] === child01)

        let row1 = table.row(1)
        XCTAssertEqual(row1.count, 2)
        XCTAssertTrue(row1[0] === child10)
        XCTAssertTrue(row1[1] === child11)
    }

    /// Test that column() skips nil cells.
    func testColumnHelperSkipsNil() {
        let table = RenderTable(columns: 2, rows: 2, textDirection: .ltr)
        let child = FixedSizeRenderBox(width: 50, height: 30)
        table.setChild(x: 0, y: 1, value: child)
        // (0,0) is nil

        let col0 = table.column(0)
        XCTAssertEqual(col0.count, 1)
        XCTAssertTrue(col0[0] === child)
    }

    /// Test that row() skips nil cells.
    func testRowHelperSkipsNil() {
        let table = RenderTable(columns: 2, rows: 1, textDirection: .ltr)
        let child = FixedSizeRenderBox(width: 50, height: 30)
        table.setChild(x: 1, y: 0, value: child)
        // (0,0) is nil

        let row0 = table.row(0)
        XCTAssertEqual(row0.count, 1)
        XCTAssertTrue(row0[0] === child)
    }
}

// MARK: - RenderTable Attach/Detach Tests

final class RenderTableAttachDetachTests: XCTestCase {

    /// Test attach propagates to children.
    func testAttachPropagatesToChildren() {
        let child = FixedSizeRenderBox(width: 50, height: 30)
        let table = RenderTable(columns: 1, rows: 1, textDirection: .ltr)
        table.setChild(x: 0, y: 0, value: child)

        let owner = PipelineOwner()
        table.attach(owner)
        XCTAssertTrue(table.attached)
        XCTAssertTrue(child.attached)
    }

    /// Test detach propagates to children.
    func testDetachPropagatesToChildren() {
        let child = FixedSizeRenderBox(width: 50, height: 30)
        let table = RenderTable(columns: 1, rows: 1, textDirection: .ltr)
        table.setChild(x: 0, y: 0, value: child)

        let owner = PipelineOwner()
        table.attach(owner)
        table.detach()
        XCTAssertFalse(table.attached)
        XCTAssertFalse(child.attached)
    }

    /// Test attach/detach with empty table.
    func testAttachDetachEmptyTable() {
        let table = RenderTable(textDirection: .ltr)
        let owner = PipelineOwner()
        table.attach(owner)
        XCTAssertTrue(table.attached)
        table.detach()
        XCTAssertFalse(table.attached)
    }
}

// MARK: - Column Width Composition Tests

final class ColumnWidthCompositionTests: XCTestCase {

    /// Test nested MaxColumnWidth with three strategies.
    func testNestedMaxColumnWidth() {
        let a = FixedColumnWidth(100.0)
        let b = FixedColumnWidth(200.0)
        let c = FixedColumnWidth(150.0)
        let width = MaxColumnWidth(MaxColumnWidth(a, b), c)
        let result = width.minIntrinsicWidth(cells: [], containerWidth: 800.0)
        XCTAssertEqual(result, 200.0)
    }

    /// Test nested MinColumnWidth with three strategies.
    func testNestedMinColumnWidth() {
        let a = FixedColumnWidth(100.0)
        let b = FixedColumnWidth(200.0)
        let c = FixedColumnWidth(150.0)
        let width = MinColumnWidth(MinColumnWidth(a, b), c)
        let result = width.minIntrinsicWidth(cells: [], containerWidth: 800.0)
        XCTAssertEqual(result, 100.0)
    }

    /// Test MaxColumnWidth with FractionColumnWidth at infinite container.
    func testMaxWithInfiniteContainer() {
        let fixed = FixedColumnWidth(100.0)
        let fraction = FractionColumnWidth(0.5)
        let width = MaxColumnWidth(fixed, fraction)
        // fraction returns 0 for infinite, fixed returns 100 => max = 100
        let result = width.minIntrinsicWidth(cells: [], containerWidth: .infinity)
        XCTAssertEqual(result, 100.0)
    }

    /// Test MinColumnWidth with FractionColumnWidth at infinite container.
    func testMinWithInfiniteContainer() {
        let fixed = FixedColumnWidth(100.0)
        let fraction = FractionColumnWidth(0.5)
        let width = MinColumnWidth(fixed, fraction)
        // fraction returns 0 for infinite, fixed returns 100 => min = 0
        let result = width.minIntrinsicWidth(cells: [], containerWidth: .infinity)
        XCTAssertEqual(result, 0.0)
    }

    /// Test MaxColumnWidth with IntrinsicColumnWidth and cells.
    func testMaxWithIntrinsicColumnWidth() {
        let intrinsic = IntrinsicColumnWidth()
        let fixed = FixedColumnWidth(50.0)
        let width = MaxColumnWidth(intrinsic, fixed)
        let cell = FixedSizeRenderBox(width: 100, height: 30)
        // intrinsic min = 100, fixed = 50 => max = 100
        let result = width.minIntrinsicWidth(cells: [cell], containerWidth: 800.0)
        XCTAssertEqual(result, 100.0)
    }

    /// Test MinColumnWidth with IntrinsicColumnWidth and cells.
    func testMinWithIntrinsicColumnWidth() {
        let intrinsic = IntrinsicColumnWidth()
        let fixed = FixedColumnWidth(50.0)
        let width = MinColumnWidth(intrinsic, fixed)
        let cell = FixedSizeRenderBox(width: 100, height: 30)
        // intrinsic min = 100, fixed = 50 => min = 50
        let result = width.minIntrinsicWidth(cells: [cell], containerWidth: 800.0)
        XCTAssertEqual(result, 50.0)
    }
}

// MARK: - TableColumnWidth Default Extension Tests

final class TableColumnWidthDefaultExtensionTests: XCTestCase {

    /// Test that the default flex extension returns nil for FixedColumnWidth.
    func testDefaultFlexForFixed() {
        let width = FixedColumnWidth(100.0)
        XCTAssertNil(width.flex(cells: []))
    }

    /// Test that the default flex extension returns nil for FractionColumnWidth.
    func testDefaultFlexForFraction() {
        let width = FractionColumnWidth(0.5)
        XCTAssertNil(width.flex(cells: []))
    }

    /// Test that IntrinsicColumnWidth without flex argument returns nil flex.
    func testDefaultFlexForIntrinsicNoFlex() {
        let width = IntrinsicColumnWidth()
        XCTAssertNil(width.flex(cells: []))
    }

    /// Test that FlexColumnWidth overrides the default flex.
    func testFlexColumnWidthOverridesDefault() {
        let width = FlexColumnWidth(4.0)
        XCTAssertEqual(width.flex(cells: []), 4.0)
    }
}

// MARK: - RenderTable Child Lifecycle Tests

final class RenderTableChildLifecycleTests: XCTestCase {

    /// Test that adoptChild sets up parent data via setupParentData.
    func testAdoptChildSetsUpParentData() {
        let table = RenderTable(columns: 1, rows: 1, textDirection: .ltr)
        let child = FixedSizeRenderBox(width: 50, height: 30)
        table.setChild(x: 0, y: 0, value: child)
        XCTAssertTrue(child.parentData is TableCellParentData)
    }

    /// Test that dropChild clears parent data.
    func testDropChildClearsParentData() {
        let table = RenderTable(columns: 1, rows: 1, textDirection: .ltr)
        let child = FixedSizeRenderBox(width: 50, height: 30)
        table.setChild(x: 0, y: 0, value: child)
        XCTAssertNotNil(child.parentData)

        table.setChild(x: 0, y: 0, value: nil)
        XCTAssertNil(child.parentData)
    }

    /// Test that construction with children array adopts all children.
    func testConstructionAdoptsAllChildren() {
        let child1 = FixedSizeRenderBox(width: 50, height: 30)
        let child2 = FixedSizeRenderBox(width: 60, height: 40)
        let child3 = FixedSizeRenderBox(width: 70, height: 50)
        let child4 = FixedSizeRenderBox(width: 80, height: 60)

        let _ = RenderTable(
            textDirection: .ltr,
            children: [[child1, child2], [child3, child4]]
        )

        XCTAssertTrue(child1.parentData is TableCellParentData)
        XCTAssertTrue(child2.parentData is TableCellParentData)
        XCTAssertTrue(child3.parentData is TableCellParentData)
        XCTAssertTrue(child4.parentData is TableCellParentData)
    }
}
