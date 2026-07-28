# Flutter Engine dart:ui to Swift Migration - Planning Tracker

This document tracks the detailed planning progress for migrating each Dart file in `engine/src/flutter/lib/ui/` to Swift 6.

**Reference:** See [SWIFT_MIGRATION_GUIDE.md](SWIFT_MIGRATION_GUIDE.md) for the complete migration strategy and technical guidelines.

---

## Planning Approach: "Ralph Wiggum" Style

Each Dart file gets **one dedicated context window** for detailed planning. Each planning session will:

1. **Analyze** the specific Dart file in depth
2. **Identify** all classes, functions, types, and dependencies
3. **Design** the three-layer architecture (Swift wrapper → C++ bridge → Flutter engine)
4. **Document** the plan in a dedicated file: `plans/<filename>_plan.md`
5. **Update** this tracker document when complete

**Planning Workflow:**
- One file at a time, one context window per file
- Each planning task creates its own detailed plan file
- This tracker gets updated with ✅ when planning is done
- Plans are reviewed before implementation begins

---

## Automated Plan Generation Workflow

Use the `dart_metadata_extractor` tool to generate compact metadata for AI consumption.

### Step 1: Generate Compact Metadata

```bash
cd dev/dart_metadata_extractor

# Run the extractor with compact format (optimized for AI)
dart run bin/extract_metadata.dart \
  -i /path/to/engine/lib/ui/<filename>.dart \
  -o /tmp/<filename>_metadata \
  --format=compact \
  --include-private
```

**Output formats:**
- `--format=compact` (recommended): AI-readable text format (~14x smaller than JSON)
- `--format=json` (default): Full JSON with all metadata details

The compact format produces a `.txt` file with:
- **External Dependencies**:
  - SDK libraries grouped by name (dart:core, dart:math, etc.)
  - Cross-file dependencies with source file paths (e.g., `lerp.dart: _lerpDouble`)
- **Migration Order**: Topologically sorted class list
- **Circular Dependencies**: Warnings for classes needing special handling
- **Per-class members**: Line ranges, modifiers, types, and `uses:` dependencies

### Step 2: Generate Migration Plan with AI

Feed the compact metadata to Claude in a new context window:

```
Read this compact metadata for <filename>.dart and generate a migration plan
following the format in ui_porting_plan.md.

Requirements:
1. List classes in the Migration Order
2. Document cross-file dependencies (e.g., lerp.dart, math.dart) that must be ported first
3. Create a table for each class with ALL members (constructors, fields,
   accessors, methods, operators) using the line ranges provided
4. Include the "uses:" dependencies for each member
5. Mark @Native methods as requiring C++ bridge
6. Include the Testing section
7. Add Notes section for abstract classes, type parameters, circular deps

<paste compact metadata here>
```

### Example Compact Output

```
# geometry.dart
path: /path/to/geometry.dart
partOf: dart.ui

## External Dependencies
dart:core: ArgumentError, Object, double, identical, int
dart:math: atan2, cos, max, min, sin, sqrt
dart:nativewrappers: NativeFieldWrapperClass1
dart:typed_data: Float32List
lerp.dart: _lerpDouble
math.dart: clampDouble

## Migration Order
OffsetBase -> RSTransform -> Radius -> Offset -> Size -> Rect -> ...

## Circular Dependencies (need special handling)
- Offset <-> Rect
- Offset <-> Rect <-> Size

## OffsetBase (abstract class) L7-92 [12 members]

  L10-15 const ctor OffsetBase(double, double)
  L17 final field double _dx
  L18 final field double _dy
  L20-29  getter bool isInfinite | uses: infinity
  L39-46  method bool operator <(OffsetBase) | uses: OffsetBase._dx, OffsetBase._dy
  ...
```

**External Dependencies Format:**
- **SDK libraries** (dart:core, dart:math, etc.): Grouped by library name
- **Cross-file dependencies** (lerp.dart, math.dart): Functions from the same library but different source files

Cross-file dependencies are important for migration because they indicate functions that must be ported from other files in the same library (e.g., `_lerpDouble` from `lerp.dart` must be available before `geometry.dart` can be fully migrated).

### Example Migration Plan Output

The generated plan should look like [geometry_plan.md](plans/geometry_plan.md):

```markdown
# geometry.dart Migration Plan

**Dart Source:** `/path/to/geometry.dart`
**Total Classes:** 10
**Total Members:** ~212
**C++ Bridge Required:** Yes

## Dependencies

### SDK Libraries
| Library | Symbols |
|---------|---------|
| dart:core | ArgumentError, Object, double, identical, int |
| dart:math | atan2, cos, max, min, sin, sqrt |
| dart:nativewrappers | NativeFieldWrapperClass1 |
| dart:typed_data | Float32List |

### Cross-File Dependencies (same library, different file)
| Source File | Symbols | Notes |
|-------------|---------|-------|
| lerp.dart | `_lerpDouble` | Must port lerp.dart first |
| math.dart | `clampDouble` | Must port math.dart first |

## Migration Order
1. **OffsetBase**
2. **RSTransform**
3. **Radius**
...

## Migration Tasks

### 1. OffsetBase (lines 7-92) - 12 members

| Status | Member | Lines | Type | Notes |
|--------|--------|-------|------|-------|
| [ ] | `(default)` | 10-15 | constructor | const |
| [ ] | `_dx` | 17 | field | final double |
| [ ] | `isInfinite` | 20-29 | getter | uses: infinity |
| [ ] | `<` | 39-46 | operator | uses: OffsetBase._dx, OffsetBase._dy |
...
```

### Benefits of This Approach

1. **Compact Format**: ~14x smaller than JSON, fits easily in AI context windows
2. **Line Ranges**: Shows exact start-end lines for each member (e.g., `L10-15`)
3. **Accuracy**: Extractor captures ALL members via AST analysis
4. **Dependency Ordering**: Topological sort ensures correct migration sequence
5. **Circular Dependency Detection**: Identifies classes needing special handling
6. **Body References**: Tracks what each member uses (math.cos, other classes, etc.)
7. **Cross-File Dependencies**: Shows functions from other files in the same library that must be ported first
7. **Flexibility**: AI can adapt output format to specific needs

---

## Planning Status Overview

**Legend:**
- ⬜ Not Started - No planning session yet
- 🔄 In Progress - Currently being planned
- ✅ Planning Complete - Detailed plan file created
- 🚀 Implementation Started - Migrated to Swift (tracked separately)

**Priority Order:**
1. **Foundation** - Simple, no dependencies (math, lerp, geometry)
2. **Core Types** - Basic data structures (annotations, key, pointer)
3. **Advanced** - Complex subsystems (painting, text, compositing, semantics)
4. **Platform** - Platform integration (platform_dispatcher, window, hooks)
5. **Special** - Special purpose files (ui.dart, natives.dart, setup_hooks.dart)

---

## Files to Plan and Port

### Phase 1: Foundation (Proof of Concept)

| Status | File | Lines | Complexity | Plan File | Notes |
|--------|------|-------|------------|-----------|-------|
| ✅ | `math.dart` | ~26 | 🟢 Simple | `plans/math_plan.md` | ✅ Planning Complete - Single pure function `clampDouble`, no C++ bridge needed. Ready for implementation. |
| ✅ | `lerp.dart` | ~50 | 🟢 Simple | `plans/lerp_plan.md` | ✅ Planning Complete - Pure interpolation functions (lerpDouble, _lerpDouble, _lerpInt), no C++ bridge needed. Ready for implementation. |
| ✅ | `geometry.dart` | ~2201 | 🟡 Medium-High | `plans/geometry_plan.md` | ✅ Planning Complete - 10 classes (Offset, Size, Rect, Radius, RRect, RSuperellipse, etc.), 50+ operators, minimal C++ bridge for RSuperellipse.contains. Most complex Phase 1 file. Ready for implementation. |

### Phase 2: Core Types & Primitives

| Status | File | Lines | Complexity | Plan File | Notes |
|--------|------|-------|------------|-----------|-------|
| ⬜ | `annotations.dart` | ~100 | 🟢 Simple | `plans/annotations_plan.md` | Metadata annotations, may not need full port |
| ⬜ | `key.dart` | ~50 | 🟢 Simple | `plans/key_plan.md` | Simple key type for widgets |
| ⬜ | `pointer.dart` | ~500 | 🟡 Medium | `plans/pointer_plan.md` | Pointer event data structures |
| ⬜ | `channel_buffers.dart` | ~300 | 🟡 Medium | `plans/channel_buffers_plan.md` | Platform channel buffering |

### Phase 3: Advanced Subsystems

| Status | File | Lines | Complexity | Plan File | Notes |
|--------|------|-------|------------|-----------|-------|
| ⬜ | `painting.dart` | ~5000 | 🔴 Complex | `plans/painting_plan.md` | Canvas, Paint, Image, Picture - core rendering APIs |
| ⬜ | `text.dart` | ~3000 | 🔴 Complex | `plans/text_plan.md` | Text layout, paragraph builder, text styles |
| ⬜ | `compositing.dart` | ~1000 | 🔴 Complex | `plans/compositing_plan.md` | Scene builder, layer tree |
| ⬜ | `semantics.dart` | ~2000 | 🔴 Complex | `plans/semantics_plan.md` | Accessibility semantics tree |

### Phase 4: Platform Integration

| Status | File | Lines | Complexity | Plan File | Notes |
|--------|------|-------|------------|-----------|-------|
| ⬜ | `platform_dispatcher.dart` | ~1500 | 🔴 Complex | `plans/platform_dispatcher_plan.md` | Core platform interface, callbacks, lifecycle |
| ⬜ | `window.dart` | ~800 | 🟡 Medium | `plans/window_plan.md` | Window abstraction, metrics, view configuration |
| ⬜ | `hooks.dart` | ~500 | 🔴 Complex | `plans/hooks_plan.md` | VM entry points - requires complete redesign for Swift |

### Phase 5: Special Purpose

| Status | File | Lines | Complexity | Plan File | Notes |
|--------|------|-------|------------|-----------|-------|
| ⬜ | `isolate_name_server.dart` | ~100 | 🟡 Medium | `plans/isolate_name_server_plan.md` | Isolate port registration |
| ⬜ | `platform_isolate.dart` | ~200 | 🟡 Medium | `plans/platform_isolate_plan.md` | Platform isolate support |
| ⬜ | `plugins.dart` | ~50 | 🟢 Simple | `plans/plugins_plan.md` | Plugin registration utilities |
| ⬜ | `natives.dart` | ~20 | 🟢 Simple | `plans/natives_plan.md` | Native function declarations - may be obsolete in Swift |
| ⬜ | `setup_hooks.dart` | ~20 | 🟢 Simple | `plans/setup_hooks_plan.md` | Hook initialization - may need redesign |
| ⬜ | `ui.dart` | ~50 | 🟢 Simple | `plans/ui_plan.md` | Main library export file |

### Test/Fixture Files (Reference Only)

| File | Notes |
|------|-------|
| `fixtures/ui_test.dart` | Test fixture, not for migration |

---

## Planning Progress Summary

**Total Files to Plan:** 20
**Planning Complete:** 3
**In Progress:** 0
**Not Started:** 17

**Estimated Planning Effort:**
- 🟢 Simple (8 files): ~30 min each = 4 hours
- 🟡 Medium (6 files): ~1 hour each = 6 hours
- 🔴 Complex (6 files): ~2 hours each = 12 hours
- **Total:** ~22 hours of planning

---

## Planning Session Template

**IMPORTANT:** Plans are TASK TRACKERS, not implementation guides. Focus on DEPENDENCIES and WHAT needs to be done, not HOW.

DO NOT include:
- Generated code examples
- How-to explanations
- Detailed implementation steps
- Obvious control flow descriptions

DO include:
- **Dependencies** (most important!)
- Line ranges for each API element (e.g., `L10-15` or just `L10`)
- C++ bridge requirements
- **Every member as a separate subtask** (constructors, fields, getters, methods, operators)
- Use tables to organize members by class
- Total member count per class

When planning a file, create `plans/<filename>_plan.md` with this structure:

```markdown
# <Filename> Migration Plan

**Dart Source:** `engine/src/flutter/lib/ui/<filename>.dart`
**Complexity:** 🟢 Simple / 🟡 Medium / 🔴 Complex
**C++ Bridge Required:** Yes/No

## Dependencies

### dart:ui Dependencies
- `file.dart::functionName` - used at lines XXX, YYY
- `file.dart::ClassName` - used at lines XXX, YYY

### C++ Dependencies
- `CppClassName::method` - called at line XXX (needs bridge)
- `@Native CppFunction` - called at line YYY (needs bridge)

## API Inventory

### Classes
- **ClassName** (lines XXX-YYY) - N methods, M operators, uses: [dependencies]

### Functions
- **functionName** (lines XXX-YYY) - uses: [dependencies]

### Enums/Constants
- **EnumName** (lines XXX-YYY)

## Migration Tasks

**IMPORTANT:** List EVERY member (constructor, field, getter, method, operator) as an individual subtask. Use tables for classes with many members.

### 1. ClassName (lines XXX-YYY) - N members

| Status | Member | Lines | Type | Notes |
|--------|--------|-------|------|-------|
| [ ] | `ClassName(...)` | 10-15 | constructor | notes |
| [ ] | `fieldName` | 17 | field | final/var type |
| [ ] | `propertyName` | 20-29 | getter | returns Type |
| [ ] | `methodName(...)` | 31-45 | method | uses: deps |
| [ ] | `operator +` | 47-52 | operator | notes |
| [ ] | `operator ==` | 54-60 | operator | equality |
| [ ] | `hashCode` | 62-63 | getter | Object.hash |
| [ ] | `toString()` | 65-70 | method | override |

### 2. FunctionName (lines XXX-YYY)

| Status | Member | Lines | Type | Notes |
|--------|--------|-------|------|-------|
| [ ] | `functionName(...)` | 5-20 | function | uses: deps |

### C++ Bridge (if needed)

| Status | Task | Lines | Notes |
|--------|------|-------|-------|
| [ ] | Bridge for `CppClass::method` | XXX | @Native signature |

### Testing

| Status | Task | Notes |
|--------|------|-------|
| [ ] | Port existing tests | location |
| [ ] | Verify edge cases | specific cases |

## Notes
[Only critical, non-obvious information]
```

---

## Swift Source Mapping Convention

To track the relationship between Dart source code and ported Swift code (enabling AI to reference Swift implementations without grepping the codebase), use structured comments in Swift files.

### Comment Format

```swift
// @dart-source: <filename>:<line-start>-<line-end>
// @dart-symbol: <SymbolName>
```

### Example: OffsetBase in Swift

```swift
// @dart-source: geometry.dart:7-92
// @dart-symbol: OffsetBase
public class OffsetBase {
    // @dart-source: geometry.dart:17
    // @dart-symbol: OffsetBase._dx
    public let dx: Double

    // @dart-source: geometry.dart:18
    // @dart-symbol: OffsetBase._dy
    public let dy: Double

    // @dart-source: geometry.dart:20-29
    // @dart-symbol: OffsetBase.isInfinite
    public var isInfinite: Bool {
        return dx.isInfinite || dy.isInfinite
    }

    // @dart-source: geometry.dart:39-46
    // @dart-symbol: OffsetBase.operator<
    public static func < (lhs: OffsetBase, rhs: OffsetBase) -> Bool {
        return lhs.dx < rhs.dx && lhs.dy < rhs.dy
    }
}
```

### Querying Mappings

AI can use `grep` to find Swift implementations:

```bash
# Find where OffsetBase is implemented
grep -r "@dart-symbol: OffsetBase$" Sources/

# Find all symbols from geometry.dart
grep -r "@dart-source: geometry.dart" Sources/

# Find a specific member
grep -r "@dart-symbol: OffsetBase.isInfinite" Sources/
```

### Benefits

1. **Self-documenting** - Mappings live with the code
2. **AI-queryable** - Simple grep finds any symbol instantly
3. **Traceable** - Each Swift symbol links back to exact Dart source lines
4. **Maintainable** - Comments update with the code during refactoring
5. **No external database** - No separate mapping files to keep in sync

### Rules

1. **Every ported symbol MUST have both comments** (`@dart-source` and `@dart-symbol`)
2. **Class-level comments** go before the class declaration
3. **Member-level comments** go before each member (properties, methods, operators)
4. **Use fully qualified names** for members: `ClassName.memberName` or `ClassName.operator<`
5. **Line ranges** use `-` for multi-line, single number for single line

---

## Example: Good vs Bad Plan

### ❌ BAD (Too much noise - explaining HOW to implement):
```markdown
### Swift Implementation Strategy
Use Swift Double type, implement as public func, preserve assert behavior...

```swift
public func clampDouble(_ x: Double, _ min: Double, _ max: Double) -> Double {
    // ... generated code ...
}
```

### Migration Tasks
- [ ] clampDouble (lines 13-25)
  - Return min if x < min (lines 15-17)
  - Return max if x > max (lines 18-20)
  - Return max if x.isNaN (lines 21-23)
  - Return x otherwise (line 24)
  - Test NaN input, infinity values, boundaries...
```

### ❌ BAD (Class-level only - not granular enough):
```markdown
## Migration Tasks
- [ ] Size (lines 346-616)
- [ ] Rect (lines 627-935)
- [ ] Port tests
```

### ✅ GOOD (Every member listed as subtask with line ranges):
```markdown
## Dependencies

### SDK Libraries
| Library | Symbols |
|---------|---------|
| dart:core | ArgumentError, Object, double, int |
| dart:math | min, max |

### Cross-File Dependencies (must port first)
| Source File | Symbols | Notes |
|-------------|---------|-------|
| lerp.dart | `_lerpDouble` | Used in Size.lerp (line 573) |
| math.dart | `clampDouble` | Used at lines 967, 981 |

## API Inventory
- **Size** (lines 346-616) - 24 members, uses: math.min/max, _lerpDouble, Offset

## Migration Tasks

### 1. Size (lines 346-616) - 24 members

| Status | Member | Lines | Type | Notes |
|--------|--------|-------|------|-------|
| [ ] | `Size(double width, double height)` | 347-349 | constructor | const |
| [ ] | `Size.copy(Size source)` | 350-353 | constructor | copy |
| [ ] | `Size.square(double dimension)` | 354-360 | constructor | const |
| [ ] | `width` | 378-379 | getter | returns _dx |
| [ ] | `height` | 381-382 | getter | returns _dy |
| [ ] | `aspectRatio` | 384-409 | getter | edge cases for 0/infinity |
| [ ] | `zero` | 411-414 | static const | Size(0.0, 0.0) |
| [ ] | `operator -(OffsetBase other)` | 427-451 | operator | returns Offset or Size |
| [ ] | `operator *(double operand)` | 462-468 | operator | multiplication |
| [ ] | `lerp(Size? a, Size? b, double t)` | 573-602 | static method | uses _lerpDouble |
| [ ] | `operator ==` | 607 | operator | equality |
| [ ] | `hashCode` | 612 | getter | Object.hash |
| [ ] | `toString()` | 615 | method | override |
... (all 24 members listed)

## Notes
- NaN input returns max (line 21) - non-obvious behavior
- Must port `lerp.dart` and `math.dart` before this file
```

---

## Next Steps

1. **Start with `math.dart`** - Simplest file, single function
2. Create detailed plan in `plans/math_plan.md`
3. Update this file with ✅ when complete
4. Move to next file in priority order
5. Continue until all planning is complete

---

**Document Version:** 1.0
**Last Updated:** 2026-01-15
**Maintained By:** Migration Team
