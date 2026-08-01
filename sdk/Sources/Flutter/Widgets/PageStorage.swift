// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// MARK: - PageStorageKey

/// A key that can be used to persist the widget state in storage after
/// destruction and will be restored when recreated.
///
/// Each key with its value plus the ancestor chain of other `PageStorageKey`s
/// need to be unique within the widget's closest ancestor `PageStorage`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/page_storage.dart:35-38`
public struct PageStorageKey<T: Hashable>: LocalKey {
    /// The value to which this key delegates its equality.
    public let value: T

    /// Creates a `ValueKey` that defines where `PageStorage` values will be saved.
    ///
    /// **Dart Source:** `page_storage.dart:37`
    public init(_ value: T) {
        self.value = value
    }

    public static func == (lhs: PageStorageKey<T>, rhs: PageStorageKey<T>) -> Bool {
        return lhs.value == rhs.value
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }

    public var description: String {
        let valueString: String
        if T.self == String.self {
            valueString = "<'\(value)'>"
        } else {
            valueString = "<\(value)>"
        }
        return "[PageStorageKey \(valueString)]"
    }
}

// MARK: - _StorageEntryIdentifier

/// Identifier for a storage entry based on the path of `PageStorageKey`s.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/page_storage.dart:41-64`
struct _StorageEntryIdentifier: Hashable, CustomStringConvertible {
    let keys: [AnyHashable]

    init(_ keys: [AnyHashable]) {
        self.keys = keys
    }

    var isNotEmpty: Bool { !keys.isEmpty }

    static func == (lhs: _StorageEntryIdentifier, rhs: _StorageEntryIdentifier) -> Bool {
        return lhs.keys == rhs.keys
    }

    func hash(into hasher: inout Hasher) {
        for key in keys {
            hasher.combine(key)
        }
    }

    var description: String {
        let keysString = keys.map { "\($0)" }.joined(separator: ":")
        return "StorageEntryIdentifier(\(keysString))"
    }
}

// MARK: - PageStorageBucket

/// A storage bucket associated with a page in an app.
///
/// Useful for storing per-page state that persists across navigations from one
/// page to another.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/page_storage.dart:70-134`
public class PageStorageBucket {
    public init() {}

    /// **Dart Source:** `page_storage.dart:71-78`
    private static func _maybeAddKey(_ context: any BuildContext, _ keys: inout [AnyHashable]) -> Bool {
        let widget = context.widget
        if let key = widget.key, let pageKey = key as? any _PageStorageKeyProtocol {
            keys.append(pageKey.anyValue)
        }
        return !(widget is PageStorage)
    }

    /// **Dart Source:** `page_storage.dart:80-88`
    private func _allKeys(_ context: any BuildContext) -> [AnyHashable] {
        var keys: [AnyHashable] = []
        if PageStorageBucket._maybeAddKey(context, &keys) {
            context.visitAncestorElements { element in
                return PageStorageBucket._maybeAddKey(element, &keys)
            }
        }
        return keys
    }

    /// **Dart Source:** `page_storage.dart:90-92`
    private func _computeIdentifier(_ context: any BuildContext) -> _StorageEntryIdentifier {
        return _StorageEntryIdentifier(_allKeys(context))
    }

    /// **Dart Source:** `page_storage.dart:94`
    private var _storage: [AnyHashable: Any]?

    /// Write the given data into this page storage bucket using the
    /// specified identifier or an identifier computed from the given context.
    ///
    /// The computed identifier is based on the `PageStorageKey`s found in the
    /// path from context to the `PageStorage` widget that owns this page
    /// storage bucket.
    ///
    /// If an explicit identifier is not provided and no `PageStorageKey`s
    /// are found, then the `data` is not saved.
    ///
    /// **Dart Source:** `page_storage.dart:104-114`
    public func writeState(_ context: any BuildContext, _ data: Any?, identifier: AnyHashable? = nil) {
        if _storage == nil {
            _storage = [:]
        }
        if let identifier = identifier {
            _storage![identifier] = data
        } else {
            let contextIdentifier = _computeIdentifier(context)
            if contextIdentifier.isNotEmpty {
                _storage![contextIdentifier] = data
            }
        }
    }

    /// Read given data from this page storage bucket using the specified
    /// identifier or an identifier computed from the given context.
    ///
    /// The computed identifier is based on the `PageStorageKey`s found in the
    /// path from context to the `PageStorage` widget that owns this page
    /// storage bucket.
    ///
    /// If an explicit identifier is not provided and no `PageStorageKey`s
    /// are found, then nil is returned.
    ///
    /// **Dart Source:** `page_storage.dart:124-133`
    public func readState(_ context: any BuildContext, identifier: AnyHashable? = nil) -> Any? {
        guard let storage = _storage else { return nil }
        if let identifier = identifier {
            return storage[identifier]
        }
        let contextIdentifier = _computeIdentifier(context)
        return contextIdentifier.isNotEmpty ? storage[contextIdentifier] : nil
    }
}

// MARK: - PageStorage

/// Establish a subtree in which widgets can opt into persisting states after
/// being destroyed.
///
/// `PageStorage` is used to save and restore values that can outlive the widget.
/// For example, when multiple pages are grouped in tabs, when a page is
/// switched out, its widget is destroyed and its state is lost. By adding a
/// `PageStorage` at the root and adding a `PageStorageKey` to each page, some of the
/// page's state (e.g. the scroll position of a `Scrollable` widget) will be stored
/// automatically in its closest ancestor `PageStorage`, and restored when it's
/// switched back.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/page_storage.dart:170-244`
public class PageStorage: StatelessWidget {
    /// The widget below this widget in the tree.
    ///
    /// **Dart Source:** `page_storage.dart:177`
    public let child: Widget

    /// The page storage bucket to use for this subtree.
    ///
    /// **Dart Source:** `page_storage.dart:180`
    public let bucket: PageStorageBucket

    /// Creates a widget that provides a storage bucket for its descendants.
    ///
    /// **Dart Source:** `page_storage.dart:172`
    public init(key: (any Key)? = nil, bucket: PageStorageBucket, child: Widget) {
        self.child = child
        self.bucket = bucket
        super.init(key: key)
    }

    /// The `PageStorageBucket` from the closest instance of a `PageStorage`
    /// widget that encloses the given context.
    ///
    /// Returns nil if none exists.
    ///
    /// This method can be expensive (it walks the element tree).
    ///
    /// **Dart Source:** `page_storage.dart:199-202`
    public static func maybeOf(_ context: any BuildContext) -> PageStorageBucket? {
        let widget: PageStorage? = context.findAncestorWidgetOfExactType(PageStorage.self)
        return widget?.bucket
    }

    /// The `PageStorageBucket` from the closest instance of a `PageStorage`
    /// widget that encloses the given context.
    ///
    /// If no ancestor is found, this method will assert in debug mode, and throw
    /// an exception in release mode.
    ///
    /// This method can be expensive (it walks the element tree).
    ///
    /// **Dart Source:** `page_storage.dart:222-240`
    public static func of(_ context: any BuildContext) -> PageStorageBucket {
        let bucket = maybeOf(context)
        assert(bucket != nil, """
            PageStorage.of() was called with a context that does not contain a \
            PageStorage widget.
            No PageStorage widget ancestor could be found starting from the \
            context that was passed to PageStorage.of().
            """)
        return bucket!
    }

    /// **Dart Source:** `page_storage.dart:243`
    public override func build(_ context: any BuildContext) -> Widget {
        return child
    }
}

// MARK: - _PageStorageKeyProtocol (internal)

/// Internal protocol for type-erasing PageStorageKey values.
///
/// Since `PageStorageKey<T>` is generic and we need to check if a key is
/// any kind of PageStorageKey in `PageStorageBucket._maybeAddKey`, this
/// protocol provides type erasure.
protocol _PageStorageKeyProtocol {
    /// The type-erased value of this PageStorageKey.
    var anyValue: AnyHashable { get }
}

extension PageStorageKey: _PageStorageKeyProtocol {
    var anyValue: AnyHashable { AnyHashable(value) }
}
