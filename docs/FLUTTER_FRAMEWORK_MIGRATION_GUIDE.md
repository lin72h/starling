# Flutter Framework to Swift 6 Migration Guide

## Executive Summary

**Goal:** Migrate the Flutter Framework from Dart to Swift 6, creating a pure Swift framework that interacts with the existing `FlutterSwiftBridge` (dart:ui Swift layer).

**Architecture:**
```
Flutter Framework (Swift - this migration)
         ↓
FlutterSwiftBridge (dart:ui layer - already migrated)
         ↓
    C++ Engine (Flutter engine core)
```

**Key Advantages:**
- No Dart VM dependency - pure Swift framework
- Direct access to FlutterSwiftBridge APIs
- Swift 6 modern concurrency and type safety
- Native platform integration without FFI overhead
- Leverage Swift's protocol-oriented design

**Critical Difference from dart:ui Migration:**
- **No C++ bridge required** - the FlutterSwiftBridge already provides the bridge to C++
- Flutter Framework Swift code directly imports and uses `FlutterSwiftBridge`
- Focus is on translating Dart framework patterns to Swift idioms

---

## Architecture Overview

### Current Dart Architecture
```
packages/flutter/lib/
├── src/
│   ├── widgets/          # Widget tree and framework
│   ├── rendering/        # RenderObject tree
│   ├── painting/         # Painting utilities
│   ├── foundation/       # Core utilities
│   ├── animation/        # Animation framework
│   ├── gestures/         # Gesture recognition
│   ├── material/         # Material Design widgets
│   ├── cupertino/        # iOS-style widgets
│   └── services/         # Platform services
└── flutter.dart          # Main export
         ↓
    dart:ui (now FlutterSwiftBridge)
```

### Target Swift Architecture
```
flutter_swift/Sources/
├── FlutterSwiftBridge/   # dart:ui layer (already migrated)
│   ├── Geometry.swift
│   ├── Painting.swift
│   ├── Compositing.swift
│   └── ...
└── Flutter/              # Flutter Framework (this migration)
    ├── Foundation/       # Core utilities
    ├── Animation/        # Animation framework
    ├── Painting/         # Painting utilities
    ├── Rendering/        # RenderObject tree
    ├── Widgets/          # Widget tree
    ├── Gestures/         # Gesture recognition
    ├── Material/         # Material Design widgets
    ├── Cupertino/        # iOS-style widgets
    └── Services/         # Platform services
```

---

## FlutterSwiftBridge Overview

The `FlutterSwiftBridge` package provides the Swift equivalent of dart:ui. It is the foundation that the Flutter Framework will build upon.

### Available APIs

The FlutterSwiftBridge provides these core types (migrated from dart:ui):

| Category | Types |
|----------|-------|
| **Geometry** | `Offset`, `Size`, `Rect`, `RRect`, `RSuperellipse`, `Radius`, `OffsetBase` |
| **Painting** | `Color`, `Paint`, `PaintingStyle`, `BlendMode`, `FilterQuality`, `StrokeCap`, `StrokeJoin`, `Shader`, `Gradient`, `ImageShader`, `MaskFilter`, `ColorFilter`, `ImageFilter` |
| **Canvas** | `Canvas`, `Picture`, `PictureRecorder` |
| **Compositing** | `Scene`, `SceneBuilder`, `EngineLayer`, various layer types |
| **Text** | `Paragraph`, `ParagraphBuilder`, `ParagraphStyle`, `TextStyle`, `TextAlign`, `TextDirection`, `FontWeight`, `FontStyle` |
| **Semantics** | `SemanticsUpdate`, `SemanticsUpdateBuilder`, `SemanticsAction`, `SemanticsFlag` |
| **Platform** | `PlatformDispatcher`, `FlutterView`, `ViewConfiguration` |
| **Input** | `PointerData`, `PointerChange`, `PointerDeviceKind`, `PointerSignalKind` |
| **Math** | `clampDouble`, `lerpDouble`, `lerpInt` |

### Importing FlutterSwiftBridge

```swift
import FlutterSwiftBridge

// Now you can use dart:ui types directly
let offset = Offset(10.0, 20.0)
let color = Color(0xFF42A5F5)
let rect = Rect.fromLTWH(0, 0, 100, 100)
```

## Workflow Per Task

For each subtask, follow this workflow:

1. **Create feature branch:**
   ```bash
   git checkout final-branch
   git pull origin final-branch
   git checkout -b swift-migrate/<subtask-name>
   ```

2. **Implement the Swift code** with Dart source references

3. **Verify compilation:**
   ```bash
   cd flutter_swift
   swift build
   ```

4. **Run tests (if applicable):**
   ```bash
   swift test --filter FlutterTests
   ```

5. **Mark subtask as complete** with ✅ COMPLETE in this plan

6. **Commit changes:**
   ```bash
   git add .
   git commit -m "Migrate <component> from alignment.dart to Swift

   - <bullet points of changes>

   Dart Source: packages/flutter/lib/src/painting/alignment.dart"
   ```
7. **Merge to final-branch:**
   ```bash
   git checkout final-branch
   git merge --no-ff swift-migrate/<subtask-name>
   ```

8. **Push changes:**
   ```bash
   git push myflutter final-branch
   ```




---

## Parallel Three-Repo Workflow with Three Agents

Use three agents working in parallel on three separate local clones of the same remote repository. Each agent works on individual **subtasks** from migration plan files, not entire files. This gives fine-grained control over work assignment and allows subtasks from different plans to be paired in the same batch.

### Setup

Three local repos share the same remote (`myflutter`), all on the same branch (`final-branch`):

```
/Users/<user>/dev/flutter2/workspace2   ← Agent 1 (repo A)
/Users/<user>/dev/flutter2/flutter      ← Agent 2 (repo B)
/Users/<user>/dev/flutter2/workspace3   ← Agent 3 (repo C)

All push/pull from: git@github.com:<user>/flutter.git (remote: myflutter)
All on branch: final-branch
```

### Team Leader Workflow

The team leader (you) orchestrates by picking subtasks from plan files:

1. **Browse plans:** Look in `plans/<module>/` for migration plan files (e.g., `plans/rendering/animated_size_migration_plan.md`)
2. **Extract subtasks:** Each plan file contains a `## Subtask Breakdown` section with numbered subtasks. Each subtask has its own branch name, checklist, and workflow.
3. **Pick three independent subtasks:** Select subtasks that don't depend on each other — they can be from the same plan file or different plan files.
4. **Launch three agents:** Assign one subtask per agent, one agent per repo.
5. **Sync repos** after all three agents complete.
6. **Repeat** with the next trio of subtasks.

```
Leader reads plans/rendering/animated_size_migration_plan.md
  → Subtask 1: RenderAnimatedSizeState and RenderAnimatedSize core
  → Subtask 2: Layout state machine and painting
  → Subtask 3: Tests

Leader reads plans/rendering/foo_migration_plan.md
  → Subtask 1: FooWidget core
  → Subtask 2: FooWidget layout
  → Subtask 3: Tests

Leader reads plans/rendering/bar_migration_plan.md
  → Subtask 1: BarWidget core
  → Subtask 2: BarWidget layout
  → Subtask 3: Tests

Batch 1:
  Agent 1 → repo A → animated_size Subtask 1 (core)
  Agent 2 → repo B → foo Subtask 1 (core)
  Agent 3 → repo C → bar Subtask 1 (core)
  ↓ all complete, sync repos

Batch 2:
  Agent 1 → repo A → animated_size Subtask 2 (layout)
  Agent 2 → repo B → foo Subtask 2 (layout)
  Agent 3 → repo C → bar Subtask 2 (layout)
  ↓ all complete, sync repos

Batch 3:
  Agent 1 → repo A → animated_size Subtask 3 (tests)
  Agent 2 → repo B → foo Subtask 3 (tests)
  Agent 3 → repo C → bar Subtask 3 (tests)
  ...
```

### Agent Workflow (per subtask)

Each agent receives a single subtask and follows the workflow specified in the plan file:

```bash
# 1. Create feature branch (branch name from the subtask)
git checkout final-branch
git checkout -b swift-migrate/<subtask-branch-name>

# 2. Read the Dart source lines specified in the subtask
# 3. Implement ONLY the items listed in the subtask checklist

# 4. Build to verify
cd flutter_swift && swift build

# 5. Fix errors, rebuild until clean

# 6. Commit
git add <files>
git commit -m "<subtask commit message>"

# 7. Merge to final-branch
git checkout final-branch
git merge --no-ff swift-migrate/<subtask-branch-name>

# 8. Do NOT push (leader handles sync)
```

**Key difference:** The agent implements only the scope defined in the subtask checklist, not the entire file. For example, Subtask 1 might create the file with core types and properties, while Subtask 2 adds layout/paint methods to the same file.

### Subtask Format (in plan files)

Each subtask in a plan file follows this structure:

```markdown
### Subtask N: <Description>
**Branch:** `swift-migrate/<subtask-branch-name>`

- [ ] Item 1 (e.g., Create file, migrate enum)
- [ ] Item 2 (e.g., Migrate class core: constructor, properties)
- [ ] Item 3 (e.g., Add Dart source documentation references)
- [ ] Verify build succeeds

**Workflow:**
1. `git checkout final-branch && git checkout -b swift-migrate/<subtask-branch-name>`
2. Implement the code
3. `swift build`
4. `git add . && git commit -m "<message>"`
5. `git checkout final-branch && git merge --no-ff swift-migrate/<subtask-branch-name>`
```

### Sync Protocol (between batches)

After all three agents complete their subtasks, the leader syncs the three repos before launching the next batch:

```bash
# Step 1: Push repo A
cd /path/to/repoA
git push myflutter final-branch

# Step 2: Fetch + merge into repo B, then push
cd /path/to/repoB
git fetch myflutter final-branch
git merge myflutter/final-branch --no-edit
swift build   # verify build still passes
git push myflutter final-branch

# Step 3: Fetch + merge into repo C, then push
cd /path/to/repoC
git fetch myflutter final-branch
git merge myflutter/final-branch --no-edit
swift build   # verify build still passes
git push myflutter final-branch

# Step 4: Fetch + merge back into repo A and repo B
cd /path/to/repoA
git fetch myflutter final-branch
git merge myflutter/final-branch --no-edit
swift build   # verify build still passes

cd /path/to/repoB
git fetch myflutter final-branch
git merge myflutter/final-branch --no-edit
swift build   # verify build still passes
```

If a repo's push is rejected (remote has new commits from another repo), fetch and merge first, then push. This is the normal case.

### Agent Launch Strategy

When launching agents:

- **One agent per repo** — never two agents on the same repo
- **No more than three agents at a time** — to keep resource usage manageable
- **Fresh context per subtask** — launch a new agent for each subtask to avoid context window exhaustion
- **Independent subtasks per batch** — group subtasks that don't depend on each other (can be from different plan files or independent subtasks within the same plan)
- **Subtask ordering within a plan** — subtasks within a plan file are numbered in dependency order; Subtask 2 typically depends on Subtask 1 being complete and synced
- **Cross-plan independence** — subtasks from different plan files are usually independent and safe to group

### Example: Rendering Module (subtask-based batches)

Given three plan files with 3 subtasks each:

| Batch | Repo A (workspace2) | Repo B (flutter) | Repo C (workspace3) |
|-------|---------------------|-------------------|----------------------|
| 1 | animated_size — Subtask 1 (core types) | viewport_offset — Subtask 1 (core types) | proxy_box — Subtask 1 (core types) |
| 2 | animated_size — Subtask 2 (layout/paint) | viewport_offset — Subtask 2 (scroll methods) | proxy_box — Subtask 2 (layout/paint) |
| 3 | animated_size — Subtask 3 (tests) | viewport_offset — Subtask 3 (tests) | proxy_box — Subtask 3 (tests) |

Subtasks from the same plan are run sequentially (Subtask 1 before Subtask 2), while subtasks from different plans run in parallel across repos.

### Handling Cross-Repo Dependencies

When a subtask in repo B depends on a type that was just created in repo A (or vice versa):

1. **Stub approach:** The agent creates a minimal stub for the missing type, then after sync the stub is removed.
2. **Post-sync fixup:** After syncing, verify the build. If there are duplicate definitions (stub vs real), remove the stub and rebuild.

Example: `Recognizer.swift` (repo B) had a `GestureArenaTeam` stub. After `Team.swift` (repo A) was synced in, the stub caused a "invalid redeclaration" error. Fix: remove the stub from `Recognizer.swift`.

### SourceKit False Positives

Every new Swift file triggers a SourceKit diagnostic: `No such module 'FlutterSwiftBridge'`. This is a **false positive** — `swift build` always succeeds. Ignore these diagnostics.

---

## Migration Phases

### Phase 1: Foundation Layer
- Core utilities: assertions, diagnostics, binding
- Basic data types: Key, UniqueKey
- Platform utilities

### Phase 2: Painting Layer
- Extend FlutterSwiftBridge painting types
- Add framework-level painting utilities
- Image handling, decoration, borders

### Phase 3: Animation Layer
- Animation controller, curves, tween
- Ticker provider, vsync handling

### Phase 4: Rendering Layer
- RenderObject base class
- RenderBox, layout protocols
- Hit testing, painting context

### Phase 5: Widgets Layer
- Widget, Element, BuildContext
- StatelessWidget, StatefulWidget, State
- InheritedWidget, Provider pattern

### Phase 6: Gestures Layer
- Gesture recognizers
- Drag, tap, scale, pan gestures

### Phase 7: Material & Cupertino
- Design system widgets
- Theming

---

## General Migration Principles

### 1. Directory Structure

```
flutter_swift/Sources/Flutter/
├── Foundation/
│   ├── Assertions.swift
│   ├── Binding.swift
│   ├── Diagnostics.swift
│   ├── Key.swift
│   └── ...
├── Animation/
│   ├── Animation.swift
│   ├── AnimationController.swift
│   ├── Curve.swift
│   ├── Tween.swift
│   └── ...
├── Painting/
│   ├── Alignment.swift
│   ├── BorderRadius.swift
│   ├── BoxDecoration.swift
│   ├── EdgeInsets.swift
│   └── ...
├── Rendering/
│   ├── RenderObject.swift
│   ├── RenderBox.swift
│   ├── Layer.swift
│   └── ...
├── Widgets/
│   ├── Widget.swift
│   ├── Element.swift
│   ├── BuildContext.swift
│   ├── StatelessWidget.swift
│   ├── StatefulWidget.swift
│   └── ...
├── Gestures/
│   ├── GestureRecognizer.swift
│   ├── TapGestureRecognizer.swift
│   └── ...
├── Material/
│   └── ...
├── Cupertino/
│   └── ...
└── Services/
    └── ...
```

### 2. Deprecated Code Policy

**RULE: Do NOT migrate deprecated code.**

When migrating Dart code to Swift, skip any classes, functions, methods, or properties that are marked as deprecated in the Dart source. This includes:

- `@Deprecated('...')` annotations
- `@deprecated` annotations
- Documentation comments indicating deprecation

**Rationale:**
- Deprecated APIs are scheduled for removal
- Migrating deprecated code wastes effort
- Swift codebase should start clean without legacy baggage
- Reduces maintenance burden

**How to identify deprecated code:**
```dart
// Skip these patterns:
@Deprecated('Use newMethod instead')
void oldMethod() { ... }

@deprecated
class OldWidget extends StatelessWidget { ... }

/// This is deprecated, use [NewClass] instead.
class LegacyClass { ... }
```

**Documentation requirement:** When skipping deprecated code, add a brief note in the Swift file:
```swift
// NOTE: Dart's `oldMethod` was deprecated and intentionally not migrated.
// See: framework.dart:XXX - @Deprecated('Use newMethod instead')
```

### 3. Code Documentation & Traceability

**CRITICAL REQUIREMENT:** Every migrated Swift class/struct/function MUST include a reference to the original Dart code.

```swift
// MARK: - Widget
/// The base class for all Flutter widgets.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart`
/// **Original Name:** `Widget`
/// **Lines:** 456-598
public protocol Widget {
    /// A unique key for this widget.
    ///
    /// **Dart Source:** `framework.dart:472-475`
    var key: Key? { get }

    /// Creates an Element for this widget.
    ///
    /// **Dart Source:** `framework.dart:577-578`
    func createElement() -> Element
}
```

### 4. Type Mapping Guidelines

| Dart Type | Swift Type | Notes |
|-----------|------------|-------|
| `double` | `Double` | Direct mapping |
| `int` | `Int64` | Use Int64 for consistency |
| `bool` | `Bool` | Direct mapping |
| `String` | `String` | UTF-16 vs UTF-8 awareness |
| `List<T>` | `[T]` | Swift Array |
| `Map<K, V>` | `[K: V]` | Swift Dictionary |
| `Set<T>` | `Set<T>` | Direct mapping |
| `T?` | `T?` | Optional |
| `dynamic` | `Any` | Avoid when possible |
| `Object` | `AnyObject` or `Any` | Context dependent |
| `abstract class` | `protocol` | With default implementations via extension |
| `mixin` | `protocol` + extension | Protocol composition |
| `class` | `class` | Reference semantics |
| `@immutable class` | `struct` | Value semantics preferred |
| `typedef` | `typealias` | Direct mapping |
| `enum` | `enum` | Direct mapping |
| `extension` | `extension` | Direct mapping |

### 5. Dart Patterns → Swift Patterns

#### Abstract Classes → Protocols with Extensions

**Dart:**
```dart
abstract class Widget {
  const Widget({ this.key });
  final Key? key;

  @protected
  Element createElement();

  String toStringShort() => describeIdentity(this);
}
```

**Swift:**
```swift
/// **Dart Source:** `framework.dart:456-598`
public protocol Widget {
    var key: Key? { get }
    func createElement() -> Element
}

extension Widget {
    /// **Dart Source:** `framework.dart:589-590`
    public func toStringShort() -> String {
        return describeIdentity(self)
    }
}
```

#### Mixins → Protocol Composition

**Dart:**
```dart
mixin TickerProviderStateMixin<T extends StatefulWidget> on State<T>
    implements TickerProvider {
  Set<Ticker>? _tickers;

  @override
  Ticker createTicker(TickerCallback onTick) {
    // ...
  }
}
```

**Swift:**
```swift
/// **Dart Source:** `ticker_provider.dart:XXX`
public protocol TickerProviderStateMixin: TickerProvider where Self: State {
    var _tickers: Set<Ticker>? { get set }
}

extension TickerProviderStateMixin {
    /// **Dart Source:** `ticker_provider.dart:XXX`
    public func createTicker(onTick: @escaping TickerCallback) -> Ticker {
        // ...
    }
}
```

#### Factory Constructors → Static Methods

**Dart:**
```dart
class BorderRadius {
  factory BorderRadius.circular(double radius) {
    return BorderRadius.all(Radius.circular(radius));
  }
}
```

**Swift:**
```swift
/// **Dart Source:** `border_radius.dart:XXX`
public struct BorderRadius {
    /// **Dart Source:** `border_radius.dart:XXX`
    public static func circular(_ radius: Double) -> BorderRadius {
        return BorderRadius.all(Radius.circular(radius))
    }
}
```

#### Const Constructors → Static Constants

**Dart:**
```dart
class EdgeInsets {
  const EdgeInsets.all(double value)
      : left = value,
        top = value,
        right = value,
        bottom = value;

  static const EdgeInsets zero = EdgeInsets.all(0.0);
}
```

**Swift:**
```swift
/// **Dart Source:** `edge_insets.dart:XXX`
public struct EdgeInsets: Hashable {
    public let left: Double
    public let top: Double
    public let right: Double
    public let bottom: Double

    /// **Dart Source:** `edge_insets.dart:XXX`
    public init(all value: Double) {
        self.left = value
        self.top = value
        self.right = value
        self.bottom = value
    }

    /// **Dart Source:** `edge_insets.dart:XXX`
    public static let zero = EdgeInsets(all: 0.0)
}
```

#### Getters/Setters → Computed Properties

**Dart:**
```dart
class RenderBox {
  Size? _size;
  Size get size => _size!;
  set size(Size value) {
    _size = value;
    markNeedsLayout();
  }
}
```

**Swift:**
```swift
/// **Dart Source:** `box.dart:XXX`
public class RenderBox: RenderObject {
    private var _size: Size?

    /// **Dart Source:** `box.dart:XXX`
    public var size: Size {
        get { _size! }
        set {
            _size = newValue
            markNeedsLayout()
        }
    }
}
```

### 6. FlutterSwiftBridge Integration

The Flutter Framework will build on top of FlutterSwiftBridge. Import and use types directly:

```swift
import FlutterSwiftBridge

/// **Dart Source:** `alignment.dart:XXX`
public struct Alignment: Hashable {
    public let x: Double
    public let y: Double

    /// **Dart Source:** `alignment.dart:XXX`
    public func alongOffset(_ other: Offset) -> Offset {
        let centerX = other.dx / 2.0
        let centerY = other.dy / 2.0
        return Offset(centerX + x * centerX, centerY + y * centerY)
    }

    /// **Dart Source:** `alignment.dart:XXX`
    public func alongSize(_ other: Size) -> Offset {
        let centerX = other.width / 2.0
        let centerY = other.height / 2.0
        return Offset(centerX + x * centerX, centerY + y * centerY)
    }

    /// **Dart Source:** `alignment.dart:XXX`
    public func withinRect(_ rect: Rect) -> Offset {
        let halfWidth = rect.width / 2.0
        let halfHeight = rect.height / 2.0
        return Offset(
            rect.left + halfWidth + x * halfWidth,
            rect.top + halfHeight + y * halfHeight
        )
    }
}
```

### 7. Widget System Patterns

#### Widget Protocol

```swift
/// **Dart Source:** `framework.dart:456-598`
public protocol Widget {
    var key: Key? { get }
    func createElement() -> Element
}

/// **Dart Source:** `framework.dart:XXX`
public protocol StatelessWidget: Widget {
    func build(context: BuildContext) -> Widget
}

/// **Dart Source:** `framework.dart:XXX`
public protocol StatefulWidget: Widget {
    associatedtype StateType: State
    func createState() -> StateType
}

/// **Dart Source:** `framework.dart:XXX`
public class State<W: StatefulWidget> {
    public var widget: W!
    public var context: BuildContext!

    public func build(context: BuildContext) -> Widget {
        fatalError("Subclasses must override build()")
    }

    public func setState(_ fn: () -> Void) {
        fn()
        // Mark element as needing rebuild
    }
}
```

#### Element and BuildContext

```swift
/// **Dart Source:** `framework.dart:XXX`
public class Element: BuildContext {
    public var widget: Widget
    public weak var parent: Element?
    public var children: [Element] = []

    // ...
}

/// **Dart Source:** `framework.dart:XXX`
public protocol BuildContext {
    var widget: Widget { get }
    func dependOnInheritedWidgetOfExactType<T: InheritedWidget>() -> T?
    func findAncestorWidgetOfExactType<T: Widget>() -> T?
    func findAncestorStateOfType<T: State>() -> T?
}
```

### 8. Error Handling

**Dart:**
```dart
assert(widget != null, 'Widget cannot be null');
throw FlutterError('Incorrect use of ParentDataWidget');
```

**Swift:**
```swift
// Debug assertions
assert(widget != nil, "Widget cannot be nil")

// Errors
enum FlutterError: Error {
    case incorrectParentData(String)
    case invalidState(String)
}
throw FlutterError.incorrectParentData("Incorrect use of ParentDataWidget")
```

### 9. Async/Await Patterns

**Dart:**
```dart
Future<void> precacheImage(ImageProvider provider) async {
  final ImageStream stream = provider.resolve(configuration);
  final Completer<void> completer = Completer<void>();
  // ...
  return completer.future;
}
```

**Swift:**
```swift
/// **Dart Source:** `image_provider.dart:XXX`
public func precacheImage(_ provider: ImageProvider) async throws {
    let stream = provider.resolve(configuration)
    // Use Swift structured concurrency
    return try await withCheckedThrowingContinuation { continuation in
        // ...
    }
}
```

---

## Build System Integration

### Package.swift Updates

Add the Flutter target to the existing package:

```swift
// swift-tools-version: 6.0
import PackageDescription
import Foundation

let swiftToolchainInclude = NSHomeDirectory() + "/Library/Developer/Toolchains/swift-6.2.1-RELEASE.xctoolchain/usr/include"
let cxxBridgeInclude = "../engine/src/flutter/lib/ui/swift/include"
let engineOutDir = "../engine/src/out/ci/host_debug_unopt_arm64"

let package = Package(
    name: "FlutterSwift",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        // dart:ui Swift layer
        .library(
            name: "FlutterSwiftBridge",
            targets: ["FlutterSwiftBridge"]
        ),
        // Flutter Framework Swift layer
        .library(
            name: "Flutter",
            targets: ["Flutter"]
        ),
    ],
    targets: [
        // dart:ui Swift implementation
        .target(
            name: "FlutterSwiftBridge",
            dependencies: ["FlutterSwiftBridgeCxx"],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
                .unsafeFlags(["-Xcc", "-I\(swiftToolchainInclude)"]),
            ],
            linkerSettings: [
                .unsafeFlags(["-L\(engineOutDir)", "-lswift_bridge"])
            ]
        ),
        // C++ bridge module
        .target(
            name: "FlutterSwiftBridgeCxx",
            cxxSettings: [
                .unsafeFlags(["-isystem", swiftToolchainInclude]),
                .unsafeFlags(["-I", cxxBridgeInclude]),
            ]
        ),
        // Flutter Framework (NEW)
        .target(
            name: "Flutter",
            dependencies: ["FlutterSwiftBridge"],
            path: "Sources/Flutter"
        ),
        // Test targets
        .testTarget(
            name: "FlutterSwiftBridgeTests",
            dependencies: ["FlutterSwiftBridge"],
            // ... existing settings
        ),
        .testTarget(
            name: "FlutterTests",
            dependencies: ["Flutter"],
            path: "Tests/FlutterTests"
        ),
    ],
    cxxLanguageStandard: .cxx20
)
```

### Build Commands

```bash
# Build everything
cd flutter_swift
swift build

# Run all tests
swift test

# Run specific test target
swift test --filter FlutterTests
```

---

## Testing Strategy

### Test Organization

```
flutter_swift/Tests/
├── FlutterSwiftBridgeTests/   # dart:ui tests (existing)
│   ├── GeometryTests.swift
│   ├── PaintingTests.swift
│   └── ...
└── FlutterTests/              # Flutter Framework tests (new)
    ├── Foundation/
    │   ├── KeyTests.swift
    │   └── ...
    ├── Animation/
    │   ├── TweenTests.swift
    │   └── ...
    ├── Painting/
    │   ├── EdgeInsetsTests.swift
    │   └── ...
    ├── Rendering/
    │   └── ...
    └── Widgets/
        ├── WidgetTests.swift
        ├── ElementTests.swift
        └── ...
```

### Test Pattern

```swift
import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for EdgeInsets
/// **Dart Test Source:** `packages/flutter/test/painting/edge_insets_test.dart`
final class EdgeInsetsTests: XCTestCase {

    /// **Dart Test:** `edge_insets_test.dart:XXX` - "EdgeInsets.all creates symmetric insets"
    func testEdgeInsetsAll() {
        let insets = EdgeInsets(all: 10.0)
        XCTAssertEqual(insets.left, 10.0)
        XCTAssertEqual(insets.top, 10.0)
        XCTAssertEqual(insets.right, 10.0)
        XCTAssertEqual(insets.bottom, 10.0)
    }

    /// **Dart Test:** `edge_insets_test.dart:XXX` - "EdgeInsets.zero is all zeros"
    func testEdgeInsetsZero() {
        XCTAssertEqual(EdgeInsets.zero.left, 0.0)
        XCTAssertEqual(EdgeInsets.zero.top, 0.0)
        XCTAssertEqual(EdgeInsets.zero.right, 0.0)
        XCTAssertEqual(EdgeInsets.zero.bottom, 0.0)
    }
}
```

---

## Migration Checklist Per File

For each Dart file being migrated:

**Pre-Migration:**
- [ ] Read and understand the Dart source file
- [ ] Identify and skip deprecated classes/functions (do NOT migrate)
- [ ] Identify dependencies on dart:ui (use FlutterSwiftBridge)
- [ ] Identify dependencies on other framework files
- [ ] Plan Swift file structure

**Swift Implementation:**
- [ ] Create Swift file in appropriate `Sources/Flutter/` subdirectory
- [ ] Add file-level Dart source reference
- [ ] Migrate all classes/structs with documentation
- [ ] Add Dart source reference for each type
- [ ] Migrate all methods/functions with line number references
- [ ] Import FlutterSwiftBridge for dart:ui types
- [ ] Use Swift idioms (protocols, extensions, value types where appropriate)

**Testing:**
- [ ] Port corresponding tests from `packages/flutter/test/`
- [ ] Add test documentation referencing original Dart tests
- [ ] Run tests and verify pass rate

**Verification:**
- [ ] Compare Dart and Swift implementations line-by-line
- [ ] Document any intentional differences
- [ ] Verify behavior matches Dart implementation

---

## Key Differences from dart:ui Migration

| Aspect | dart:ui Migration | Flutter Framework Migration |
|--------|-------------------|----------------------------|
| **C++ Bridge** | Required - create bridge headers and implementations | Not needed - use FlutterSwiftBridge |
| **Engine Interaction** | Direct C++ calls via bridge | Via FlutterSwiftBridge APIs |
| **Package Location** | `flutter_swift/Sources/FlutterSwiftBridge/` | `flutter_swift/Sources/Flutter/` |
| **Dependencies** | FlutterSwiftBridgeCxx (C++ module) | FlutterSwiftBridge (Swift module) |
| **Complexity** | Memory management, SWIFT_SHARED_REFERENCE | Pure Swift, higher-level abstractions |
| **Focus** | Low-level engine bindings | Application framework patterns |

---

## Example: Migrating EdgeInsets

### Step 1: Find Dart Source

Location: `packages/flutter/lib/src/painting/edge_insets.dart`

### Step 2: Create Swift File

```swift
// Sources/Flutter/Painting/EdgeInsets.swift

import FlutterSwiftBridge

// MARK: - EdgeInsetsGeometry
/// Base class for EdgeInsets and EdgeInsetsDirectional.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/edge_insets.dart`
/// **Original Name:** `EdgeInsetsGeometry`
/// **Lines:** 23-280
public protocol EdgeInsetsGeometry {
    /// The total offset in the horizontal direction.
    ///
    /// **Dart Source:** `edge_insets.dart:45-46`
    var horizontal: Double { get }

    /// The total offset in the vertical direction.
    ///
    /// **Dart Source:** `edge_insets.dart:52-53`
    var vertical: Double { get }

    /// Resolve to EdgeInsets based on text direction.
    ///
    /// **Dart Source:** `edge_insets.dart:XXX`
    func resolve(_ direction: TextDirection?) -> EdgeInsets
}

// MARK: - EdgeInsets
/// An immutable set of offsets in each of the four cardinal directions.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/edge_insets.dart`
/// **Original Name:** `EdgeInsets`
/// **Lines:** 282-520
public struct EdgeInsets: EdgeInsetsGeometry, Hashable {
    public let left: Double
    public let top: Double
    public let right: Double
    public let bottom: Double

    /// Creates insets from offsets from the left, top, right, and bottom.
    ///
    /// **Dart Source:** `edge_insets.dart:290-295`
    public init(left: Double = 0, top: Double = 0, right: Double = 0, bottom: Double = 0) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }

    /// Creates insets where all the offsets are `value`.
    ///
    /// **Dart Source:** `edge_insets.dart:304-310`
    public init(all value: Double) {
        self.left = value
        self.top = value
        self.right = value
        self.bottom = value
    }

    /// Creates insets with symmetric horizontal and vertical offsets.
    ///
    /// **Dart Source:** `edge_insets.dart:318-328`
    public init(horizontal: Double = 0, vertical: Double = 0) {
        self.left = horizontal
        self.right = horizontal
        self.top = vertical
        self.bottom = vertical
    }

    /// An EdgeInsets with zero offsets in each direction.
    ///
    /// **Dart Source:** `edge_insets.dart:334`
    public static let zero = EdgeInsets(all: 0)

    // MARK: - EdgeInsetsGeometry

    /// **Dart Source:** `edge_insets.dart:XXX`
    public var horizontal: Double { left + right }

    /// **Dart Source:** `edge_insets.dart:XXX`
    public var vertical: Double { top + bottom }

    /// **Dart Source:** `edge_insets.dart:XXX`
    public func resolve(_ direction: TextDirection?) -> EdgeInsets { self }

    // MARK: - Operators

    /// **Dart Source:** `edge_insets.dart:XXX`
    public static func + (lhs: EdgeInsets, rhs: EdgeInsets) -> EdgeInsets {
        EdgeInsets(
            left: lhs.left + rhs.left,
            top: lhs.top + rhs.top,
            right: lhs.right + rhs.right,
            bottom: lhs.bottom + rhs.bottom
        )
    }

    /// **Dart Source:** `edge_insets.dart:XXX`
    public static func - (lhs: EdgeInsets, rhs: EdgeInsets) -> EdgeInsets {
        EdgeInsets(
            left: lhs.left - rhs.left,
            top: lhs.top - rhs.top,
            right: lhs.right - rhs.right,
            bottom: lhs.bottom - rhs.bottom
        )
    }

    /// **Dart Source:** `edge_insets.dart:XXX`
    public static prefix func - (insets: EdgeInsets) -> EdgeInsets {
        EdgeInsets(
            left: -insets.left,
            top: -insets.top,
            right: -insets.right,
            bottom: -insets.bottom
        )
    }

    /// **Dart Source:** `edge_insets.dart:XXX`
    public static func * (lhs: EdgeInsets, rhs: Double) -> EdgeInsets {
        EdgeInsets(
            left: lhs.left * rhs,
            top: lhs.top * rhs,
            right: lhs.right * rhs,
            bottom: lhs.bottom * rhs
        )
    }

    // MARK: - Utilities

    /// Returns a new rect that is bigger than the given rect in each direction by
    /// the amount of inset in each direction.
    ///
    /// **Dart Source:** `edge_insets.dart:XXX`
    public func inflateRect(_ rect: Rect) -> Rect {
        Rect.fromLTRB(
            rect.left - left,
            rect.top - top,
            rect.right + right,
            rect.bottom + bottom
        )
    }

    /// Returns a new rect that is smaller than the given rect in each direction by
    /// the amount of inset in each direction.
    ///
    /// **Dart Source:** `edge_insets.dart:XXX`
    public func deflateRect(_ rect: Rect) -> Rect {
        Rect.fromLTRB(
            rect.left + left,
            rect.top + top,
            rect.right - right,
            rect.bottom - bottom
        )
    }
}
```

---

## Success Criteria

**Per-File Success:**
- [ ] All types have Dart source references
- [ ] Swift build succeeds
- [ ] All tests ported and passing
- [ ] Line-by-line comparison completed
- [ ] All differences documented

**Per-Module Success:**
- [ ] All files in module migrated
- [ ] Module tests passing
- [ ] Integration with FlutterSwiftBridge verified

**Overall Project Success:**
- [ ] All Flutter Framework modules migrated
- [ ] Full test coverage maintained
- [ ] Performance validated
- [ ] Documentation complete

---

## References

- **Flutter Framework Source:** `packages/flutter/lib/`
- **Flutter Framework Tests:** `packages/flutter/test/`
- **FlutterSwiftBridge:** `flutter_swift/Sources/FlutterSwiftBridge/`
- **Swift Documentation:** [Swift.org](https://www.swift.org/documentation/)

---

**Document Version:** 1.0
**Last Updated:** 2026-02-07
**Target Swift Version:** 6.0+
**Target Platforms:** macOS 14+
