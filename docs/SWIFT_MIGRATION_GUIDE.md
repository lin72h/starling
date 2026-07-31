# Flutter Engine dart:ui to Swift 6 Migration Guide

## Executive Summary

**Goal:** Migrate Flutter's `engine/src/flutter/lib/ui` code from Dart to Swift 6, creating a pure Swift glue layer between the Flutter framework (which will be ported to Swift) and the Flutter C++ engine. This eliminates the Dart VM dependency entirely.

**Architecture:**
```
Flutter Framework (Swift - future)
         ↓
    dart:ui layer (Swift - this migration)
         ↓
    C++ Engine (Flutter engine core)
```

**Key Technical Advantages:**
- Swift 6's native C++ interoperability eliminates need for @Native annotations and Dart FFI
- Direct C++ calls without Dart VM overhead
- No Dart VM dependency - pure Swift to C++ bridge
- Direct memory management and value semantics for better performance
- Modern concurrency primitives available (though thread-safety ignored initially)
- Strong type safety and compile-time guarantees

**Approach:** Proof-of-concept first with small modules, dual implementation maintained in parallel

**Critical Difference from Dart Implementation:**
- **Remove ALL Dart VM related code**: No `@pragma('vm:entry-point')`, no Dart VM API calls, no dart_wrapper
- The Swift layer is **NOT** called from C++, it **CALLS** C++ directly
- This is a glue/bridge layer, not an engine entry point layer

---

## Migration Phases Overview

### Phase 1: Foundation & Proof of Concept
- Infrastructure setup (build system integration)
- Select 1-2 simple modules for PoC (e.g., math.dart, lerp.dart)
- Validate Swift 6 C++ interop works with Flutter engine
- Establish testing framework and build process

### Phase 2: Core Primitives
- Migrate geometry and basic data structures
- Establish patterns for remaining migrations

### Phase 3: Platform Integration
- Migrate platform dispatcher and related types
- Migrate hooks (convert from C++→Dart callbacks to Swift→C++ calls)

### Phase 4: Advanced Features
- Migrate complex subsystems (text, compositing, semantics, painting)

### Phase 5: Testing & Validation
- Comprehensive testing and performance validation
- Integration testing with full Flutter engine

---

## General Migration Principles

### 1. Code Organization

**Directory Structure:**
```
engine/src/flutter/lib/ui/
├── dart/                      # Keep existing Dart implementation
│   ├── geometry.dart
│   ├── lerp.dart
│   ├── painting.dart
│   └── ...
└── swift/                     # C++ bridge code (built by Flutter build system)
    ├── include/               # C++ bridge headers (Swift compiles these)
    │   ├── intrusive_reference_counted.h
    │   ├── rsuperellipse_bridge.h   # Example: RSuperellipse bridge
    │   ├── canvas_bridge.h
    │   ├── paint_bridge.h
    │   └── ...
    ├── src/                   # C++ bridge implementation
    │   ├── rsuperellipse_bridge.cc  # Example: RSuperellipse implementation
    │   ├── canvas_bridge.cc
    │   ├── paint_bridge.cc
    │   └── ...
    └── BUILD.gn               # GN build rules for C++ bridge

flutter_swift/                 # Swift package (project root)
├── Package.swift              # Swift Package Manager manifest
├── libswift_bridge.dylib -> ../engine/src/out/ci/host_debug_unopt_arm64/libswift_bridge.dylib
│                              # Symlink so swift test can find the library
├── Sources/
│   ├── FlutterSwiftBridge/    # Swift implementation
│   │   ├── RSuperellipse.swift    # Example: RSuperellipse Swift wrapper
│   │   ├── Geometry.swift
│   │   ├── Lerp.swift
│   │   ├── Painting.swift
│   │   └── ...
│   └── FlutterSwiftBridgeCxx/ # Module for C++ bridge headers
│       ├── include/
│       │   └── module.modulemap   # Points to engine bridge headers
│       └── placeholder.c          # Required for SwiftPM target
└── Tests/
    └── FlutterSwiftBridgeTests/
        ├── RSuperellipseTests.swift
        ├── GeometryTests.swift
        ├── LerpTests.swift
        └── ...
```

**Note:** The `libswift_bridge.dylib` symlink in `flutter_swift/` points to the library built by `et build`. This allows `swift test` to find the C++ bridge library at runtime.

### 2. Code Documentation & Traceability

**CRITICAL REQUIREMENT:** Every migrated Swift class/struct/function MUST include a reference to the original Dart code.

**Documentation Format:**
```swift
// MARK: - Offset
/// An immutable 2D floating-point offset.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/geometry.dart`
/// **Original Name:** `Offset`
/// **Lines:** 94-350
///
/// See also:
///  * Dart implementation at geometry.dart:94
public struct Offset: OffsetBase, Hashable {
    public let dx: Double
    public let dy: Double

    /// Creates an offset.
    ///
    /// **Dart Source:** `geometry.dart:105-107`
    /// **Original:** `Offset(this.dx, this.dy)`
    public init(_ dx: Double, _ dy: Double) {
        self.dx = dx
        self.dy = dy
    }

    /// The magnitude of the offset.
    ///
    /// **Dart Source:** `geometry.dart:154-156`
    /// **Original:** `double get distance => math.sqrt(_dx * _dx + _dy * _dy);`
    public var distance: Double {
        sqrt(dx * dx + dy * dy)
    }

    // ... more members with references
}
```

**For Each Function:**
```swift
/// Linearly interpolate between two numbers.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/lerp.dart:13-23`
/// **Original Name:** `lerpDouble`
///
/// When `a` and `b` are equal or both NaN, `a` is returned.
/// Otherwise, `a`, `b`, and `t` are required to be finite or null,
/// and the result of `a + (b - a) * t` is returned.
public func lerpDouble(_ a: Double?, _ b: Double?, _ t: Double) -> Double? {
    // Implementation matching Dart behavior
    if a == b || (a?.isNaN ?? false) && (b?.isNaN ?? false) {
        return a
    }
    let a = a ?? 0.0
    let b = b ?? 0.0
    assert(a.isFinite, "Cannot interpolate between finite and non-finite values")
    assert(b.isFinite, "Cannot interpolate between finite and non-finite values")
    assert(t.isFinite, "t must be finite when interpolating between values")
    return a * (1.0 - t) + b * t
}
```

**Benefits:**
- Easy to cross-reference during code review
- Simplifies future maintenance when Dart code changes
- Helps track migration progress
- Essential for debugging behavioral differences

### 3. Type Mapping Guidelines

| Dart Type | Swift Type | Notes |
|-----------|------------|-------|
| `double` | `Double` | Direct mapping |
| `int` | `Int64` | Use Int64 for consistency with Dart's 64-bit integers |
| `bool` | `Bool` | Direct mapping |
| `String` | `String` | **CAUTION:** Dart uses UTF-16, Swift uses UTF-8 |
| `List<T>` | `[T]` or `ContiguousArray<T>` | Use ContiguousArray for performance-critical code |
| `Uint8List` | `[UInt8]` or `Data` | Consider UnsafeBufferPointer for C++ interop |
| `ByteData` | `Data` | Handle byte offset carefully |
| `class` (mutable) | `class` | Reference semantics |
| `class` (immutable value-like) | `struct` | Value semantics, copy-on-write |
| `enum` | `enum` | Direct mapping |
| `abstract class` | `protocol` or `protocol + extension` | Use protocol for interface, extension for default implementations |
| `typedef` | `typealias` | Direct mapping |
| `T?` (nullable) | `T?` (Optional) | Nearly 1:1 mapping |

**String Handling:**
- Be aware of UTF-16 (Dart) vs UTF-8 (Swift) differences
- Test thoroughly with emoji, surrogate pairs, combining characters
- Consider using `String.UTF16View` when interfacing with Dart/C++ code that expects UTF-16

### 4. Code Structure Patterns

#### Abstract Classes → Protocols with Extensions

**Dart:**
```dart
abstract class OffsetBase {
  const OffsetBase(this._dx, this._dy);
  final double _dx;
  final double _dy;

  bool get isFinite => _dx.isFinite && _dy.isFinite;
  bool get isInfinite => _dx >= double.infinity || _dy >= double.infinity;
}
```

**Swift:**
```swift
/// **Dart Source:** `geometry.dart:7-92`
/// **Original:** `OffsetBase` abstract class
public protocol OffsetBase {
    var dx: Double { get }
    var dy: Double { get }
}

extension OffsetBase {
    /// **Dart Source:** `geometry.dart:31-37`
    public var isFinite: Bool {
        dx.isFinite && dy.isFinite
    }

    /// **Dart Source:** `geometry.dart:20-29`
    public var isInfinite: Bool {
        dx >= .infinity || dy >= .infinity
    }
}
```

#### Immutable Value Types → Structs

**Dart:**
```dart
class Offset extends OffsetBase {
  const Offset(double dx, double dy) : super(dx, dy);

  Offset operator +(Offset other) {
    return Offset(_dx + other._dx, _dy + other._dy);
  }
}
```

**Swift:**
```swift
/// **Dart Source:** `geometry.dart:94-350`
public struct Offset: OffsetBase, Hashable {
    public let dx: Double
    public let dy: Double

    /// **Dart Source:** `geometry.dart:105-107`
    public init(_ dx: Double, _ dy: Double) {
        self.dx = dx
        self.dy = dy
    }

    /// **Dart Source:** `geometry.dart:197-199`
    public static func + (lhs: Offset, rhs: Offset) -> Offset {
        Offset(lhs.dx + rhs.dx, lhs.dy + rhs.dy)
    }
}
```

#### Factory Constructors → Static Methods or Factory Namespaces

**Pattern 1: Named Factory Constructor → Static Method**

**Dart:**
```dart
class Rect {
  factory Rect.fromLTRB(double left, double top, double right, double bottom) {
    return Rect._(...);
  }
}
```

**Swift:**
```swift
/// **Dart Source:** `geometry.dart:XXX`
public struct Rect {
    /// **Dart Source:** `geometry.dart:XXX-XXX`
    public static func fromLTRB(_ left: Double, _ top: Double,
                                 _ right: Double, _ bottom: Double) -> Rect {
        Rect(...)
    }
}
```

**Pattern 2: Redirecting Factory for Protocols → Factory Namespace Enum**

When Dart uses `factory ProtocolName() = ConcreteImplementation;` to provide a default implementation for an abstract class/protocol, Swift cannot use factory constructors on protocols. Instead, use a factory namespace enum with a plural name.

**Dart:**
```dart
abstract class SceneBuilder {
  factory SceneBuilder() = _NativeSceneBuilder;

  // abstract methods...
}
```

**Swift:**
```swift
/// **Dart Source:** `compositing.dart:240-591`
public protocol SceneBuilder: AnyObject {
    // protocol methods...
}

/// **Dart Source:** `compositing.dart:593-1084`
public class NativeSceneBuilder: SceneBuilder {
    // implementation...
}

// MARK: - SceneBuilders Factory

/// Factory namespace for creating SceneBuilder instances.
///
/// **Dart Source:** `compositing.dart:262`
/// **Original:** `factory SceneBuilder() = _NativeSceneBuilder;`
///
/// In Dart, `SceneBuilder` has a factory constructor that returns a
/// `_NativeSceneBuilder`. In Swift, protocols cannot have factory
/// initializers, so this enum serves as the factory namespace.
///
/// DIFFERENCE FROM DART: Uses an enum factory namespace instead of factory constructor.
/// REASON: Swift protocols cannot have factory constructors. This pattern provides
/// equivalent ergonomics while maintaining type safety.
public enum SceneBuilders {
    /// Creates a new `SceneBuilder`.
    ///
    /// **Dart Source:** `compositing.dart:262`
    /// **Original:** `factory SceneBuilder() = _NativeSceneBuilder;`
    ///
    /// Equivalent to Dart's `SceneBuilder()` factory constructor.
    public static func create() -> any SceneBuilder {
        return NativeSceneBuilder()
    }
}
```

**Usage Comparison:**
```swift
// Dart: let builder = SceneBuilder();
// Swift: let builder = SceneBuilders.create()

// Dart: let recorder = PictureRecorder();
// Swift: let recorder = PictureRecorders.create()
```

**Key Features:**
- **Plural naming**: `SceneBuilders`, `PictureRecorders` (plural) distinguish the factory namespace from the protocol
- **`.create()` method**: Consistent API across all factory namespaces
- **Protocol return type**: Returns `any SceneBuilder` for flexibility
- **Clear documentation**: References original Dart factory constructor
- **Type safety**: Maintains Swift's type system while providing Dart-like ergonomics

#### Named Constructors → Multiple Initializers

**Dart:**
```dart
class Size {
  const Size(this.width, this.height);
  const Size.square(double dimension) : width = dimension, height = dimension;
  const Size.fromWidth(double width) : width = width, height = double.infinity;
}
```

**Swift:**
```swift
/// **Dart Source:** `geometry.dart:XXX`
public struct Size {
    public let width: Double
    public let height: Double

    /// **Dart Source:** `geometry.dart:XXX`
    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    /// **Dart Source:** `geometry.dart:XXX`
    public init(square dimension: Double) {
        self.width = dimension
        self.height = dimension
    }

    /// **Dart Source:** `geometry.dart:XXX`
    public init(fromWidth width: Double) {
        self.width = width
        self.height = .infinity
    }
}
```

#### Constants → Static Properties

**Dart:**
```dart
class Offset {
  static const Offset zero = Offset(0.0, 0.0);
  static const Offset infinite = Offset(double.infinity, double.infinity);
}
```

**Swift:**
```swift
/// **Dart Source:** `geometry.dart:XXX`
extension Offset {
    /// **Dart Source:** `geometry.dart:XXX`
    public static let zero = Offset(0.0, 0.0)

    /// **Dart Source:** `geometry.dart:XXX`
    public static let infinite = Offset(.infinity, .infinity)
}
```

### 5. Error Handling & Assertions

**Dart:**
```dart
assert(a.isFinite, 'Cannot interpolate between finite and non-finite values');
throw ArgumentError('Invalid value');
```

**Swift:**
```swift
// Debug assertions (stripped in release)
assert(a.isFinite, "Cannot interpolate between finite and non-finite values")

// Preconditions (always checked)
precondition(a.isFinite, "Cannot interpolate between finite and non-finite values")

// Throwing errors
enum FlutterSwiftBridgeError: Error {
    case invalidArgument(String)
}
throw FlutterSwiftBridgeError.invalidArgument("Invalid value")
```

**Guidelines:**
- Match Dart's `assert()` with Swift's `assert()` for debug-only checks
- Use `precondition()` for conditions that should always be checked
- Create Swift error types for exception scenarios
- Maintain same error messages for consistency

### 6. C++ Interoperability

**Swift 6 Direct C++ Interop:**

Swift 6 can directly call C++ code. Enable with:
```swift
// In Package.swift
swiftSettings: [
    .interoperabilityMode(.Cxx)
]
```

**⚠️ CRITICAL: Swift Calls C++ (Not the Other Way Around)**

The Swift layer is a **glue layer** between Flutter framework and C++ engine. Swift calls C++, C++ does NOT call Swift.

**What to Remove from Dart Code:**

When migrating, **REMOVE** all Dart VM related code:

❌ **Remove:**
- `@pragma('vm:entry-point')` annotations - not needed in Swift
- `@Native<...>` annotations - Swift calls C++ directly
- Dart VM API calls (Dart_Handle, Dart_ThrowException, etc.)
- `AssociateWithDartWrapper()` calls
- `IMPLEMENT_WRAPPERTYPEINFO` usage
- Any Dart VM FFI code

✅ **Keep (translate to Swift):**
- Business logic and algorithms
- Data structures and types
- Validation and error handling
- C++ engine API calls (translate from @Native to direct Swift calls)

### 7. C++ Bridge Layer for Swift Interop

**Core Principle:** Swift cannot compile Flutter engine headers. Create a separate bridge layer with clean C++ headers.

#### 7.1 IntrusiveReferenceCounted Base Class

First, create a reusable reference counting base class:

```cpp
// engine/src/flutter/lib/ui/swift/include/intrusive_reference_counted.h
#ifndef FLUTTER_SWIFT_INTRUSIVE_REFERENCE_COUNTED_H_
#define FLUTTER_SWIFT_INTRUSIVE_REFERENCE_COUNTED_H_

#include <atomic>

template <typename T>
class IntrusiveReferenceCounted {
 public:
  IntrusiveReferenceCounted() : ref_count_(1) {}

  void Retain() {
    ref_count_.fetch_add(1, std::memory_order_relaxed);
  }

  void Release() {
    if (ref_count_.fetch_sub(1, std::memory_order_release) == 1) {
      std::atomic_thread_fence(std::memory_order_acquire);
      delete static_cast<T*>(this);
    }
  }

 protected:
  ~IntrusiveReferenceCounted() = default;

 private:
  std::atomic<int> ref_count_;
};

#endif
```

**Key features:**
- Starts with ref_count=1
- Thread-safe atomic operations
- CRTP pattern for type-safe deletion
- SWIFT_SHARED_REFERENCE compatible

#### 7.2 Bridge Header Requirements

Every bridge header MUST follow these rules:

**Bridge header checklist (files in `engine/src/flutter/lib/ui/swift/include/`):**
- ❌ NO Flutter engine `#include` statements
- ✅ `#include <swift/bridging>` for SWIFT_SHARED_REFERENCE macro
- ✅ `#include "intrusive_reference_counted.h"` for base class
- ✅ Forward declarations only: `namespace flutter { class Canvas; }`
- ✅ Use pimpl pattern with forward-declared impl struct
- ✅ Inherit from `IntrusiveReferenceCounted<BridgeClassName>`
- ✅ Declare global Retain/Release functions BEFORE the class (Swift requirement)
- ✅ Add `SWIFT_SHARED_REFERENCE(RetainXxx, ReleaseXxx)` annotation
- ✅ Add `__attribute__((visibility("default")))`
- ✅ Public constructor with primitive types only (Swift calls directly)
- ✅ Public destructor (needed for pimpl cleanup)
- ✅ Delete copy constructor and assignment operator
- ✅ Methods with primitive types or `void*` parameters
- ✅ Inline definitions of global Retain/Release functions at end of header

**Bridge implementation checklist (files in `engine/src/flutter/lib/ui/swift/src/`):**
- ✅ CAN include Flutter engine headers
- ✅ Define the pimpl struct with actual Flutter types
- ✅ Wraps actual Flutter C++ objects
- ✅ Converts between primitive types and Flutter types (use SafeNarrow for double→float)
- ✅ Implements constructors and methods declared in header

#### 7.3 Complete Example: RSuperellipse Bridge

This is a real working example from the codebase showing all three layers.

**Step 1: Bridge Header (engine/src/flutter/lib/ui/swift/include/rsuperellipse_bridge.h)**
```cpp
#ifndef FLUTTER_SWIFT_RSUPERELLIPSE_BRIDGE_H_
#define FLUTTER_SWIFT_RSUPERELLIPSE_BRIDGE_H_

#include <swift/bridging>
#include "intrusive_reference_counted.h"

namespace flutter::swift_bridge {

// Forward declaration for retain/release functions
class RSuperellipseBridge;

}  // namespace flutter::swift_bridge

// Free functions for SWIFT_SHARED_REFERENCE - must be at global scope
void RetainRSuperellipseBridge(flutter::swift_bridge::RSuperellipseBridge* p) noexcept;
void ReleaseRSuperellipseBridge(flutter::swift_bridge::RSuperellipseBridge* p) noexcept;

namespace flutter::swift_bridge {

// Forward declarations for pimpl
struct RSuperellipseImpl;

/// C++ bridge wrapping Flutter's RSuperellipse.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/geometry.dart:2051-2110`
class __attribute__((visibility("default")))
    SWIFT_SHARED_REFERENCE(RetainRSuperellipseBridge, ReleaseRSuperellipseBridge)
        RSuperellipseBridge
    : public IntrusiveReferenceCounted<RSuperellipseBridge> {
 public:
  /// Creates an RSuperellipseBridge wrapping a Flutter RSuperellipse.
  RSuperellipseBridge(double left,
                      double top,
                      double right,
                      double bottom,
                      double tl_radius_x,
                      double tl_radius_y,
                      double tr_radius_x,
                      double tr_radius_y,
                      double br_radius_x,
                      double br_radius_y,
                      double bl_radius_x,
                      double bl_radius_y);

  /// Checks if a point is contained within the rounded superellipse.
  bool Contains(double x, double y) const;

  ~RSuperellipseBridge();

 private:
  RSuperellipseBridge(const RSuperellipseBridge&) = delete;
  RSuperellipseBridge& operator=(const RSuperellipseBridge&) = delete;

  // Pimpl - holds the actual Flutter types
  RSuperellipseImpl* impl_;
};

}  // namespace flutter::swift_bridge

// Inline definitions for global retain/release functions
inline void RetainRSuperellipseBridge(flutter::swift_bridge::RSuperellipseBridge* p) noexcept {
  p->Retain();
}
inline void ReleaseRSuperellipseBridge(flutter::swift_bridge::RSuperellipseBridge* p) noexcept {
  p->Release();
}

#endif  // FLUTTER_SWIFT_RSUPERELLIPSE_BRIDGE_H_
```

**Key patterns in the header:**
1. `#include <swift/bridging>` - Required for SWIFT_SHARED_REFERENCE macro
2. Forward declare the class before global Retain/Release functions
3. Retain/Release functions at global scope (Swift requirement)
4. Use pimpl pattern (`RSuperellipseImpl*`) to hide Flutter types
5. Delete copy constructor and assignment operator
6. Public destructor (needed for pimpl cleanup)
7. Inline Retain/Release definitions at end of header

**Step 2: Bridge Implementation (engine/src/flutter/lib/ui/swift/src/rsuperellipse_bridge.cc)**
```cpp
#include "include/rsuperellipse_bridge.h"

// Flutter engine headers (only in .cc file)
#include "flutter/display_list/geometry/dl_geometry_types.h"
#include "flutter/impeller/geometry/round_superellipse_param.h"
#include "flutter/impeller/geometry/rounding_radii.h"

#include <algorithm>
#include <cmath>
#include <limits>

namespace flutter::swift_bridge {

namespace {
// Inline SafeNarrow to avoid dependency on //flutter/lib/ui:ui
inline float SafeNarrow(double value) {
  if (std::isinf(value) || std::isnan(value)) {
    return static_cast<float>(value);
  }
  return std::clamp(static_cast<float>(value),
                    std::numeric_limits<float>::lowest(),
                    std::numeric_limits<float>::max());
}
}  // namespace

// Pimpl implementation holding actual Flutter types
struct RSuperellipseImpl {
  flutter::DlRect bounds;
  impeller::RoundingRadii radii;

  RSuperellipseImpl(flutter::DlRect b, impeller::RoundingRadii r)
      : bounds(b), radii(r) {}
};

RSuperellipseBridge::RSuperellipseBridge(double left,
                                         double top,
                                         double right,
                                         double bottom,
                                         double tl_radius_x,
                                         double tl_radius_y,
                                         double tr_radius_x,
                                         double tr_radius_y,
                                         double br_radius_x,
                                         double br_radius_y,
                                         double bl_radius_x,
                                         double bl_radius_y) {
  // Build bounds (same as rsuperellipse.cc:15-22)
  flutter::DlRect bounds = flutter::DlRect::MakeLTRB(
      SafeNarrow(left), SafeNarrow(top),
      SafeNarrow(right), SafeNarrow(bottom)).GetPositive();

  // Build radii (same as rsuperellipse.cc:24-40)
  impeller::RoundingRadii radii{
      .top_left = flutter::DlSize(SafeNarrow(tl_radius_x),
                                  SafeNarrow(tl_radius_y)),
      .top_right = flutter::DlSize(SafeNarrow(tr_radius_x),
                                   SafeNarrow(tr_radius_y)),
      .bottom_left = flutter::DlSize(SafeNarrow(bl_radius_x),
                                     SafeNarrow(bl_radius_y)),
      .bottom_right = flutter::DlSize(SafeNarrow(br_radius_x),
                                      SafeNarrow(br_radius_y)),
  };

  impl_ = new RSuperellipseImpl(bounds, radii);
}

RSuperellipseBridge::~RSuperellipseBridge() {
  delete impl_;
}

bool RSuperellipseBridge::Contains(double x, double y) const {
  // Same logic as rsuperellipse.cc:83-89
  flutter::DlPoint point(SafeNarrow(x), SafeNarrow(y));

  if (!impl_->bounds.Contains(point)) {
    return false;
  }

  auto param = impeller::RoundSuperellipseParam::MakeBoundsRadii(
      impl_->bounds, impl_->radii);
  return param.Contains(point);
}

}  // namespace flutter::swift_bridge
```

**Key patterns in the implementation:**
1. Include the bridge header from `include/` directory
2. NOW include Flutter engine headers (DlRect, RoundingRadii, etc.)
3. Define the pimpl struct with actual Flutter types
4. Use SafeNarrow() to convert double→float safely
5. Destructor deletes the pimpl

**Step 3: Swift Wrapper (flutter_swift/Sources/FlutterSwiftBridge/RSuperellipse.swift)**
```swift
import FlutterSwiftBridgeCxx

/// Swift wrapper for Flutter's RSuperellipse.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/geometry.dart:1808-2049`
///
/// This class wraps the C++ RSuperellipseBridge which in turn wraps
/// Flutter's DlRect and RoundingRadii via pimpl pattern.
public class RSuperellipse {
    // C++ bridge object - Swift ARC handles lifetime via SWIFT_SHARED_REFERENCE
    private let bridge: flutter.swift_bridge.RSuperellipseBridge

    /// Creates an RSuperellipse with the given bounds and corner radii.
    ///
    /// **Dart Source:** `geometry.dart:2052-2067` (_NativeRSuperellipse constructor)
    public init(
        left: Double,
        top: Double,
        right: Double,
        bottom: Double,
        tlRadiusX: Double,
        tlRadiusY: Double,
        trRadiusX: Double,
        trRadiusY: Double,
        brRadiusX: Double,
        brRadiusY: Double,
        blRadiusX: Double,
        blRadiusY: Double
    ) {
        // Direct call to C++ bridge constructor
        self.bridge = flutter.swift_bridge.RSuperellipseBridge(
            left, top, right, bottom,
            tlRadiusX, tlRadiusY,
            trRadiusX, trRadiusY,
            brRadiusX, brRadiusY,
            blRadiusX, blRadiusY
        )
    }

    /// Whether the point lies inside the rounded superellipse.
    ///
    /// **Dart Source:** `geometry.dart:2101-2109`
    public func contains(x: Double, y: Double) -> Bool {
        return bridge.Contains(x, y)
    }
}
```

**Key patterns in the Swift wrapper:**
1. `import FlutterSwiftBridgeCxx` - Import the C++ module (see module.modulemap below)
2. Reference bridge class with full namespace: `flutter.swift_bridge.RSuperellipseBridge`
3. Call C++ constructor directly - Swift handles memory via SWIFT_SHARED_REFERENCE
4. No `deinit` needed - Swift ARC automatically calls Release()
5. Document Dart source references for traceability

**Step 4: Module Map (sdk/Sources/FlutterSwiftBridgeCxx/include/module.modulemap)**
```
module FlutterSwiftBridgeCxx {
    header "engine/intrusive_reference_counted.h"
    header "engine/rsuperellipse_bridge.h"
    export *
    requires cplusplus
}
```

The headers are **vendored** into `include/engine/`, not read out of the engine
checkout. So adding a bridge header is two steps:

```bash
# 1. declare it in the modulemap (the line above), then
sdk/tools/sync-vendored-headers.sh
```

The modulemap is the manifest that script reads, so the header list lives in one
place. `sync-engine-headers.sh --check` reports drift, and drift is worth taking
seriously: these headers describe the ABI of the `libflutter_engine` being linked,
so a stale copy is not a compile error, it is a crash at runtime.

**Key patterns in the module map:**
1. Paths are relative to `include/`, pointing at the vendored copies
2. Include all bridge headers that Swift needs to compile
3. `requires cplusplus` since these are C++ headers

A bridge header that includes anything from the wider engine tree cannot be
vendored — that is why `swift_runtime_controller.h` is deliberately absent: it
reaches `flutter/runtime/runtime_controller_interface.h` and from there FML,
tonic and `dart_api.h`. Keep bridge headers closed over their own directory.

**Step 5: BUILD.gn (engine/src/flutter/lib/ui/swift/BUILD.gn)**
```python
shared_library("swift_bridge") {
  sources = [
    # Bridge headers (Swift-compatible, no Flutter includes)
    "include/intrusive_reference_counted.h",
    "include/rsuperellipse_bridge.h",

    # Bridge implementations
    "src/rsuperellipse_bridge.cc",
  ]

  public_configs = [
    ":swift_bridge_config",
    "//flutter:config",
  ]

  deps = [
    ":intrusive_reference_counted",
    "//flutter/display_list",
    "//flutter/impeller/geometry",
  ]
}
```

**Key patterns in BUILD.gn:**
1. Build as `shared_library` so Swift can link against it
2. List both headers and implementations in sources
3. Add deps for Flutter engine libraries used in implementations

**⚠️ CRITICAL: Never depend on anything under `//flutter/lib/ui/`**

Everything under `//flutter/lib/ui/` is the **Dart UI layer** that we are replacing with Swift. The C++ bridge code in `engine/src/flutter/lib/ui/swift/` must NEVER add ANY dependency from `//flutter/lib/ui/` in BUILD.gn.

❌ **WRONG - Never do this:**
```python
deps = [
  "//flutter/lib/ui",              # NO! Dart UI layer
  "//flutter/lib/ui:ui",           # NO! Dart UI layer
  "//flutter/lib/ui/window",       # NO! Dart UI layer
  "//flutter/lib/ui/window:window", # NO! Dart UI layer
  "//flutter/lib/ui/painting",     # NO! Dart UI layer
  # ANY path starting with //flutter/lib/ui/ is FORBIDDEN
]
```

✅ **CORRECT - Depend on underlying engine libraries:**
```python
deps = [
  "//flutter/display_list",
  "//flutter/impeller/geometry",
  "//flutter/fml",
  "//third_party/skia",
  # etc. - actual engine implementation libraries OUTSIDE of lib/ui/
]
```

The Swift bridge should depend on the **underlying C++ engine libraries** (display_list, impeller, fml, skia, etc.), NOT on anything under `//flutter/lib/ui/`. If you need functionality from `lib/ui`, find the underlying engine library it wraps and depend on that instead.

**How this example works:**

**Data flow:**
```
Swift RSuperellipse class (flutter_swift/)
    ↓ calls constructor
RSuperellipseBridge (C++ bridge header in engine/.../swift/include/) - Swift compiles this
    ↓ implementation
rsuperellipse_bridge.cc (in engine/.../swift/src/) - wraps DlRect + RoundingRadii
    ↓ calls
Flutter Impeller geometry (actual Flutter engine implementation)
```

**Memory management:**
1. Swift: `RSuperellipseBridge(...)` - ref_count starts at 1
2. Swift stores in property - SWIFT_SHARED_REFERENCE doesn't increment (same owner)
3. When Swift RSuperellipse object deallocates, Swift calls `ReleaseRSuperellipseBridge()`
4. `Release()` decrements ref_count to 0, deletes RSuperellipseBridge
5. ~RSuperellipseBridge() deletes the pimpl, cleaning up Flutter types

**Key takeaways:**
- ✅ Bridge header: NO Flutter includes, uses pimpl pattern, global Retain/Release functions
- ✅ Bridge implementation: CAN include Flutter headers, defines pimpl struct, uses SafeNarrow
- ✅ Swift wrapper: Clean API, imports C++ module, uses full namespace for bridge class
- ✅ Module map: Points to engine bridge headers with relative paths
- ✅ BUILD.gn: Builds shared library with Flutter engine deps
- ✅ All five components work together seamlessly

### 8. Removing Dart VM Dependencies

**CRITICAL:** The Swift implementation has NO Dart VM. All VM-related code must be removed during migration.

**Dart VM Patterns to Remove:**

#### 1. VM Entry Points
❌ **Dart (with VM):**
```dart
@pragma('vm:entry-point')
void _beginFrame(int microseconds, int frameNumber) {
  PlatformDispatcher.instance._beginFrame(microseconds);
}

@pragma('vm:entry-point')
void _drawFrame() {
  PlatformDispatcher.instance._drawFrame();
}
```

✅ **Swift (no VM):**
```swift
// These are NOT needed in Swift!
// The Swift framework will call PlatformDispatcher directly
// No C++ → Swift calls in this architecture
```

#### 2. Native Annotations (@Native)
❌ **Dart (with FFI):**
```dart
@Native<Int32 Function(Pointer<Void>)>(symbol: 'Image::width', isLeaf: true)
external int get width;
```

✅ **Swift (direct C++):**
```swift
/// **Dart Source:** `painting.dart:2185-2186`
public var width: Int {
    return Int(cppImage.width())  // Direct C++ call
}
```

#### 3. Dart VM API Calls in C++
When you look at C++ files (e.g., `canvas.cc`), you'll see Dart VM API calls:

❌ **C++ code calling Dart VM (ignore these patterns):**
```cpp
// These patterns are for Dart VM integration - NOT needed for Swift

void Canvas::Create(Dart_Handle wrapper, ...) {  // ← Dart VM handle
  UIDartState::ThrowIfUIOperationsProhibited();   // ← Dart VM check

  Dart_ThrowException(ToDart("Error"));           // ← Dart VM exception

  canvas->AssociateWithDartWrapper(wrapper);      // ← Dart VM wrapper
}

IMPLEMENT_WRAPPERTYPEINFO(ui, Canvas);            // ← Dart VM macro
```

✅ **Swift approach:**
```swift
// Swift calls C++ directly, no wrapper association needed
// C++ classes use SWIFT_SHARED_REFERENCE for automatic memory management

public class Canvas {
    // C++ object with SWIFT_SHARED_REFERENCE - Swift ARC handles lifetime
    private let cppCanvas: CppCanvas

    /// **Dart Source:** `painting.dart:XXX`
    /// **Note:** Dart version used Dart_Handle wrapper, Swift directly wraps C++ object
    ///          C++ Canvas uses SWIFT_SHARED_REFERENCE, no manual memory management
    public init(recorder: PictureRecorder, bounds: Rect) {
        // Call C++ directly to create canvas
        // C++ returns a SWIFT_SHARED_REFERENCE object
        self.cppCanvas = CppCanvas.create(recorder.cppRecorder, bounds.toCpp())
        // Swift ARC automatically retains the C++ object
    }

    // No deinit needed - Swift ARC automatically releases cppCanvas
}
```

#### 4. Hooks File Pattern

The `hooks.dart` file is full of VM entry points. These need complete redesign:

❌ **Dart (C++ calls into Dart VM):**
```dart
// hooks.dart - VM entry points called by C++ engine
@pragma('vm:entry-point')
void _updateWindowMetrics(int viewId, double devicePixelRatio, ...) {
  PlatformDispatcher.instance._updateWindowMetrics(viewId, ...);
}

@pragma('vm:entry-point')
void _dispatchPlatformMessage(String name, ByteData? data, int responseId) {
  PlatformDispatcher.instance._dispatchPlatformMessage(name, data, responseId);
}
```

✅ **Swift (completely different approach):**
```swift
// NO direct equivalents needed!
// These were for C++ → Dart communication via VM

// Instead, the Swift framework will need to:
// 1. Provide callback registration APIs
// 2. Poll or receive events from C++ engine through a different mechanism
// (This is a future architecture consideration beyond this migration)

// For now, focus on Swift → C++ calls:
public class PlatformDispatcher {
    /// **Dart Source:** `platform_dispatcher.dart:XXX`
    /// **Note:** Dart version was called BY C++ engine via VM entry point.
    ///          Swift version is called BY framework, not by C++.
    public func sendPlatformMessage(name: String, data: Data?, callback: @escaping (Data?) -> Void) {
        // Swift calls C++ to send message
        CppPlatformDispatcher.sendMessage(name, data, callback)
    }
}
```

#### 5. C++ Classes with Dart VM Dependencies

When looking at C++ headers (e.g., `canvas.h`), ignore Dart VM specific code:

❌ **C++ with Dart VM (from canvas.h - ignore these parts):**
```cpp
class Canvas : public RefCountedDartWrappable<Canvas> {  // ← Dart VM base class
 public:
  static void Create(Dart_Handle wrapper, ...);          // ← VM entry

  void save();                                           // ← Keep this
  void restore();                                        // ← Keep this
  void drawRect(...);                                    // ← Keep this

 private:
  sk_sp<DisplayListBuilder> display_list_builder_;       // ← Keep this
};
```

✅ **What to migrate to Swift:**
- The **actual functionality** (save, restore, drawRect)
- The **C++ object references** (DisplayListBuilder)
- The **business logic**

✅ **What NOT to migrate:**
- Dart VM wrapper infrastructure
- VM entry point static methods
- Dart VM exception throwing

### 9. Testing Requirements

**Test Migration Strategy:**

1. **Port Existing Dart Tests:** Tests from `engine/src/flutter/testing/dart/` should be ported to Swift XCTest
2. **Maintain Test Coverage:** Every ported Dart test must have corresponding Swift test
3. **Test File Naming:** Mirror Dart test structure (e.g., `color_test.dart` → `ColorTests.swift`)

**Test Structure:**
```swift
import XCTest
@testable import FlutterSwiftBridge

/// Tests for Offset class
/// **Dart Test Source:** `engine/src/flutter/testing/dart/geometry_test.dart`
final class OffsetTests: XCTestCase {

    /// **Dart Test:** `geometry_test.dart:XXX` - "Offset.+ should add offsets"
    func testOffsetAddition() {
        let a = Offset(10.0, 20.0)
        let b = Offset(5.0, 15.0)
        let result = a + b
        XCTAssertEqual(result, Offset(15.0, 35.0))
    }

    /// **Dart Test:** `geometry_test.dart:XXX` - "Offset.isFinite"
    func testOffsetIsFinite() {
        XCTAssertTrue(Offset(1.0, 2.0).isFinite)
        XCTAssertFalse(Offset(.infinity, 2.0).isFinite)
        XCTAssertFalse(Offset(1.0, .nan).isFinite)
    }

    // More tests...
}
```

**Parity Testing:**
Consider creating a test harness that can run both Dart and Swift implementations with same inputs and verify outputs match exactly.

### 10. Build System Integration

**Requirements:**
- Must build both C++ engine and Swift code
- Hybrid GN + Swift Package Manager approach
- After porting, always verify both builds succeed

**Build Verification Steps:**

1. **C++ Engine Build:**
```bash
# Build Flutter engine with et (engine tool)
cd engine/src
./flutter/bin/et build --config ci/host_debug_unopt_arm64
```

2. **Swift Build:**
```bash
# Build Swift package
cd flutter_swift
swift build

# Run Swift tests
swift test
```

**Build System Files:**

**Package.swift (flutter_swift/Package.swift):**
```swift
// swift-tools-version: 6.0
import PackageDescription
import Foundation

let swiftToolchainInclude = NSHomeDirectory() + "/Library/Developer/Toolchains/swift-6.2.1-RELEASE.xctoolchain/usr/include"
let cxxBridgeInclude = "../engine/src/flutter/lib/ui/swift/include"
let engineOutDir = "../engine/src/out/ci/host_debug_unopt_arm64"

let package = Package(
    name: "FlutterSwiftBridge",
    platforms: [
        .macOS(.v14),
        // .iOS(.v17),  // Future platform support
    ],
    products: [
        .library(
            name: "FlutterSwiftBridge",
            targets: ["FlutterSwiftBridge"]
        ),
    ],
    targets: [
        // Main Swift target containing the dart:ui Swift implementation
        .target(
            name: "FlutterSwiftBridge",
            dependencies: ["FlutterSwiftBridgeCxx"],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
                .unsafeFlags([
                    "-Xcc",
                    "-I\(swiftToolchainInclude)",
                ]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L\(engineOutDir)",
                    "-lswift_bridge",
                ])
            ]
        ),
        // C++ bridge module with modulemap pointing to engine headers
        .target(
            name: "FlutterSwiftBridgeCxx",
            cxxSettings: [
                .unsafeFlags(["-isystem", swiftToolchainInclude]),
                .unsafeFlags(["-I", cxxBridgeInclude]),
            ]
        ),
        // Test target
        .testTarget(
            name: "FlutterSwiftBridgeTests",
            dependencies: ["FlutterSwiftBridge"],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
                .unsafeFlags([
                    "-Xcc",
                    "-I\(swiftToolchainInclude)",
                ]),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx20
)
```

**Key points in Package.swift:**
1. Two targets: `FlutterSwiftBridge` (Swift code) depends on `FlutterSwiftBridgeCxx` (C++ module)
2. `FlutterSwiftBridgeCxx` target contains only the module.modulemap
3. Link against `libswift_bridge` built by the engine
4. Swift toolchain include path needed for `<swift/bridging>` header

**Module Map (flutter_swift/Sources/FlutterSwiftBridgeCxx/include/module.modulemap):**
```
module FlutterSwiftBridgeCxx {
    header "../../../../engine/src/flutter/lib/ui/swift/include/intrusive_reference_counted.h"
    header "../../../../engine/src/flutter/lib/ui/swift/include/rsuperellipse_bridge.h"
    // Add new bridge headers here as they are created
    export *
    requires cplusplus
}
```

**Key points in module.modulemap:**
1. Located in `flutter_swift/Sources/FlutterSwiftBridgeCxx/include/`
2. Uses relative paths to engine bridge headers
3. Add each new bridge header as it's created
4. `requires cplusplus` since these are C++ headers

**Placeholder file (flutter_swift/Sources/FlutterSwiftBridgeCxx/placeholder.c):**
```c
// Empty file required by SwiftPM - target must have at least one source file
```

**CRITICAL:** The module.modulemap points to headers in `engine/src/flutter/lib/ui/swift/include/` only!

### 11. Code Style & Conventions

**General Principle:** Swift code should be as close as possible to original Dart code in structure and naming.

**Naming Conventions:**
- **Classes/Structs/Enums:** Keep Dart naming (e.g., `Offset`, `Rect`, `PlatformDispatcher`)
- **Functions/Methods:** Keep Dart naming (e.g., `lerpDouble`, not `lerpedDouble`)
- **Properties:** Keep Dart naming (e.g., `isFinite`, not `isFiniteValue`)
- **Private members:** Use Swift convention (underscore prefix optional, rely on `private` keyword)

**Exception:** Use Swift conventions for:
- Initializers (`init` instead of constructor name)
- Protocol conformance (e.g., `Hashable`, `Equatable`)
- Operator overloads (Swift syntax)

**Formatting:**
- Follow standard Swift formatting (swift-format)
- 2-space indentation (match Dart/Flutter style)
- Keep line lengths reasonable (~100 chars)

### 12. Code Equivalence Requirements

**CRITICAL:** Migrated Swift code should behave **identically** to Dart code:

- Same function signatures (adapted for Swift idioms)
- Same edge case handling (NaN, infinity, null/nil)
- Same numerical precision
- Same error conditions and messages
- Same performance characteristics (or better)

**Verification Process:**

After successful build, perform a thorough comparison:

1. **Line-by-Line Comparison**
   - Compare original Dart source with Swift implementation
   - Verify every function, method, class, struct, enum is migrated
   - Check for missing functionality

2. **Document ALL Differences**
   - Any deviation from Dart behavior MUST be documented
   - Use consistent comment format in Swift code:
   ```swift
   // DIFFERENCE FROM DART: [Brief description]
   // REASON: [Why this difference exists]
   // DART: [Original Dart behavior/code if relevant]
   ```

3. **Examples of Acceptable Differences**
   ```swift
   // DIFFERENCE FROM DART: Using Swift's native Hashable instead of Dart's == operator
   // REASON: Swift idiomatic approach, provides better type system integration
   extension Offset: Hashable {
       // Implementation follows Swift conventions
   }
   ```

   ```swift
   // DIFFERENCE FROM DART: Using @inlinable for performance-critical functions
   // REASON: Swift optimization, no behavior change, better performance
   @inlinable
   public func clampDouble(_ x: Double, _ min: Double, _ max: Double) -> Double {
       // ...
   }
   ```

4. **Examples of Differences Requiring Documentation**
   - Algorithm changes for platform compatibility
   - Type system adaptations (e.g., protocol instead of abstract class)
   - Error handling differences (throwing vs returning nil)
   - Memory management approach differences
   - Naming convention changes beyond standard Swift style

5. **Review Process**
   - All documented differences must be reviewed
   - Verify differences are intentional and justified
   - Ensure no accidental behavior changes

**Areas Requiring Extra Care:**
- Floating-point arithmetic (NaN, infinity handling)
- String operations (UTF-16 vs UTF-8)
- Integer overflow behavior
- Null/nil coalescing semantics
- Collection iteration order

### 13. Post-Migration Verification Process

**CRITICAL:** After code migration and successful build, perform thorough verification to ensure no functionality is lost or changed unintentionally.

#### Step 1: Build Verification
- Verify C++ bridge builds successfully
- Verify Swift package builds successfully
- Verify all tests pass

#### Step 2: Code Comparison
Perform systematic line-by-line comparison between Dart and Swift:

**Comparison Checklist:**
```
For each Dart file:
  ✓ Open original Dart file
  ✓ Open corresponding Swift file(s)
  ✓ Compare side-by-side:
    - Every class/struct definition
    - Every method/function signature
    - Every property/field
    - Every constant
    - Every enum
    - Every factory/static method
    - Every operator overload
    - Every assertion/validation
    - Every edge case handler
```

**Use a Comparison Tool:**
```bash
# Generate side-by-side comparison report
# Example: Compare clampDouble implementations
diff -u <(cat engine/src/flutter/lib/ui/math.dart) \
        <(cat flutter_swift/Sources/FlutterSwiftBridge/Math.swift)
```

#### Step 3: Document Differences
For EVERY difference found, add documentation in Swift code:

**Required Format:**
```swift
// DIFFERENCE FROM DART: [Specific difference description]
// REASON: [Justification - why this difference exists]
// DART SOURCE: [Original Dart file:line reference]
// [Optional: Original Dart code snippet if helpful]
```

**Examples:**

**Example 1: Type System Adaptation**
```swift
// DIFFERENCE FROM DART: Using protocol instead of abstract class
// REASON: Swift doesn't have abstract classes; protocol + extension provides equivalent functionality
// DART SOURCE: geometry.dart:7-92 (OffsetBase abstract class)
public protocol OffsetBase {
    var dx: Double { get }
    var dy: Double { get }
}
```

**Example 2: Platform Idiom**
```swift
// DIFFERENCE FROM DART: Conforming to Hashable protocol
// REASON: Swift idiom for value equality; provides better standard library integration
// DART SOURCE: geometry.dart:94 (Offset class with == operator)
extension Offset: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(dx)
        hasher.combine(dy)
    }
}
```

**Example 3: Performance Optimization**
```swift
// DIFFERENCE FROM DART: Added @inlinable attribute
// REASON: Performance optimization for frequently-called function; no behavior change
// DART SOURCE: math.dart:13
@inlinable
public func clampDouble(_ x: Double, _ min: Double, _ max: Double) -> Double {
    // ...
}
```

**Example 4: Error Handling**
```swift
// DIFFERENCE FROM DART: Throws error instead of returning null
// REASON: Swift idiomatic error handling; makes error case explicit
// DART: Returns null on invalid input (painting.dart:XXX)
public func createShader(_ bounds: Rect) throws -> Shader {
    guard isValidConfiguration else {
        throw FlutterSwiftBridgeError.invalidConfiguration("Invalid gradient configuration")
    }
    // ...
}
```

#### Step 4: Create Difference Report
For each file, maintain a differences table in the plan file:

```markdown
## Differences from Dart Implementation

| # | Type | Location | Description | Reason | Approved |
|---|------|----------|-------------|--------|----------|
| 1 | Type System | Offset.swift:10 | Protocol instead of abstract class | Swift language limitation | ✅ |
| 2 | Error Handling | Paint.swift:45 | Throws instead of returns nil | Swift idiom | ✅ |
| 3 | Performance | Math.swift:15 | Added @inlinable | Optimization, no behavior change | ✅ |
```

#### Step 5: Review and Approval
- Review all documented differences
- Verify each difference is intentional and justified
- Ensure no accidental behavior changes
- Get approval for significant differences

#### Step 6: Update Test Coverage
If differences are found:
- Add tests that explicitly verify the new behavior
- Document why tests differ from Dart tests
- Ensure edge cases are still covered

### 14. Migration Checklist Per File

For each Dart file being migrated:

**C++ Bridge Creation:**
- [ ] Create bridge header in `engine/src/flutter/lib/ui/swift/include/` directory
- [ ] Bridge header must NOT include any Flutter engine headers
- [ ] Include `"intrusive_reference_counted.h"` in bridge header
- [ ] Use forward declarations and opaque pointers (`void*`) in bridge header
- [ ] Inherit bridge class from `IntrusiveReferenceCounted<BridgeClassName>`
- [ ] Add `SWIFT_SHARED_REFERENCE(Retain, Release)` annotation to bridge class
- [ ] Add `__attribute__((visibility("default")))` to bridge class
- [ ] Make constructor public with primitive types only - Swift calls directly
- [ ] Make destructor private
- [ ] Create bridge implementation in `engine/src/flutter/lib/ui/swift/src/` directory
- [ ] Bridge implementation CAN include Flutter engine headers
- [ ] Bridge implementation wraps actual Flutter C++ objects
- [ ] Convert between primitive types and Flutter types in implementation
- [ ] Add bridge header to `engine/src/flutter/lib/ui/swift/module.modulemap`
- [ ] Update `engine/src/flutter/lib/ui/swift/BUILD.gn` to build bridge code

**C++ Engine Modifications (if needed):**
- [ ] Remove Dart VM dependencies from C++ code (Dart_Handle, AssociateWithDartWrapper, etc.)
- [ ] Replace Dart VM entry point methods with factory methods
- [ ] Remove IMPLEMENT_WRAPPERTYPEINFO macros
- [ ] Ensure C++ classes work with bridge layer

**Swift Implementation:**
- [ ] Create corresponding Swift file in `flutter_swift/Sources/FlutterSwiftBridge/` with proper header comment
- [ ] Add Dart source reference at file level
- [ ] Migrate all classes/structs with documentation
- [ ] Add Dart source reference for each class/struct
- [ ] Migrate all methods/functions with documentation
- [ ] Add Dart source reference for each method/function (including line numbers)
- [ ] Migrate all constants and static properties
- [ ] Use direct C++ bridge calls (no @Native annotations)
- [ ] Wrap C++ bridge objects with SWIFT_SHARED_REFERENCE (no manual memory management)
- [ ] Remove all Dart VM related code (@pragma, VM entry points, etc.)

**Testing:**
- [ ] Port corresponding tests from `engine/src/flutter/testing/dart/`
- [ ] Add test documentation referencing original Dart tests
- [ ] Run Swift tests and verify 100% pass rate

**Build Verification:**
- [ ] Verify C++ engine build succeeds with SWIFT_SHARED_REFERENCE annotations
- [ ] Verify Swift package build succeeds
- [ ] Verify integration build links Swift with C++ correctly

**Code Comparison & Verification:**
- [ ] Compare original Dart code line-by-line with new Swift code
- [ ] Verify all functions/methods have been migrated
- [ ] Verify all classes/structs have been migrated
- [ ] Verify all constants and static properties have been migrated
- [ ] Identify ANY differences in behavior or implementation
- [ ] Document all differences in Swift code with `// DIFFERENCE FROM DART:` comments
- [ ] Document reasons for differences (e.g., Swift idioms, platform limitations, intentional improvements)
- [ ] Ensure differences are reviewed and approved

**Documentation:**
- [ ] Document any deviations from Dart implementation (should be zero)
- [ ] Document C++ classes modified with SWIFT_SHARED_REFERENCE
- [ ] Update this tracking document

## Success Criteria

**Per-File Success:**
- [ ] All classes/functions have Dart source references
- [ ] C++ build succeeds
- [ ] Swift build succeeds
- [ ] All tests ported and passing
- [ ] Line-by-line comparison completed
- [ ] All differences documented with `// DIFFERENCE FROM DART:` comments
- [ ] All differences reviewed and approved
- [ ] Code review completed
- [ ] Performance measured (no regressions)

**Overall Project Success:**
- [ ] All dart:ui files migrated
- [ ] Full backward compatibility maintained
- [ ] Zero test regressions
- [ ] Measurable performance improvement
- [ ] Documentation complete
- [ ] Build system fully integrated

---

## Architecture Clarifications

**Data Flow:**
1. Flutter Framework (Swift) creates UI elements
2. Framework calls dart:ui Swift APIs (this migration)
3. Swift APIs call C++ engine directly
4. C++ engine renders using Skia/Impeller

**NOT:**
- ~~C++ engine calling back into Swift~~ (this was the Dart VM model)
- ~~Swift implementing VM entry points~~ (no VM anymore)

**Callback/Event Handling:**
When the C++ engine needs to notify the framework (e.g., frame callbacks, platform messages), this will need to be handled differently than Dart's VM entry points. The Swift layer should provide mechanisms for the framework to register callbacks, and the C++ engine will need a new bridge mechanism (this is a future consideration beyond this migration).

## Questions & Future Considerations

**Deferred to Later:**
- Thread safety and concurrency (Swift actors, async/await)
- Event/callback mechanism from C++ engine to Swift framework
- Hot reload support (may require dynamic loading)
- iOS platform support (after macOS proven)
- Windows/Linux cross-platform Swift (experimental)

**Open Technical Questions:**
1. How will C++ engine events/callbacks reach the Swift framework? (New bridge mechanism needed)
2. Should Swift implementation expose public API for direct macOS use?
3. Binary distribution strategy (static vs dynamic linking)?
4. Versioning strategy for Swift implementation?

---

## References

- **Flutter Engine Source:** `engine/src/flutter/lib/ui/`
- **Dart Tests:** `engine/src/flutter/testing/dart/`
- **Swift C++ Interop:** [Swift.org C++ Interoperability](https://www.swift.org/documentation/cxx-interop/)
- **Flutter Engine Architecture:** [Flutter Engine Overview](https://github.com/flutter/flutter/wiki/The-Engine-architecture)

---

**Document Version:** 1.1
**Last Updated:** 2026-01-19
**Target Swift Version:** 6.0+
**Target Platforms:** macOS 14+, cross-platform Swift (experimental)

**Changelog:**
- v1.1 (2026-01-19): Updated with real RSuperellipse example, corrected directory structure, added FlutterSwiftBridgeCxx module pattern
