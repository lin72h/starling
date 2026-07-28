import FlutterSwiftBridge

// MARK: - TextEditingValue Extension

/// Extension to add helper methods to TextEditingValue (defined in Rendering/Editable.swift).
extension TextEditingValue {
    /// An empty text editing value.
    public static var empty: TextEditingValue { TextEditingValue() }

    /// Returns a new value with the text replaced in the given range.
    public func replaced(_ range: TextRange, _ replacementString: String) -> TextEditingValue {
        let originalText = text
        let clampedStart = Swift.min(range.start, originalText.count)
        let clampedEnd = Swift.min(range.end, originalText.count)
        let startIndex = originalText.index(originalText.startIndex, offsetBy: clampedStart)
        let endIndex = originalText.index(originalText.startIndex, offsetBy: clampedEnd)
        var newText = originalText
        newText.replaceSubrange(startIndex..<endIndex, with: replacementString)
        let newOffset = clampedStart + replacementString.count
        return TextEditingValue(
            text: newText,
            selection: TextSelection(offset: newOffset),
            composing: TextRange.empty
        )
    }
}

// MARK: - TextEditingController

/// A controller for an editable text field.
///
/// Whenever the user modifies a text field with an associated
/// `TextEditingController`, the text field updates `value` and the controller
/// notifies its listeners.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/editable_text.dart`
public class TextEditingController: ChangeNotifier {

    /// Creates a controller for an editable text field.
    public init(text: String = "") {
        _value = TextEditingValue(
            text: text,
            selection: TextSelection(offset: text.count)
        )
        super.init()
    }

    /// Creates a controller for an editable text field from an initial value.
    public init(value: TextEditingValue) {
        _value = value
        super.init()
    }

    /// The current value of the text field.
    public var value: TextEditingValue {
        get { _value }
        set {
            if _value == newValue { return }
            _value = newValue
            notifyListeners()
        }
    }
    private var _value: TextEditingValue

    /// The current string the user is editing.
    public var text: String {
        get { _value.text }
        set {
            value = _value.copyWith(
                text: newValue,
                selection: TextSelection(offset: newValue.count),
                composing: TextRange.empty
            )
        }
    }

    /// The currently selected range within `text`.
    public var selection: TextSelection {
        get { _value.selection }
        set {
            value = _value.copyWith(selection: newValue)
        }
    }

    /// Set the `value` to empty.
    public func clear() {
        value = TextEditingValue(
            text: "",
            selection: TextSelection(offset: 0),
            composing: TextRange.empty
        )
    }

    /// Whether the text field has any text.
    public var hasText: Bool {
        return !_value.text.isEmpty
    }

    // MARK: - Text manipulation helpers

    /// Inserts text at the current cursor position, or replaces the current
    /// selection with the given text.
    public func insertText(_ insertedText: String) {
        let currentText = text
        let sel = selection

        if sel.isValid && sel.baseOffset >= 0 && sel.extentOffset >= 0 {
            let start = Swift.min(sel.start, currentText.count)
            let end = Swift.min(sel.end, currentText.count)
            let range = TextRange(start: start, end: end)
            value = value.replaced(range, insertedText)
        } else {
            // No valid selection — append to end
            let newText = currentText + insertedText
            value = TextEditingValue(
                text: newText,
                selection: TextSelection(offset: newText.count)
            )
        }
    }

    /// Deletes the character before the cursor (backspace).
    public func deleteBackward() {
        let currentText = text
        let sel = selection

        guard !currentText.isEmpty else { return }

        if sel.isValid && !sel.isCollapsed {
            // Delete selection
            let start = Swift.min(sel.start, currentText.count)
            let end = Swift.min(sel.end, currentText.count)
            let range = TextRange(start: start, end: end)
            value = value.replaced(range, "")
        } else if sel.isValid && sel.baseOffset > 0 {
            // Delete character before cursor
            let deletePos = Swift.min(sel.baseOffset, currentText.count)
            let range = TextRange(start: deletePos - 1, end: deletePos)
            value = value.replaced(range, "")
        } else if !sel.isValid {
            // No valid selection — delete last character
            let newText = String(currentText.dropLast())
            value = TextEditingValue(
                text: newText,
                selection: TextSelection(offset: newText.count)
            )
        }
    }

    /// Deletes the character after the cursor (forward delete).
    public func deleteForward() {
        let currentText = text
        let sel = selection

        guard !currentText.isEmpty else { return }

        if sel.isValid && !sel.isCollapsed {
            // Delete selection
            let start = Swift.min(sel.start, currentText.count)
            let end = Swift.min(sel.end, currentText.count)
            let range = TextRange(start: start, end: end)
            value = value.replaced(range, "")
        } else if sel.isValid && sel.baseOffset < currentText.count {
            // Delete character after cursor
            let deletePos = sel.baseOffset
            let range = TextRange(start: deletePos, end: deletePos + 1)
            value = value.replaced(range, "")
        }
    }

    /// Moves the cursor left by one character.
    public func moveCursorLeft() {
        let sel = selection
        if sel.isValid && sel.baseOffset > 0 {
            let newOffset = sel.isCollapsed ? sel.baseOffset - 1 : sel.start
            selection = TextSelection(offset: newOffset)
        }
    }

    /// Moves the cursor right by one character.
    public func moveCursorRight() {
        let sel = selection
        if sel.isValid && sel.baseOffset < text.count {
            let newOffset = sel.isCollapsed ? sel.baseOffset + 1 : sel.end
            selection = TextSelection(offset: newOffset)
        }
    }

    /// Moves the cursor to the beginning of the text.
    public func moveCursorToStart() {
        selection = TextSelection(offset: 0)
    }

    /// Moves the cursor to the end of the text.
    public func moveCursorToEnd() {
        selection = TextSelection(offset: text.count)
    }
}

