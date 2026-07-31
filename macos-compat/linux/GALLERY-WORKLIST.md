# Gallery probe — breadth work-list

`probe/Gallery` is the second, comprehensive probe (after `probe/Hello`): a stock
SwiftUI app exercising the common **layout primitives, controls, and modifiers**.
Built UNMODIFIED with Apple's toolchain on macOS, run through `machold` on
Linux/arm64. This file is the measured reconstruction work-list.

## How it was built (on the Mac)

```bash
cd macos-compat/probe
xcrun swiftc -parse-as-library -target arm64-apple-macos14.0 \
  -sdk "$(xcrun --show-sdk-path)" -O -o Gallery Gallery.swift
```

Result: Mach-O arm64, `LC_DYLD_CHAINED_FIXUPS` + `LC_MAIN` (same format `machold`
already handles), `minos 14.0`. **127 imports** (Hello had 87).

Re-measure the surface any time with:
```bash
xcrun dyld_info -imports probe/Gallery | awk 'NR>1{print $2}' | xcrun swift-demangle
```

## Delta vs Hello: 58 new SwiftUI symbols + 5 non-SwiftUI

Everything Hello needed is already reconstructed. The breadth work is the delta below.

### New layout containers / modifiers (the core of this milestone)

| SwiftUI type | Reconstruct | Flutter target (CompatHost) |
|---|---|---|
| `HStack` / `_HStackLayout` | struct + `View` conformance + witness | `Row` |
| `ZStack` / `_ZStackLayout` | struct + `View` conformance | `Stack` |
| `ScrollView` (`init(_:showsIndicators:content:)`) | struct + `View` conformance | `SingleChildScrollView` |
| `Group` | struct (transparent passthrough in tree) | inline children |
| `Spacer` | struct | `Spacer` / `Expanded` |
| `Divider` (`init()`) | struct | `Divider` |
| `ForEach` (`init(_: Range<Int>, content:)`) | struct, `Range==Data` | expand → `[Widget]` |
| `_FrameLayout` (`.frame(width:height:alignment:)`) | `ViewModifier` + witness | `SizedBox` / `ConstrainedBox` |
| `_ClipEffect` (`.cornerRadius`) | `ViewModifier` + conformance | `ClipRRect` / `Container(borderRadius:)` |
| `_EnvironmentKeyWritingModifier` (`.foregroundColor`) | `ViewModifier` (env write) | fold into child `TextStyle`/color |

### New leaf views

| SwiftUI type | Reconstruct | Flutter target |
|---|---|---|
| `Image(systemName:)` | struct | `Icon` (map SF-symbol name → glyph) |
| `Color` (as a `View`) + `View` witness | struct | `Container(color:)` |
| `RoundedRectangle` + `RoundedCornerStyle.continuous` | shape struct | rounded `Container` |
| `TextField(_:text:...)` | struct, `Binding<String>` | `TextField` |
| `Toggle(_:isOn:)` | struct, `Binding<Bool>` | `Switch` |
| `Slider(value:in:onEditingChanged:)` | struct, `Binding<BinaryFloatingPoint>` | `Slider` |

### New `Text` modifiers (return `Text`, fold into `TextStyle`)

- `Text.font(Font?)`, `Text.fontWeight(Font.Weight?)`, `Text.foregroundColor(Color?)`, `Text.bold()`

### New static getters (enum/struct cases — declare to match mangling)

- **Color:** `.blue .green .white .yellow .primary .secondary`
- **Font:** `.largeTitle .subheadline`; **Font.Weight:** `.bold`
- **Alignment:** `HorizontalAlignment.leading`, `VerticalAlignment.center`, `Alignment.center`
- **Axis.Set:** `.vertical` (ScrollView default axis)

### New non-SwiftUI symbols (5)

| Symbol | Status on Linux |
|---|---|
| `swift_getKeyPath` | ✅ in `libswiftCore.so` |
| `Double : BinaryFloatingPoint` conformance | ✅ in `libswiftCore.so` |
| type metadata `Swift.Bool`, `Swift.String` | ✅ in `libswiftCore.so` |
| `___chkstk_darwin` | ❌ Darwin stack-probe — **add a stub in the loader's resolver** (no-op; or alias to `__chkstk`). The only new bottom-layer gap. |

## Suggested order (incremental, bisectable)

`Gallery.swift`'s `ContentView` is split into commentable sections. Grow the
reconstruction + `toWidget` one group at a time, in this dependency order:

1. **Stacks**: `HStack`/`ZStack` + `Spacer`/`Divider` (closest to existing VStack).
2. **`.frame` / `.foregroundColor` / `.font` modifiers** (most-used; unlock the rest).
3. **`Color` as a View** + color/font static getters.
4. **`ScrollView` + `Group`** (containers).
5. **`ForEach(Range)`** (data-driven expansion in the reflection walk).
6. **Controls**: `Toggle`, `TextField`, `Slider` (each needs a `Binding<T>` round-trip
   back through `swiftui_compat_dispatch`, like `Button`).
7. **`Image` / `RoundedRectangle` / `_ClipEffect`** (cosmetic; do last).

After each group: rebuild `libSwiftUI.so`, run `./run.sh ../probe/Gallery`, and
confirm the symbol count drops + the section renders (pixproof).

> Tip: `machold` currently `DIE`s on the first unresolved import. Hardening it to
> collect and print **all** unresolved imports in one run (and run `__mod_init_func`
> initializers) makes this loop much faster — see the "measurement tool" step.

## Progress (2026-06-06)

- [x] **Loader hardened.** `machold` now (a) stubs `___chkstk_darwin` with a *real*
  arm64 stack-probe (Swift's dynamic alloca jumps `sp` past the guard gap; a no-op
  stub SIGSEGVs on large frames), and (b) collects + prints **all** unresolved
  imports in one run instead of dying on the first.
- [x] **All 127 imports resolve.** The 57 new SwiftUI symbols are reconstructed in
  `SwiftUIShim/Sources/SwiftUI/Gallery.swift` (shared source); `LC_ALL=C` symbol
  diff vs the binary is **0 missing**. Gallery loads, binds, reaches `App.main()`.
- [x] **Most of the tree constructs.** `ContentView.body` builds correctly through
  typography (`Group`/`Text`/`.font`/`.fontWeight`/`.foregroundColor`/`.bold`),
  `Divider`, the `HStack`+`Image`+`Spacer`+`.bold` row, the `ZStack`+`Color`+
  `.frame`+`.cornerRadius` overlay, and the counter `HStack` — i.e. the stacks,
  containers, leaves, and inlined modifiers all work.

### Key ABI findings (the hard part)

- **@frozen vs resilient return ABI.** `Color`/`Font`/`Font.Weight`/`Image` import
  no metadata accessor → Apple declares them `@frozen` and returns them **by value
  in registers** (8 bytes, a single provider class). Reconstructing them as
  *resilient* structs holding an inline `String` (16 bytes) made the binary's
  value-copy **overflow its fixed 8-byte buffer** → SIGSEGV. Fix: `@frozen` structs
  wrapping one provider class (`_ColorBox`/`_FontBox`/`_ImageBox`); `Font.Weight` =
  `{ value: CGFloat }`.
- **`Binding` is 17 bytes, not 16.** Measured from the binary: it loads the Binding
  as `ldp x4,x5,[buf]; ldurb w6,[buf+0x10]` — a byte at offset 16. That tips it over
  16 bytes, so Apple **returns Binding via sret** and passes it in 2 regs + a byte.
  Ours is now `{ _transaction(8), box(8), _flag(1) }` = 17 bytes.

### The Binding return-ABI gap — root-caused by gdb, adapter landed

gdb tracing pinned the controls' fault to a **Swift cross-version return-ABI
difference**. The binary calls the generic `State.projectedValue` getter expecting
the 17-byte `Binding` returned via **sret** (it sets `x8` = result buffer, reads the
`Binding` from it). But Swift 6.2.4 returns `≤4`-field structs **in registers**
(verified: a 3- and even 4-field `@frozen` struct returns in regs; it switches to
sret only at 5 fields / 33 bytes). So our getter left the binary's sret buffer
unwritten → the control init read a garbage `Binding` and retained a non-object.
This is the AAPCS "`>16` bytes → indirect return" rule (what the binary was built
against) vs Swift 6.2.4's "`≤4` registers → direct" rule. It can't be fixed in the
struct: a *resilient* `Binding` fixes the return (sret) but flips the by-value PASS
into a by-pointer pass → NULL deref.

**Fix (landed) — all 3 controls construct.** The real key: Apple's `Binding<Value>`
**stores `Value` inline** (`{transaction(8), location(8), value: Value}`), measured
from the binary — `Binding<Bool>` is 17 bytes (loaded `x4,x5`+byte) but
`Binding<String>` is 32 bytes (`x4,x5,x6,x7`). Reconstructing `Binding` with a real
`_value: Value` field (a) sizes it correctly for every `Value` (so the by-value PASS
and stack-arg layout match — fixes the `TextField`/`Slider` SIGBUS that was a
*neighbouring* stack arg, not a Darwin-refcount issue), and (b) makes `Binding<Value>`
**address-only** in the generic `projectedValue` getter, so Swift returns it **via
sret naturally** — exactly what the binary wants. No loader adapter needed (the
earlier trampoline was removed). `Toggle`, `TextField`, and `Slider` all construct.

### DONE — Gallery renders + interacts on Linux/arm64 🎉

Side-by-side: [`gallery-macos.png`](gallery-macos.png) (the real app on macOS) vs
[`gallery-linux.png`](gallery-linux.png) (the same unmodified binary via `machold` +
Flutter on Linux/arm64). The Linux host renders with `MacosTheme(.dark())` + the
repo's `MacosUI` controls (`PushButton`/`MacosCheckbox`/`MacosTextField`/`MacosSlider`)
and a full-width stretch layout to match.


The last blocker was the same sret-return gap as `Binding`: gdb showed the binary
sets up an sret buffer (`x8`) for `ForEach.init`, but our 32-byte (4-word) `ForEach`
returns in **registers**, leaving it unwritten → the copy-witness later reads garbage.
Apple's `ForEach` is the same `{data, content}` (32 B) but returned via sret (the
AAPCS `>16 bytes → indirect` rule). Fix: make `ForEach` **resilient** (drop `@frozen`)
so our init returns via sret. With that, **the entire `ContentView.body` constructs.**

Then the reflection (`Reflect.swift`/`FlutterBridge.swift`) and `CompatHost.toWidget`
were extended to cover every node: ScrollView→SingleChildScrollView, HStack→Row,
ZStack→Stack, Group (transparent), Spacer→Expanded, Divider, Image (glyph),
Color→ColoredBox, `.frame`→SizedBox, `.cornerRadius`→ClipRRect, `.foregroundColor`/
`.font`/`.bold`→TextStyle, **ForEach expanded by calling its content closure per
element**, and Toggle/TextField/Slider reading their `@State` values.

`./run.sh ../probe/Gallery` now renders the full Gallery — title/subheadline, divider,
the rating row, the ZStack, the Count/Increment row, the Enabled toggle (green=on),
the "Flutter" text field, the slider at 0.5, and the 2×3 ForEach grid of rounded
green boxes — and **clicking Increment bumps the counter live** (Count 0→1), exactly
like Hello. The general lesson across Binding + ForEach: Swift 6.2.4 returns
`≤4`-word structs in registers, but the macOS binary (older Swift ABI) expects
`>16`-byte structs via sret — make the type resilient (or address-only) to bridge it.

### Remaining after the controls unblock

- Extend `Reflect.swift` + `FlutterBridge.swift` to walk the new containers/leaves
  (HStack→row, ZStack→stack, ScrollView, Spacer, Divider, Image→Icon, Color→box,
  `.frame`/`.cornerRadius`/`.foregroundColor`/`.font`, `ForEach` expansion) and the
  controls (Toggle/TextField/Slider with their `Binding` round-trips).
- Extend `CompatHost.toWidget` with the matching Flutter widgets.
