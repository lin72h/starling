// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

// MARK: - CalculatorEngine

enum CalcOp {
    case add, subtract, multiply, divide
}

/// Immediate-execution calculator state machine (macOS Calculator "Basic"
/// semantics): binary operators evaluate the pending operation first, `=`
/// repeats the last operation when pressed again.
struct CalculatorEngine {
    private(set) var display: String = "0"

    private var accumulator: Double? = nil
    private var pendingOp: CalcOp? = nil
    /// The next digit replaces the display instead of appending to it
    /// (after an operator, `=`, `%`, or on a cleared calculator).
    private var replaceNext = true
    // Repeated-equals support: `2 + 3 = = =` keeps adding 3.
    private var lastOp: CalcOp? = nil
    private var lastOperand: Double = 0

    /// True when the calculator holds no state at all (AC vs C label).
    var isCleared: Bool {
        display == "0" && accumulator == nil && pendingOp == nil
    }

    /// The operator whose key should render highlighted: the pending one,
    /// but only until the user starts typing the second operand.
    var activeOp: CalcOp? { replaceNext ? pendingOp : nil }

    mutating func digit(_ d: Int) {
        if display == "Error" { clearAll() }
        if replaceNext || display == "0" {
            display = String(d)
            replaceNext = false
        } else if digitCount < 12 {
            display += String(d)
        }
    }

    mutating func dot() {
        if display == "Error" { clearAll() }
        if replaceNext {
            display = "0."
            replaceNext = false
        } else if !display.contains(".") {
            display += "."
        }
    }

    mutating func setOp(_ op: CalcOp) {
        guard display != "Error" else { return }
        if pendingOp != nil && !replaceNext {
            evaluatePending()
            guard display != "Error" else { return }
        }
        accumulator = value
        pendingOp = op
        replaceNext = true
    }

    mutating func equals() {
        guard display != "Error" else { return }
        if pendingOp != nil {
            lastOp = pendingOp
            lastOperand = value
            evaluatePending()
            pendingOp = nil
        } else if let op = lastOp {
            display = Self.format(apply(op, value, lastOperand))
        }
        replaceNext = true
    }

    mutating func toggleSign() {
        guard display != "Error" else { return }
        if display.hasPrefix("-") {
            display.removeFirst()
        } else if display != "0" {
            display = "-" + display
        }
    }

    mutating func percent() {
        guard display != "Error" else { return }
        display = Self.format(value / 100.0)
        replaceNext = true
    }

    /// `C`: drop only the current entry, keep the pending operation.
    mutating func clearEntry() {
        display = "0"
        replaceNext = true
    }

    /// `AC`: reset everything.
    mutating func clearAll() {
        display = "0"
        accumulator = nil
        pendingOp = nil
        lastOp = nil
        lastOperand = 0
        replaceNext = true
    }

    // MARK: - Internals

    private var value: Double { Double(display) ?? 0 }

    private var digitCount: Int {
        display.filter { $0.isNumber }.count
    }

    private mutating func evaluatePending() {
        guard let op = pendingOp, let acc = accumulator else { return }
        let r = apply(op, acc, value)
        display = Self.format(r)
        accumulator = r.isFinite ? r : nil
        replaceNext = true
    }

    private func apply(_ op: CalcOp, _ a: Double, _ b: Double) -> Double {
        switch op {
        case .add: return a + b
        case .subtract: return a - b
        case .multiply: return a * b
        case .divide: return a / b
        }
    }

    static func format(_ v: Double) -> String {
        guard v.isFinite else { return "Error" }
        if v == 0 { return "0" }
        if v == v.rounded() && abs(v) < 1e12 {
            return String(format: "%.0f", v)
        }
        return String(format: "%.10g", v)
    }
}
