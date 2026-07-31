# macos-compat: SwiftUI feature work-list (discovery 2026-06-11)

How this was produced: one minimal probe per feature (`probe/D_*.swift`), each built
unmodified with Apple's toolchain and run under `machold` on Linux. machold reports the
**unresolved imports** for any feature we don't yet reconstruct — that's the work-list.
Build a probe with `xcrun swiftc -parse-as-library -O` and run `MACHOLD_VERBOSE=1
./run.sh ../probe/D_x` to see its `UNRESOLVED:` lines.

Outcome per feature: **RENDERS** (works), **FATAL** (unresolved imports — needs the listed
types), **CRASH** (binds but the render path mishandles it).

## TIER 2 GUI — AppKit renders through Flutter (2026-07-02)

The strategic pivot landed: an **unmodified ObjC/AppKit app draws through the same Flutter
host** as the SwiftUI tier, reusing the entire render path. machold synthesizes AppKit
classes that build the RNode JSON the host already renders.
- **NSApplication/NSWindow/NSView/NSTextField/NSButton** (`machold_init_appkit`, same
  synthesis template as the Foundation classes). `-[NSApplication run]` is THE SEAM: fires
  `applicationDidFinishLaunching:` on the delegate, walks the key window's `contentView`
  subviews into RNode JSON (a `column` of `text`/`button` nodes via `open_memstream`), and
  calls `swiftui_compat_run` (blocks in the GLFW loop). `NSRect` is an HFA in d0-d3 — the
  msgSend trampoline already preserves q0-q3. `objc_autoreleasePoolPush/Pop` → no-op.
- **Interactive**: machold now DEFINES `swiftui_compat_dispatch` (build.sh `--export-dynamic`
  → main-exe def wins the host bind over libSwiftUI's). AppKit taps → the registered
  NSButton's `objc_msgSend(target, action, sender)` → re-walk → `swiftui_compat_update`;
  tier-1 Swift taps forward via `dlsym(RTLD_NEXT)` to libSwiftUI's def (`@State` intact).
- **NSStackView** (G4): the modern layout container → RNode column/row by orientation
  (`addArrangedSubview:`/`setOrientation:`); the walk drives `contentView` through
  `machold_json_view` so a stackview contentView emits its own column/row.
- **NSSlider** (G4): `sliderWithValue:minValue:maxValue:target:action:` (3 doubles in d0-d2)
  → `{"t":"slider","value":frac}`. (Thumb renders at left — a pre-existing MacosSlider host
  limitation "needs layout width", `MacosProgressIndicator.swift:163`; the fill tracks value.)
- **NSButton checkbox/toggle** (G5): host `.toggle` has no dispatch-back, so a checkbox reuses
  button dispatch — renders as a button node with an ASCII `[x]/[ ]` marker; `+checkboxWith
  Title:target:action:`/`-state`/`-setState:`/`-setButtonType:`; dispatch XORs the checkbox
  state before firing the action (NSButton grew kind@32/state@40, instanceSize 48).
- **NSImageView + NSProgressIndicator** (G6): NSImage (`+imageWithSystemSymbolName:` /
  `+imageNamed:`) + NSImageView → `{"t":"image","name":<symbol>}`; NSProgressIndicator
  (`-setDoubleValue:`/`-setMin/MaxValue:`/`-setIndeterminate:`) → `{"t":"progress","value":
  frac}`. Progress bar renders at value; SF Symbol glyph only if the host icon map has it.
- **NSTableView** (G7): the first control where the walk messages BACK INTO the app —
  `numberOfRowsInTableView:` then `tableView:objectValueForTableColumn:row:` per row on the
  dataSource → a column of text rows (`NSTableColumn` `initWithIdentifier:`/`setTitle:`;
  `machold_display_bytes` stringifies NSString values). Demonstrates the reverse-of-dispatch
  callback direction.
- **Editable NSTextField** (G8): the last interactive mechanism — host→app TEXT routing
  (counterpart to tap dispatch). The host's `.textField` node gained an id + wires
  `MacosTextField.onSubmitted → swiftui_compat_text(id, text)`; machold defines/owns
  `swiftui_compat_text` (export-dynamic), sets the field's stringValue and fires its
  target/action (or delegate `controlTextDidEndEditing:`), then re-walks. `+textFieldWith
  String:`/`-setEditable:`/`-setTarget:`/`-setAction:`/`-setDelegate:` (NSTextField grew to
  editable@16/target@24/action@32/delegate@40). `MACHOLD_AUTOTEXT=<text>` headless harness.
- **Composite task app** (G9, the "RealApp" of the ObjC tier): validates the whole bridge in
  one realistic app AND the app-delegate launch path (window built in
  `applicationDidFinishLaunching:`, which `-run` fires before walking). An AppDelegate that is
  both delegate + table dataSource + field action target: type "Read book" → `-addTask:`
  appends to an NSMutableArray → `reloadData` → the walk re-pulls the dataSource → the new row
  renders ([Buy milk, Walk dog] → +Read book). No new machold code — every class/selector
  already covered.
- **NSPopUpButton** (G10): a dropdown → the host picker node (options + selectedIndex +
  per-option dispatch ids); reuses the tap path (g_btn grew popup/optidx — a popup option
  sets the popup's selectedIndex then fires its target/action). `addItemsWithTitles:` reads
  the NSArray by messaging count/objectAtIndex:. Autotap selects an option → the choice
  highlights + echoes.
- **Probes**: G0 (empty), G1 (label), G2/G3 (counter), G4 (stackview+slider), G5 (checkbox),
  G6 (image+progress), G7 (table via dataSource), G8 (editable field echo), G9 (composite task
  app via delegate), G10 (dropdown Red→Green) — all frame-verified. Both tiers regression-clean.

Both interaction directions now work for AppKit: **app→host** render (`-run` → RNode →
`swiftui_compat_run`), **host→app** taps (`swiftui_compat_dispatch` → target/action) and text
(`swiftui_compat_text`), and **app←→app** data pull (NSTableView dataSource messaging).

**Real-binary scouting (2026-07-02)** — ran a real macOS system binary (`/usr/bin/sw_vers`,
arm64e slice) under machold. Loader gained **arm64e chained-fixup support** (formats 9/12:
auth@63, bind@62, 11-bit next, stride 8, PAC bits dropped) — arm64 probes unaffected. Symbols
resolve with **zero unresolved**: the Linux Swift toolchain's **CoreFoundation fork** backs CF*
via dlsym; 3 libSystem shims added (`___std{in,out,err}p`, `malloc_type_*`,
`_CFCopySupplementalVersionDictionary`). **Execution wall = PAC — now DEFEATED**: the box has `paca/pacg`
enabled; binding pointers unsigned made arm64e auth-branches fault. Fix: `machold_disable_pac()`
does a **raw `prctl(PR_PAC_SET_ENABLED_KEYS, 0x0f, 0)` syscall** (raw `svc`, not the glibc
wrapper — its pac-ret-signed live return would make the kernel refuse to disable IA) right
before entering the Mach-O, clearing `SCTLR_EL1.En{IA,IB,DA,DB}` so `pac*`/`aut*` become NOPs
and unsigned pointers are accepted. Gated to arm64e; the arm64 path is untouched (machold has
no pac-ret). **Real arm64e now executes**: `sw_vers` runs its real code (blocked only by the
Linux CF lacking a macOS version dict — an OS-data gap); probes recompiled as arm64e produce
byte-identical output to arm64 (`O0_minimal_e`/`O9_format_e`). So arm64e system tools are
loadable+bindable+**executable** — the remaining gap for real tools is macOS OS-data/CF-fork
coverage, not PAC. (Only the generic key `0x10` can't be toggled — EINVAL — and needn't be.)

**A REAL macOS system binary now PRINTS on Linux (2026-07-03)** — `/usr/bin/sw_vers` (arm64e)
runs unmodified under machold and outputs `ProductName: macOS / ProductVersion: 14.5 /
BuildVersion: 23F79-machold` (+ `-productVersion`/`-buildVersion` args). The last two walls:
(1) **OS-data** — machold fabricates the version dictionary `__CFCopySupplementalVersionDictionary`
returns (nil on Linux → its error), built via the Linux CF (`CFStringCreateWithCString` +
`CFDictionaryCreate`); the version-key constants are exported by the Linux CF fork *with a
leading underscore* (`_kCFSystemVersionProductNameKey`). (2) **Linux CF Swift-bridge crash** —
`CFDictionaryGetValueIfPresent` with CFType callbacks routes hashing through `_CFSwiftGetHash`
→ `swift_dynamicCastFailure`; bypassed by building the dict with **NULL callbacks** (pointer
hash/equality) keyed by the constant CFString pointers sw_vers looks up with. This is the full
"unmodified real Apple binary executes and produces correct output on Linux" milestone.

**Second real binary + frontier map (2026-07-03)** — `/usr/bin/arch` now prints `arm64` too,
via generic BSD/libSystem shims (NXGetLocalArchInfo — real struct has `name` at offset 0! —
getprogname/errc/sysctlbyname/realpath + spawn-mode null stubs). **Real-binary frontier now
mapped**: CF-only tools work (`sw_vers` ✓, `arch` ✓); Foundation-ObjC tools need the deferred
**Foundation-fusion** — `plutil` = 73 unresolved (real `NSJSONSerialization`/`NSPropertyList
Serialization`/`NSError`/`NSException` ObjC classes + Swift-Foundation bridging), `defaults` =
20. That fusion (real Foundation ObjC classes, or bridging to the Linux Swift-Foundation
implementations) is the next big frontier for real Foundation tools.

**Foundation-fusion STARTED (2026-07-03)** — synthesizing the Foundation ObjC classes real
tools need, via machold's proven recipe (so the objects message cleanly through machold's
runtime). Phase 1 (`F1_error`): **NSError** + the generic ObjC runtime entry points every
Foundation binary uses — `objc_opt_new`, `objc_opt_isKindOfClass`, `objc_getProperty`/
`objc_setProperty*`, and a fix to `objc_opt_class` (was returning the metaclass for a class
receiver like `[NSError class]`). Phase 2 (`F2_procfs`): **NSProcessInfo** (arguments/
processName/pid) + **NSFileManager** (fileExistsAtPath:/contentsAtPath:). Foundation-tool
unresolved: plutil 73→68, defaults 20→16.
**The hard core remaining** (the reason the counts drop slowly): (a) serialization classes
`NSJSONSerialization`/`NSPropertyListSerialization` — the Linux CF *does* implement these, but
their results are Linux-CF/Swift objects that **can't be messaged through machold's
from-scratch ObjC runtime** (no Darwin method lists) — the central impedance; (b) Swift-
Foundation bridging thunks (`$s…10FoundationE_bridgeToObjectiveC…` for Array/Dict/String/Data/
Date) — module-split mangling; (c) `NSException` + real `@try/@catch` (needs DWARF unwinding).
Phase 3 (`F3_serial`) — **the serializers, via a machold⇄Swift-Foundation bridge** (chosen
over hand-rolling parsers in C): NSJSONSerialization/NSPropertyListSerialization route to the
Linux Swift toolchain's real `JSONSerialization`/`PropertyListSerialization` (a
`FoundationFusion.swift` in libcompat_host), which parse/emit and convert the Swift `Any` tree
⇄ **machold-native** objects at the boundary via an exported `machold_obj_*` C ABI. The binary
only sees machold-native collections (messageable) — the impedance never arises. NSNumber
gained an int/double/bool type tag; added NSNull. This bridge is **reusable for any
Swift-Foundation API** (NSDateFormatter/NSLocale/regex → wrap + convert). plutil 68→66,
defaults 16→15.

Phase 4 (`F4_date`): **NSDateFormatter via the same bridge** — `machold_fusion_date_format/parse`
drive Swift's DateFormatter (UTC/POSIX); machold's NSDateFormatter reuses NSString/NSDate so
in/out are messageable. Confirms the bridge is a general pattern (wrap any Swift-Foundation API,
convert at the edge), not serializer-specific.

Phase 5 (`F5_plumbing`): CLI-tool plumbing — **NSFileHandle** (writeData: to a fd, how tools
emit output), NSAutoreleasePool (no-op), NSCharacterSet (whitespace), NSString rangeOfString:
(NSRange struct return) + path methods, and resolve-only stubs (CFPreferences SPI, objc
exception, NSSearchPath). **`defaults` now LOADS with 0 unresolved** and runs partway.

**NEW WALL — the REVERSE impedance**: `defaults read <file>` parses the plist via the bridge
(→ machold-native objects) but then crashes in Linux CF's `_CFSwiftIsEqual` — a machold-native
object passed *into* Linux CF's C API dynamic-cast-fails (the mirror of the forward impedance
the bridge solves). CF-heavy ObjC tools that feed our objects back into CF C functions hit this.
Solving it means making machold objects survive CF calls (give them a CF-recognizable type) or
avoiding CF on our objects — a deeper effort than the forward bridge.

Phase 6 (`F6_cfbridge`): **reverse-impedance solved (the general mechanism)** — machold-aware
CF C functions. Wrappers for CFGetTypeID/CFEqual/CFRelease/CFStringGetLength/CFStringHasPrefix/
CFNumberIsFloatType detect a machold object (`machold_obj_type != -1`) and handle it natively,
else forward to the real Linux CF (bound only in the loaded Mach-O's imports, so the Swift tier
is untouched). NSFileHandle writeData: now handles a real CFMutableData too. Machold-native
objects now survive Linux CF's C API. `defaults` gets past the object-equality wall and reaches
CFPreferencesCopyMultiple, which crashes **inside Linux CF** (`__CFCopyFormattingDescription`) —
a defaults-specific CFPreferences path (next wall: intercept the CFPreferences family to read
the plist file + return machold objects, or a working Linux CF prefs impl).

Phase 7 (`F7_describe`): CFPreferences intercept + -description. `defaults read <file>` now
loads, intercepts CFPreferences (CopyMultiple/CopyKeyList/CopyValue read `<domain>.plist` via
the bridged parser → a machold-native dict — Linux CF's own CFPreferences crashes), and
**builds the correct 4-entry dict**. -description renders the OpenStep `{ k = v; }` format
(F7 = exactly what `defaults` prints); + NSString breadth (+alloc/-initWithFormat:arguments:,
rangeOfString:, path methods, trim, dataUsingEncoding:allowLossyConversion:), NSMutableArray
factories, mlist capacity 24→48. **`defaults` reads its data correctly but its output path
(not writeData:/msgSend-description we traced) doesn't reach stdout** — a tool-specific
rendering tail (likely a CF stream or a stubbed fn silently dropping output).

**ObjC EXCEPTIONS done (X1)** — @try/@catch/@throw work via a self-contained compact-unwind
mini-unwinder (NOT DWARF: Apple arm64 has only __unwind_info + the Itanium LSDA, so libgcc's
unwinder can't be driven). Load builds a PC→LSDA table from __unwind_info; objc_exception_throw
(naked) captures the thrower's regs → machold_eh_search parses the LSDA call-site/action/ttype
tables + matches the exc isa chain vs OBJC_EHTYPE_$_NSException → machold_eh_resume (naked)
restores sp/x29/callee-saved and branches to the landing pad (x0=exc, x1=filter). NSException
synthesized. Single-frame only (throw+catch same fn); cross-frame cleanup deferred.

**Swift _bridgeToObjectiveC thunks (2nd big piece, PARTIAL — plutil 66→36):** two reusable
idioms — (a) 3 collection rewrites (`So7NSArrayC→AA7NSArrayC` etc.; Darwin __C classes are
Swift-defined on Linux, mangled as the `AA` substitution back-ref, not `10Foundation`), (b) a
`bridge_exact[]` Darwin→Linux full-symbol map table for value types moved to
`20FoundationEssentials` (Data/URL/Date/CocoaError, with `0A0E` ext markers + substitution
shifts). Swift tier + all suites regression-clean. REMAINING for plutil (36, a long tail):
StringProtocol compare/range/replace exact maps; ~10 C-func/runtime stubs (class_getSuperclass,
objc_allocWithZone, NSStringFromClass, __error, swift_dynamicCastObjCClass…); 5 error-domain
globals; 4 classes (NSLocale/NSTimeZone/NSMutableCharacterSet/NSISO8601DateFormatter); several
genuinely-absent Swift symbols — then the native↔Linux-Foundation impedance at the serializer
boundary (uncertain even after loading). A large mechanical harvest, not a quick finish.

**plutil now LOADS (0 unresolved) + runs + reads the file**, then hits the WALL: `plutil -p`
aborts at "Could not cast value … to Foundation.NSData" — plutil's Swift does `as NSData` on a
machold-native object and Swift's dynamic cast fails (machold isa ≠ Linux Swift metadata). This
is the fundamental native↔Linux-Foundation impedance for a Swift+ObjC HYBRID: a single object
can't satisfy both ObjC-message access (needs machold objects) AND Swift `as?`-casts (needs
Linux Swift objects). The symbol-resolution half is DONE (all 66 resolve via rewrites/exact-maps/
stubs/minimal classes: NSLocale/NSTimeZone/NSISO8601DateFormatter, error globals, runtime stubs,
NSData +dataWithContentsOfFile:, NSFileHandle -fileDescriptor). Solving the wall needs machold's
Foundation objects to BE Linux Swift objects for hybrid tools — which reintroduces the forward
impedance on the ObjC-message paths (the hard bidirectional problem).

**"USE SWIFT OBJECT" — the bidirectional bridge, DONE for the NSData boundary.** The Swift-cast
wall is broken: +[NSData dataWithContentsOfFile:] now returns a REAL Linux Swift NSData (via
FoundationFusion machold_fusion_data_from_file), so plutil's `as Data` cast succeeds; and
machold's objc_msgSend gained a FOREIGN-OBJECT DISPATCH (machold_msgSend_fail → CFGetTypeID →
route CFData/CFString selectors to the CF C-API) so Swift-native objects also take machold
messages — the two-way bridge. machold_nsdata_ptr lets serializers/writeData read either kind.
plutil now READS (real NSData) → PARSES (machold tree) → SORTS keys → EMITS output. Remaining is
a plutil-internal per-selector tail: its PLU* mutable subclasses want private NSArray/NSDict CF
internals (_initByAdoptingBuffer:count:size:, initWithObjects:forKeys:count:, isValidJSONObject:)
and the -p C-string path needs a few accessors. Not a clean finish, but the hard impedance is gone.

**plutil -p now READS→PARSES→SORTS→PRINTS VALUES.** Traced the remaining defect: [key UTF8String]
returns VALID pointers, but plutil prints "(null)" for every key while values print fine — keys
go through a Swift-bridge path (plutil reads the key as a Swift String) and bridging a machold-
native NSString→Swift String fails (machold isa ≠ Linux Swift NSString metadata). Same Swift-cast
impedance as NSData, RECURSING to strings. Next increment (per "use swift object"): make dict KEYS
real Swift strings — cascades to machold_key_eq/objectForKeyedSubscript (must compare Swift keys
via CFString, dict stays machold-native for values). Array index also prints 0/0 (plutil's index
path). Bounded but cascading; the principle is proven, each Swift-bridged leaf must be Swift-native.

TRIED dict-keys-as-Swift-strings — REVERTED: making parsed keys real Swift NSStrings fixes
plutil's key-bridge but REGRESSES F3_serial (machold-native consumers message the keys via ObjC
expecting machold strings). CONCLUSION: an object that BOTH crosses a Swift cast AND is ObjC-
messaged by another consumer can't be one type — the recursive impedance is genuinely hard. It
worked for NSData (a leaf that only crosses the cast; machold reads it via CFDataGetBytePtr, never
messages it) but NOT for strings shared between a Swift-bridging tool and ObjC consumers. KEPT the
reusable robustness: machold's isa-walkers (opc_opt_class/isKindOfClass:/swift_dynamicCastObjCClass)
now gate on machold_is_machold_class so a foreign Swift/CF object no longer crashes them; foreign
dispatch gained CFString compare/UTF8String.

Next phases: plutil is a deep tool-specific tail (its Swift key-bridge + -p C-string formatter);
the NSData "use swift object" pattern is the durable win for cast-crossing LEAVES. Better ROI:
apply it to a tool whose Swift objects aren't also machold-messaged. Trace defaults' output call;
cross-frame exception cleanup (deferred).

**GUI remaining ladder**: NSTextView (multiline text routing), NSOutlineView (tree dataSource),
per-view frame layout (frames dropped — host centers+columns), window chrome (title bar),
NSMenu/menu bar, NSViewController/NSWindowController. Same pattern: synthesize the class → emit
an RNode node → the host renders. Harvest with `MACHOLD_OBJC_LENIENT`.
**Noted cosmetic/host gaps** (shared with tier-1): (a) MacosSlider thumb stuck at left —
needs LayoutBuilder (`MacosProgressIndicator.swift:163`); (b) host SF-Symbol icon map missing
many glyphs (star.fill, list.bullet, gearshape → tofu); (c) UTF-16 CFConstantString (a
constant NSString with non-ASCII like "…") — machold reads bytes as a C string and truncates
at the first NUL; ASCII constants are fine.

## TIER 2 opened — a from-scratch objc_msgSend (2026-07-02)

Every tier-1 win above stayed on the `objc_msgSend = 0` side of the boundary (pure
Swift/SwiftUI). This crosses it: a minimal ObjC **messaging** runtime inside machold —
no libobjc, no Darling (its libobjc is a Mach-O dylib welded to its whole userland,
not an ELF drop-in). The heavy lifting was already done: machold's chained-fixup pass
wires `__objc_classlist` / class isa+superclass+cache / `__objc_selrefs`, so messaging
needed only a dispatcher + a method-list walk.
- **`machold_objc_msgSend` / `…Super2`**: naked-asm dispatchers (precedent
  `machold_ds_init_immortal`) — save x0-x8 + q0-q3, call C `machold_lookup_imp(self,SEL)`,
  restore every arg register, tail-`br` to the IMP. nil-receiver → 0.
- **`machold_lookup_imp[_from_class]`**: walk isa→`class_ro`(data&~7)→baseMethods up the
  superclass chain, SEL by `strcmp`. Handles small/relative (modern arm64: `{int32
  name,types,imp}` self-relative; name→selref slot→methname) AND big method_t. Terminates
  on the `class_ro` **RO_ROOT** flag — a root class's superclass is a chained-fixup rebase
  to the mach header (not NULL), so a null check would walk into it and crash.
- C helpers in `resolve_symbol`: `class_createInstance`/`objc_alloc`/`objc_alloc_init`/
  `object_getClass`/`sel_registerName`/`objc_storeStrong`; `objc_retain`→identity,
  `objc_release`→no-op (our objects are malloc'd, not swift heap objects). `MACHOLD_TRACE_OBJC`.
- **Probes**: `O0_minimal.m` pure class-method → "answer==42" (1 dispatch); `O1_hello.m`
  +alloc/-init/-bumpBy: with ivar+int arg → "bumpBy==14" (3). Swift tier regression-clean.

**Ladder rungs 1-3 DONE (2026-07-02):**
- **Variadic-ABI shim** (`MACHOLD_VA_TRAMP`): Darwin arm64 passes C-varargs on the STACK,
  glibc/AAPCS in registers x1-x7/v0-v7 — so `printf(fmt,42)` misprinted. Each shim captures
  the caller sp (=&first vararg) before touching the stack, builds an AAPCS64 va_list with
  both register offsets exhausted (all args from `__stack`), and tail-calls the glibc `v*`
  variant. `printf`/`sprintf`/`snprintf` bound; `fprintf` deferred (Darwin FILE* ≠ glibc).
- **Messageable NSObject** (`O2_nsobject.m`): `machold_init_nsobject` synthesizes an
  NSObject class+metaclass in Darwin layout with real (big) method lists — `+alloc`/`+new`,
  `-init`/`-self`/`-retain`/`-autorelease`/`-release`/`-dealloc`/`-class`. A binary's
  `__objc_classlist` subclass binds its superclass to these; `[[Foo alloc] init]` resolves
  `+alloc` in the metaclass and `-init` via `[super init]`→`objc_msgSendSuper2`→NSObject.
  → "bumpBy=14" (subclass w/ ivar + `[super init]` + int arg).
- **Constant `@"…"` strings** (`O3_nsstring.m`): `machold_init_cfstring` provides
  `__CFConstantStringClassReference` — `{isa, flags, char* str@16, long len@24}` with
  `-length`/`-UTF8String`/`-stringByAppendingString:` (builds a new string, same layout)/
  `-isEqualToString:`, no real CoreFoundation. → `[@"hello" stringByAppendingString:@" objc"]`
  = "hello objc" len 10.

- **NSMutableArray** (`O4_app.m`): hand-written messageable collection rooted at NSObject —
  `{isa, void** items@8, long count@16, long cap@24}`, C-backed (realloc), `-init`/
  `-addObject:`/`-count`/`-objectAtIndex:`(+Subscript)/`-lastObject`. `+alloc` inherited
  from NSObject's metaclass (reads THIS class's instanceSize). Bound as
  `OBJC_CLASS_$_NSMutableArray`/`_NSArray`. **O4 is a full pure-ObjC "app"** (the tier-2
  analog of RealApp): an `NSObject` subclass Task {`NSString* title`, `int done`} in an
  NSMutableArray, iterated + printed → "[ ] Buy milk / [x] Ship objc / … / 1/3 done".

- **NSNumber + NSMutableDictionary** (`O5_dict.m`): a `@42` literal is a static
  `NSConstantIntegerNumber` `{isa, encoding@8, long value@16}` (24 B, from `__objc_intobj`)
  → value accessors read @16. `NSMutableDictionary` `{isa, keys@8, vals@16, count@24,
  cap@32}` with `-setObject:forKey:`(+Subscript)/`-objectForKey:`/`-count`, string-aware
  key comparison (our NSStrings by content, else pointer). → dict of NSString→@N with an
  overwrite → "answer=100 lucky=7 count=2".

**Reusable Foundation-type recipe** (used for NSObject/NSString/NSMutableArray/NSNumber/
NSMutableDictionary): synthesize `machold_class_t` + `class_ro_t` (set instanceSize) + a
big method list of C imps over a fixed instance layout; root at NSObject
(`superclass=&machold_nsobj_cls`, `meta.superclass=&machold_nsobj_meta`, `ro.flags` NOT
RO_ROOT); bind `OBJC_CLASS_$_<Name>` in `resolve_symbol`. NSDictionary/NSNumber/NSString
etc. are all this shape.

- **Class registry + categories** (`O6_category.m`): post-fixup passes over
  `__objc_classlist` (register each class by name → `objc_getClass`/`objc_lookUpClass`/
  `NSClassFromString`) and `__objc_catlist` (merge category method lists into a side-table
  the dispatcher consults BEFORE `class_ro.baseMethods`, so categories override — no
  `class_rw` rebuild). A category on a foreign class (NSObject) + dynamic lookup → "answer=42
  Widget=found NSObject=found". NB: a category compiled in the same TU as its class is
  merged at compile time (no `__objc_catlist`); only foreign-class categories emit one.

- **NSLog** (`O7_nslog.m`): a format walker over the NSString format + Darwin stack-varargs,
  handling `%@` (our NSString → its bytes, else `<Class: ptr>`), `%d`/`%ld`/`%u`/`%x`/`%s`/
  `%c`/`%p`/`%f`, → `NSLog(@"hello %@ n=%d big=%ld str=%s", …)` = "hello objc-world n=42
  big=1000 str=raw". Writes to stderr (no timestamp — the clock is wrong under machold).

- **Foundation breadth** (`O8_breadth.m`; harvested via `MACHOLD_OBJC_LENIENT` = log-missing-
  selector + return nil so one run lists the whole work-list): NSString hasPrefix:/hasSuffix:/
  containsString:/uppercaseString/lowercaseString/substringFromIndex:/
  componentsSeparatedByString:/isEqual:; NSArray firstObject/insertObject:atIndex:/
  removeObjectAtIndex:/removeLastObject/containsObject:/indexOfObject:/
  componentsJoinedByString:; NSNumber runtime boxing (+numberWithInt:/Bool:/Integer:/Long:/
  UnsignedInteger:). Shared `machold_make_string` + `machold_obj_eq` helpers.

- **Variadic methods + NSMutableString** (`O9_format.m`): the shared format walker is now
  `machold_format_stream(FILE*, …)` (+ `machold_format_to_string` via `open_memstream`);
  `+[NSString stringWithFormat:]` / `-[NSMutableString appendFormat:]` are naked va-capture
  IMPs (varargs on the Darwin stack, like NSLog) that format into an NSString.
  `+stringWithUTF8String:`/`+string`, and NSMutableString (`+string`/`-init`/`-appendString:`/
  `-setString:`/`-appendFormat:`, growable buffer). This closes the last *non-mechanical*
  breadth item (variadic method dispatch).

- **@[] literals + for-in + NSMutableSet/NSData** (`O10_data.m`): fast enumeration
  (`machold_fastenum` fills the NSFastEnumerationState with internal storage in one batch;
  `objc_enumerationMutation` no-op) on NSMutableArray/NSConstantArray/NSMutableSet; the `@[…]`
  literal is a static `NSConstantArray {isa, count@8, id* objects@16}`; NSMutableSet (dedup,
  reuses the array layout); NSData `{isa, bytes@8, len@16}` (+`-[NSString dataUsingEncoding:]`);
  NSString `-intValue`/`-doubleValue`.

- **Blocks** (`O11_blocks.m`): the block ABI — `{isa, flags, reserved, invoke@16,
  descriptor, captures}`; invoking = `block->invoke(block, args)`. Minimal runtime:
  `_NSConcrete{Stack,Global,Malloc}Block` dummy isa, `_Block_copy`/identity,
  `_Block_object_assign/dispose`/no-op (synchronous-only; `__block` byrefs stay on stack),
  `__objc_personality_v0` dummy. `enumerateObjectsUsingBlock:` calls the block per element
  with `*stop` honored → the last common ObjC mechanism. Now `sortUsingComparator:`/
  completion-handler-style APIs are reachable via the same `invoke` call.

- **sortUsingComparator: / dict block-enum / mutableCopy / NSDate** (`O12_sort.m`):
  `-[NSMutableArray sortUsingComparator:]` (qsort_r + comparator block), `mutableCopy`,
  `-[NSMutableDictionary enumerateKeysAndObjectsUsingBlock:]` / `+dictionary`, `NSDate`
  (`+date`/`-timeIntervalSince1970`, real epoch via gettimeofday).

**Tier-2 remaining ladder**: (5b) pure-mechanical breadth as probes demand — `NSValue`,
`NSError`, `NSURL`, KVC accessors, `NSString`/`NSArray` odds and ends (harvest with
`MACHOLD_OBJC_LENIENT`). (7) real Foundation/CoreFoundation (archiving, full KVC, toll-free
bridging) — the large deferred fusion. The console-level ObjC runtime (messaging core, I/O,
all 3 collections + literals + fast/block enumeration + sorting, strings/formatting/parsing,
numbers, data, dates) now runs substantial pure-ObjC programs; the only NEW mechanism left is
the strategic pivot (AppKit→Flutter render bridge). 13 probes O0–O12, all exit 0.
**The strategic pivot** remains: an **ObjC/AppKit app that RENDERS through the Flutter host**
(an `NSApplication`/`NSWindow`/`NSView`→RNode bridge, the tier-2 analog of the SwiftUI render
path) — the next big milestone, where the ObjC tier meets the Flutter GUI, vs. continued
Foundation breadth. The ObjC runtime + Foundation console surface is now broad enough to run
a substantial pure-ObjC program (dispatch/super/categories/registry/collections/strings/
formatting/logging); everything left in breadth is drop-in, everything new is the GUI bridge.
NB: a tier-1 SwiftUI app becomes tier-2 the moment it calls a *messaging* Foundation API
(UserDefaults/NSString bridging); the two tiers coexist in machold (Swift-interop classes
go through `swift_getSingletonMetadata` realization, never `__objc_classlist`; ObjC classes
stay Darwin-layout and get messaged).

## Milestone — RealApp (2026-07-02)

`probe/RealApp{,.swift}`: a composite multi-screen interactive todo app written like a
real app (an `ObservableObject` store via `.environmentObject`, `TabView` with `Label`
tab items, `ForEach` rows with `.onTapGesture` toggles + conditional `.foregroundStyle`,
`.buttonStyle(.borderedProminent)`, `ProgressView`, `.sheet`, `Form`/`Section`,
`@AppStorage` + `Stepper`, `@Environment(\.colorScheme)`, `Toggle`), built UNMODIFIED
with Apple's toolchain (224 imports, `objc_msgSend` = 0). **Binds 224/224 and renders
both screens correctly on the first run**; autotap switches tabs live. The three
discovery sweeps covered the entire composite surface — the harvest produced ZERO new
unresolved symbols. Known cosmetic: tab-item SF Symbol names (`list.bullet`,
`gearshape`) missing from the host glyph map.

## Done

| Feature | Probe | Types added |
|---|---|---|
| `.frame(maxWidth:…)` fill/flex | `D_flexframe` | `_FlexFrameLayout` (112 B, matches Apple) → `.frame` node |
| `if / else` in a body | `D_cond` | `_ConditionalContent<T,F>` + `Storage` enum + constrained `init(storage:)` |
| `if` / `if let` (no else) | `D_iflet` | `Optional: View` conformance + `_makeView` |
| `.background(Color)` / `.background(gradient)` | `D_background` / `D_bggradient` | `ShapeStyle` + `Color: ShapeStyle` + `_BackgroundStyleModifier` (9/16, matches Apple). Background carries a full `RenderNode` (any `ShapeStyle` that's also a `View` renders via its own `_makeView`); host paints it as a `DecoratedBox` decoration (color or gradient) behind the child, sized to the child. 38/38 symbols for the gradient form. |
| `.overlay(View)` / `.overlay(gradient)` | `D_overlay` / `D_ovgradient` | `_OverlayModifier<Overlay>` (View form → `Stack[content, overlay]`, centered) + `_OverlayStyleModifier<Style>` (ShapeStyle form, 9 B = same layout as `_BackgroundStyleModifier`; chosen for `.overlay(Color/gradient)` even though those are also Views). Style overlay → foreground `DecoratedBox` (paints over, fills the child's bounds). 38/38 for the gradient form. |
| `LinearGradient` / `RadialGradient` / `AngularGradient` | `D_gradient` / `D_radial` / `D_angular` | `UnitPoint` (16 B), `Gradient` (8 B) + `Stop` (16 B), `Angle` (8 B), and all three gradients (40 B each) — `@frozen`, layout-matched to Apple. `colors:` inits inline → `Gradient(colors:)` + the primary `init(gradient:…)`. 29/28/29 symbols. The shared host `boxDecoration(for:)` maps each to `Flutter.LinearGradient`/`RadialGradient`/`SweepGradient`, so all three work bare (filled), as `.background`, and as `.overlay`. (Radial start/endRadius are absolute points; mapped to Flutter's default fractional radius 0.5 — exact mapping needs the box size.) |
| `.background(style, in: shape)` / `.overlay(style, in: shape)` | `D_bgshape` / `D_ovshape` | `_InsettableBackgroundShapeModifier<Style: ShapeStyle, S: InsettableShape>` (background's insettable overload) + `_OverlayShapeModifier<Style: ShapeStyle, S: Shape>` — both 27 B `{style, shape, fillStyle}`, inits inlined, constraints witness-table-matched to Apple. A `.shaped` paint node carries the shape's kind+radius; host `boxDecoration(for:)` adds `borderRadius`/`shape: .circle`. 36/42 symbols. |
| Shapes: `RoundedRectangle`/`Rectangle`/`Circle`/`Capsule`/`Ellipse` + `.clipShape`/`.cornerRadius` | `D_shapes` | `Shape`/`InsettableShape` protocols; each shape `@frozen` at Apple's size (empties = 0 B, `Capsule` = 1 B) + an `_AnyShapeDescriptor` (kind + radius). `.clipShape(anyShape)`/`.cornerRadius` unified via an `_AnyClipEffect` erasure → a `.clip(kind, radius, child)` node → host `ClipRRect`/`ClipOval`/`ClipRect`. 45/45 symbols; Gallery's `.cornerRadius` regression-clean. |
| `LazyVStack`/`LazyHStack` / `List` | `D_lazy` / `D_list` | `PinnedScrollableViews: OptionSet` (4 B) — the only layout-critical type (passed by value); the Lazy*Stack/`List` inits are real (imported) calls, so those layouts are ours. Lazy stacks render as VStack/HStack; `List<SelectionValue: Hashable, Content>` (`== Never` init) → a `.list` node (host: ScrollView + inset rows + hairline separators). `_makeViewList`/`_viewListCount` satisfied by our View defaults. 41/27 symbols. |
| `TabView` + `.tabItem` | `D_tab` | `TabView<SelectionValue: Hashable, Content>` (the `== Int` default-selection init, a real call → layout ours). `.tabItem { label }` returns `some View` whose underlying type is our `_TabItemView` (carries page + label); `TabView._makeView` flattens content and pulls page+label per tab via `_AnyTabItem` → a `.tabview(labels, pages)` node. Host: centered tab bar (active tab highlighted) + selected page. 31/31 symbols. **Tap-to-switch works** (host-side, like navStack): tab items are `GestureDetector`s; tapping tab `i` sets `selectedTab` and re-renders (re-applies the current root, which already carries every page) — verified by `MACHOLD_AUTOTAP` L2 frames (default → "A"/page "a"; after tap → "B"/page "b"). |
| `GeometryReader` + `GeometryProxy.size` | `D_geo` | The first **bidirectional** feature: the body reads the laid-out size, unknown at walk time. `GeometryReader<Content>` (`@frozen`, holds the closure — init inlined → 16 B). `_makeView` registers the closure by id (like button actions) + emits a `.geometryReader(id)` placeholder; the host calls back `swiftui_compat_geometry(id, w, h)` at build time → the closure runs with a `GeometryProxy(size:)` → its subtree renders. Two Linux mangling fixes: `CGFloat: _FormatSpecifiable` (for `\(geo.size.width)`) + a machold `So6CGSizeV`→`10Foundation6CGSizeV` rewrite (the `__C.CGSize` getter). **Limitation:** the size is the window's content area (correct for a root/full-bleed GR); per-region size needs a real `LayoutBuilder` (not in this Flutter port — a follow-up). |
| `NavigationStack` + `NavigationLink` + `NavigationPath` | `D_nav` | Stateful push/pop. Both inits are real (imported) calls → layouts ours, BUT the declaration FORM is mangling-critical: `NavigationStack.init(root:)` is a **struct-body init with `where Data == NavigationPath`** (trailing `…AFRszrlufC`), while `NavigationLink.init(_:destination:)` is in an **extension `where Label == Text`** (`…E…`) — mismatch the form and the symbol won't bind. `NavigationLink`'s destination is **eager** (the value, not a closure — the modern `@ViewBuilder` form inlines to it), so the navLink node embeds the rendered destination and the host does push/pop **entirely host-side** (a `navStack` of pushed RNodes; link tap pushes, back bar pops, re-render via the tap mailbox) — no SwiftUI round-trip. 31/31 symbols. Verified interactively (autotap push → back bar + destination). |
| `ObservableObject` / `@StateObject` / `@ObservedObject` / `@Published` (render path) | `D_observable` / `D_obs_rich` | The binary's `class M: ObservableObject` is an **ObjC-interop Swift class** realized on Linux with **no ObjC runtime** (msgSend=0). Type layer (`Combine` + StateObject/ObservedObject) was banked earlier; this completes the machold **class-realization** loader work (all in `linux/loader/machold.c`). Three pieces, each pinned by disassembling the binary: (1) **ObjC ivar-offset globals** — `M.init` reads each `@Published` field's offset from a per-field "direct field offset" (`Wvd`) bss global, not the metadata field-offset vector. Our `updateClassMetadata2` now walks `metadata.data → class_ro_t(@+48 ivars) → ivar_list → ivar.offset` and writes each (the real runtime's job); without it `_c` was written over the instance's isa, zeroing it. (2) **Header-only Darwin→Linux metadata conversion** — relocate ONLY the fixed header `[flags@40 .. ivarDestroyer@72)` down into the 24-B ObjC `{cache,data}` gap so the Linux runtime reads description/instanceSize correctly, but LEAVE the trailing area (field-offset vector @0x50, vtable @0x58) where Apple put it — the binary hardcodes those Darwin offsets (`M.init` field read, `m.c` vtable dispatch) and the descriptor's own FVO/VTableOffset already match, so no FVO patch. (3) **Clear the descriptor's singleton-init flag** post-realization so keypath construction (`M.c.getter` builds `\M.c`/`\M._c` → `swift_checkMetadataState`) takes the statically-complete fast path instead of our bypassed (NULL) singleton-cache state machine. Generalizes to N fields (D_obs_rich: 5 `@Published`, 5 ivar-offsets). Verified: D_observable renders `Text("\(m.c)")` = **"0"** end-to-end through the Flutter engine (L2 frame). Diagnostics: `MACHOLD_TRACE_META=1`. Gallery/D_nav/D_shapes/D_geo regression-clean. |
| `ObservableObject` reactivity (Combine surface + `@StateObject` persistence) | `D_obs_combine` / `D_obs_react` | Two parts. **(a) Combine surface** (D_obs_combine: FATAL→RENDERS): reconstructed `Combine.Cancellable`/`AnyCancellable` (final class, `Hashable` for `Set<AnyCancellable>`) + `AnyCancellable.store(in: inout Set)` + `Publisher.sink(receiveValue:) where Failure == Never`, and SwiftUI's `_AppearanceActionModifier` (@frozen `{appear, disappear}` 32 B, `ViewModifier`) for `.onAppear` (inlined → `ModifiedContent<Content, _AppearanceActionModifier>`; MakeView renders the wrapped content). All plain type reconstruction (no loader change). **(b) Live re-render** (D_obs_react — a `Button { m.c += 1 }`): `@StateObject` now **persists** its object across re-walks via a global cache keyed by the stored thunk closure's **function pointer** (stable per declaration; the context word churns per CV copy, so it's excluded). A button tap → host dispatch runs the action → mutates the persisted `M` → re-walk reads it → counter ticks **0→1→2→3→4** (verified via `MACHOLD_TAP=N`; L2 frame shows Text + blue "inc" button). `$m` bindings route through the same persisted object. |
| `ObservableObject` push-based re-render (non-interactive mutations + `.onAppear`) | `D_obs_appear` | A `@Published` mutation that does NOT happen inside a button action now triggers a re-walk. **Cross-dylib hook:** the `@Published` setter (and `ObservableObjectPublisher.send()`) in libCombine calls `swiftui_compat_invalidate` — a `@_silgen_name` undefined symbol resolved at load from libSwiftUI (like `swiftui_compat_run`/`update`; libCombine now links `--unresolved-symbols=ignore-all`). **Deferred + coalesced:** the SwiftUI side sets `_pendingInvalidate` while `_rendering` (inside a walk or a dispatched action) and re-renders once afterward (a capped settle loop), so mid-walk/mid-action mutations don't recurse and the re-render reads the committed value. **`.onAppear` now fires** once per appearance (keyed by closure fn pointer) after its content renders; the resulting mutation is settled. The initial onAppear settle runs BEFORE `swiftui_compat_run` (which blocks in the L2 GLFW loop) so the first frame is already settled; later loop-time mutations flow through the `swiftui_compat_update` mailbox. Verified: `D_obs_appear` (`Text("\(m.c)").onAppear { m.c = 42 }`) renders **"42"** (stub + L2 frame); D_obs_react still ticks 0→1→2→3→4. Regression-clean. |
| `Combine` `.sink` value delivery (subscribe-time) | `D_obs_sink` | `Publisher.sink(receiveValue:)` now actually delivers. Added `Subscriber.receive(_:)` + an internal `_AnySink` forwarding subscriber; `Published.Publisher` carries a snapshot of the value (taken when `$x` is accessed) and `receive(subscriber:)` delivers it — so `store.$c.sink { v in … }` fires once with the current `c` (Combine sends a @Published's current value immediately on subscribe). `sink` returns a no-op `AnyCancellable`. Verified: `D_obs_sink` (`Text(m.label).onAppear { _ = m.$c.sink { v in m.label = "got \(v)" } }`, `c = 7`) renders **"got 7"** (sink delivered → set another `@Published` → re-rendered). Regression-clean (D_obs_combine's sink now fires once, no loop — its `c` is static). **Remaining:** FUTURE-value push (a sink reacting to later `c` mutations) — needs a subject-backed `Published.Publisher` (shared box + subscriber list). Low value: the view already re-renders on every `@Published` mutation via the setter→invalidate hook, so this only matters for `.sink` side-effects that need ongoing values. |

| `VStack`/`HStack` cross-axis alignment | `D_align` | Per-stack alignment is now propagated to Flutter `crossAxisAlignment` (was the "columns use `.start`" cosmetic gap). `VStack`/`HStack` (and Lazy* @ their `.center` default) read `alignment.key` — our `HorizontalAlignment`/`VerticalAlignment` are `{key: Int}` (leading/top=0, center=1, trailing/bottom=2; the binary gets these via our non-inlinable static-let accessors, so the representation is self-consistent even though `VStack.init` is inlined). `_crossAxis` maps key→bucket (0 start / 1 center / 2 end), threaded through `RenderNode.vstack/hstack` → JSON `align` → host `CrossAxisAlignment`. Never `.stretch` (that tight-forces children to an unbounded width → the old `isFinite` SIGTRAP); start/center/end keep intrinsic children finite. Verified: `D_align` (leading/center/trailing VStacks) — L2 frame shows the short label left/center/right within each block; outer default VStack centers (Apple's default). **`ForEach`/`Group` inherit too** (`D_alignfe`): `_stackChildren` flattens them into the parent stack's direct children, so `VStack(.trailing){ ForEach… }` right-aligns every row (L2-verified). The only non-inheriting case is a ForEach/Group used as the *root* view (no enclosing stack), which falls back to `.start`. Regression-clean. |
| `.overlay(view, alignment:)` alignment | `D_ovalign` | `.overlay(view)`'s `alignment:` arg is now honored (was always centered). `_OverlayModifier` already carried `alignment: Alignment` (`{horizontal, vertical}`, both `{key:Int}`); exposed it via `_AnyOverlayModifier._overlayAlign` packed as `h*3+v` (h/v each 0 leading/top, 1 center, 2 trailing/bottom; default 4 = center, also used by the style/shape overlays which fill). Threaded `RenderNode.overlay(_,_,Int)` → JSON `align` → host `Alignment(x,y)` on the `Stack` (content fills → its own alignment is a no-op; the smaller overlay positions per `align`). Verified: `D_ovalign` — L2 frame shows "TL" at a box's top-left (topLeading=0) and "BR" at another's bottom-right (bottomTrailing=8). Regression-clean. |
| `Label(_:systemImage:)` | `D_label` | `Label<Title, Icon>: View` (resilient → binary calls our init + `_makeView`; 3 imports: the `where Title == Text, Icon == Image` extension `init(_:systemImage:)`, the nominal descriptor, the View conformance). Renders as an `HStack[icon, title]` (gap 6, centered). Verified: `D_label` (`Label("Home", systemImage: "house")`) → L2 frame shows the icon glyph + "Home". Regression-clean. (First feature from the 2026-06-21 discovery sweep — see below.) |
| `ProgressView(value:total:)` | `D_progress` | Determinate progress bar. `ProgressView<Label, CurrentValueLabel>: View` (resilient). **Mangling gotcha:** Apple's interface shows `init(value:total:)` in `extension where CurrentValueLabel == EmptyView` with `where Label == EmptyView` on the init, but the binary's symbol carries BOTH same-type constraints on the init with NO extension-context infix (`…V5value5total…AGRszAGRs_SBRd__lufC`) — so declare it in an **unconstrained** `extension ProgressView` with `where Label == EmptyView, CurrentValueLabel == EmptyView` on the init (the constrained-extension form bakes a `…E…` infix and won't bind). `_makeView` emits a `.progress(fraction)` node (value/total); host draws a gray track + blue fill (or just the track for indeterminate `nil`). Verified: `D_progress` (`ProgressView(value: 0.4)`) → L2 frame shows a bar ~40% filled. Regression-clean. |
| `Stepper(_:value:step:)` | `D_stepper` | Interactive − / + control. `Stepper<Label>: View` (resilient); the `where Label == Text` init `init<V: Strideable>(_:value:step:onEditingChanged:)` builds inc/dec closures from the `Binding` (`value.wrappedValue.advanced(by: ±step)`). `_makeView` ships the two closures in a `.stepper` node; FlutterBridge registers them as tap actions (like Button); host renders `label − +`. Tapping mutates the binding → @State → re-render. Verified: `D_stepper` (`Stepper("Count: \(n)", value: $n)`) → renders "Count: 0" + − / + buttons (L2 frame); two − taps → "Count: -1", "Count: -2". Regression-clean. |
| `LazyVGrid` (+ `GridItem`) | `D_grid` | Reconstructed `GridItem` (+ nested `Size` enum: `fixed`/`flexible(min:max:)`/`adaptive`, defaults matched) and `LazyVGrid<Content>: View` (both resilient). Only the column COUNT (`columns.count`) drives layout: `_makeView` flattens content into a `.grid(cols, items)` node; host chunks items into rows of `cols` (each an HStack) stacked in a Column. Verified: `D_grid` (`LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) { Text("a"); Text("b"); Text("c") }`) → L2 frame shows "a b" / "c" (2 columns). Per-item sizing/spacing accepted but not yet honored (uniform grid). Regression-clean. |
| `.onTapGesture` / `.navigationTitle` / `.onChange(of:initial:_:)` / `.sheet(isPresented:…)` | `D_tapgesture` / `D_navtitle` / `D_onchange` / `D_sheet` | Four **resilient View-extension** methods (imported F + FQOMQ pairs — signatures must mangle exactly, underlying types entirely ours; the `.tabItem` pattern). `.onTapGesture` → `_TapGestureView` → a `.tappable` node (host GestureDetector on the Button dispatch path; tap → n 0→1 verified). `.navigationTitle` → `_NavigationTitledView` (title carried; bar display a follow-up). `.onChange` → `_OnChangeView`: compares against the previous walk's value (cache keyed by the action closure's fn pointer), fires `action(old,new)` post-render (deferred-settle); `initial:` fires on first appearance. `.sheet` → binding false ⇒ base only; true ⇒ `.sheet` node = base + full-bleed scrim (tap = dismiss → binding false + `onDismiss`) + centered rounded panel ("SHEET" over dimmed base, frame-verified). |
| `.opacity` / `.scaleEffect` / `.shadow` | `D_opacity` / `D_scale` / `D_shadow` | @frozen effect modifiers the binary constructs INLINE: `_OpacityEffect{opacity}` 8 B, `_ScaleEffect{scale: CGSize, anchor: UnitPoint}` 32 B (the CGFloat overload collapses inline to `CGSize(s,s)+.center`), `_ShadowEffect{color, radius, offset}` 32 B + `Color(RGBColorSpace, white:opacity:)` (resilient enum-case symbols + init; value colors ride the provider name as `rgba:r,g,b,a`). Host: `Opacity`/`Transform`/`BoxShadow`. **HOST LESSON:** `.scaleEffect` anchors at the view's OWN bounds — a bare `Transform` under tight (root) constraints is window-sized, so a centered anchor flings top-left content off-screen; shrink-wrap with `Align(width/heightFactor: 1)` (layout-neutral). "dim" at 50% + "big" at 1.5× frame-verified. |
| `AnyView` | `D_anyview` | @frozen `{storage: class ref}` 8 B; `init<V: View>(_:)` is RESILIENT (the binary calls it — `init(erasing:)` is AEIC and inlines to it), so the box is ours (`_AnyViewBox` holding `any View`); `_makeView` renders the boxed view. 3/3 symbols. |
| `Grid` + `GridRow` | `D_gridrows` | Both @frozen with @inlinable inits — the binary constructs BOTH inline (probe imports only descriptors + View conformances): `Grid{_tree: _VariadicView.Tree<GridLayout, Content>}` with `GridLayout{alignment: Alignment(16), horizontalSpacing: CGFloat?, verticalSpacing: CGFloat?}: _VariadicView_Root` (Tree's constraint), `GridRow{alignment: VerticalAlignment?, content}`. Rendered as a vstack of per-row hstacks via an `_AnyGridRow` erasure ("a b" / "c d" frame-verified). |
| `Menu` | `D_menu` | Resilient (layout free; binary calls the init). MANGLING: the `LocalizedStringKey` init carries `where Label == Text` **on the init** (`…AFRszrlufC`, no extension-context infix) — declare in an unconstrained `extension Menu` with the where-clause on the member (the ProgressView lesson). Host: tap-to-expand dropdown — the label chip toggles an items panel (host state like tab selection); autotap-verified open showing the A/B item buttons. |
| `.disabled` / `.lineLimit` | `D_disabled` / `D_linelimit` | `.disabled` inlines `_EnvironmentKeyTransformModifier` (@frozen `{keyPath@0, transform@8}` 24 B; body `{ $0 = $0 && !disabled }` on `\.isEnabled`) — the `_AnyEnvWriter` erasure gained the transform variant (`transform(&env[keyPath:])`); `EnvironmentValues.isEnabled` resilient accessors (+ auto-emitted property descriptor for the binary's keypath literal); Buttons under `isEnabled == false` register a no-op action. `.lineLimit(n)` inlines `environment(\.lineLimit, n)` → new `EnvironmentValues.lineLimit: Int?` → threaded into the `.text` node → host `Text(maxLines:)`. |
| **Sweep 3 batch 1** — `Text.foregroundStyle`/`.italic()`, `Font.system(size:weight:design:)`, `.alert`, `.toolbar`, `.contextMenu`, `.onSubmit`+`SubmitTriggers`, `SecureField`, `TextEditor`, `GroupBox`, `LazyHGrid`, `@SceneStorage`, `.toggleStyle`/`.textFieldStyle`, `\.tintColor`, `\.multilineTextAlignment`+`TextAlignment` | 16 probes | Resilient/signature-only reconstruction (details in commit 75c9b7477a1). Highlights: alert = the sheet node with title + actions where **every alert button also dismisses** (action composition); `@SceneStorage` is NOT the AppStorage shape — @frozen FIVE fields `{_key: String, _domain: String?, _value: Value, _location: AnyLocation<Value>?, _transformBox: class}` = 56 B for Int (the 8 B guess crashed WindowGroup's outlined copy — measure before assuming sibling wrappers share layouts); `Font.system` rides a `"sys:SIZE:WEIGHT"` provider name; SecureField masks with bullets; italic threads a new Text.Modifier case → host fontStyle. |
| **Sweep 3 batch 2** — `.offset`, `.rotationEffect`, `.blur`, `.fixedSize`, `.ignoresSafeArea`+`SafeAreaRegions`, `.id` (`IDView`), `Shape.fill` (`_ShapeView`), `.onHover`, `.animation`/`withAnimation` (`Animation`+`_AnimationModifier`), `.transition` (`AnyTransition`/`OpacityTransition`/`TransitionTraitKey`) | 10 probes | The @frozen inline-constructed set, layouts from the swiftinterface: `_OffsetEffect{offset: CGSize}` 16 B; `_RotationEffect{angle: Angle, anchor: UnitPoint}` 24 B (host: center-anchored Transform with the Align shrink-wrap); `_BlurEffect{radius, isOpaque}` (host renders content unblurred — ImageFilterLayer doesn't paint in this compositor yet); `_FixedSizeLayout{horizontal, vertical}` 2 B, `_SafeAreaRegionsIgnoringLayout{regions: SafeAreaRegions(UInt), edges: Edge.Set}`, `_HoverRegionModifier{callback}` 16 B, `_AnimationModifier<V>{animation: Animation?, value}` — all pass-throughs (no safe areas/hover routing/animation system; `withAnimation` applies instantly; `Animation` @frozen `{box: class ref}` 8 B with resilient `.default`). `IDView{content, id}` renders content. `Shape.fill` → `_ShapeView{shape, style, fillStyle(2 B)}` → the existing `.shaped` pipeline (red circle frame-verified). `.transition` = 4 resilient decls riding `_TraitWritingModifier`; ignored at render (no animations). |
| `Shape.stroke` / `.border` | `D_stroke` / `D_border` | The outline family. `StrokeStyle` @frozen `{lineWidth @0, lineCap @8 (4 B __C struct), lineJoin @12, miterLimit @16, dash @24, dashPhase @32}` = 40 B with a RESILIENT init whose mangling embeds `So9CGLineCapV`/`So10CGLineJoinV` — **reproduced on Linux by a local C module** (`CGCompatShims`: plain C `typedef enum`s import as `__C` RawRepresentable structs, exactly Darwin's kind-V import; wired into build.sh via `-fmodule-map-file`). **NEW machold LESSON — substitution shift:** the textual `12CoreGraphics7CGFloatV`→`10Foundation7CGFloatV` rewrite changes the symbol's WORD LIST, so later word-substitution indices shift (`So0pH0V`→`So0oH0V`) and byte-exact dlsym misses — StrokeStyle.init needed an exact-symbol map (future CoreGraphics-param symbols with trailing substitutions too). Types: `_StrokedShape{shape, style}` (@frozen, inlined), `Rectangle._Inset{amount}`, `_BackgroundModifier{background, alignment}`, `ShapeView` protocol + `StrokeShapeView` (@frozen, ONE stored field = the full `ModifiedContent<_ShapeView<_StrokedShape<C>, S>, _BackgroundModifier<B>>` nest the binary constructs INLINE via AEIC). Render: a `.stroked` node → border-only `BoxDecoration` (`Border.all`). Red 3 px circle outline + bordered text frame-verified. |
| `@FocusState` + `.focused` | `D_focusstate` | @frozen `{value: Value @0, location: AnyLocation<Value>?, resetValue: Value}` (17/24 for Bool — measured AND interface-confirmed; the SceneStorage lesson applied). ALL members resilient (fields are plain internal — nothing inlines), so semantics are ours: no focus engine — reads yield the initial value, programmatic focus writes are dropped; nested `Binding{_binding: Binding<Value>}` wraps our Binding. `.focused` → `_FocusedView` pass-through. |
| `DragGesture` + `.gesture` + `.onChanged` | `D_draggesture` | The gesture types are all RESILIENT (layouts ours): `Gesture` protocol, `DragGesture{minimumDistance, coordinateSpace}` + `Value{time, location, startLocation}` (+ computed translation), `GestureMask` (@frozen OptionSet UInt32, resilient statics), `CoordinateSpace(Protocol)`/`LocalCoordinateSpace.local`, `_ChangedGesture{base, action}` + `Gesture.onChanged`. The engine gesture graph (`_makeGesture`/`_GestureInputs`) is NOT reconstructed — the walk recognizes the concrete `_ChangedGesture<DragGesture>` shape and emits a `.draggable(id)` node; the host's `GestureDetector(onPanStart/onPanUpdate)` routes pan events through new `swiftui_compat_drag(id, x, y, sx, sy)` → a synthesized `DragGesture.Value` → the app's closure → re-render. (Live-drag untested headlessly — needs a real pointer; the plumbing mirrors the proven tap path.) |
| `@Environment(\.…)` | `D_envread` | The 18-symbol flagship, mostly machold binds. `Environment<Value>` @frozen with ONE stored field `content`, a @frozen 2-case enum `{keyPath(KeyPath<EnvironmentValues, Value>) \| value(Value)}` (case order is tag-ABI). Apple's `init(_:)` AND `wrappedValue` are @inlinable — the binary stores `.keyPath(kp)` inline and switches inline — so the injection pass (the `_AnyEnvironmentInjectable` machinery) rewrites `.keyPath(kp)` → `.value(env[keyPath: kp])` before `body`: the inlined getter takes `.value` and the "not installed on a View" **os_log fallback branch is dead code** (5 machold no-op binds; `os_log_type_enabled` → false short-circuits any live path). `ColorScheme` is a RESILIENT enum (case + synthesized-== symbols export like `Color.RGBColorSpace`); `EnvironmentValues.colorScheme` defaults `.dark` (the host's appearance). machold also gained: `objc_retain/release` + `swift_unknownObjectRetain/Release` → native `swift_retain/release` (msgSend=0 doctrine), and `_swiftImmortalRefCount` = `(void*)0x80000004FFFFFFFF` — the Darwin ABSOLUTE symbol whose "address" IS the immortal `InlineRefCounts` pattern, bound into statically-emitted objects' refcount words (`dyld_info -exports` ground truth; RefCount.h is interop-independent). Verified: `D_envread` renders "dark". |
| `@AppStorage` | `D_appstorage` | @frozen `{location: UserDefaultLocation<Value>` (class)} = 8 B; wrappedValue (get/nonmutating set)/projectedValue/inits all RESILIENT, `where Value == Int/String/Bool/Double` ON the inits (the Menu pattern). The `store:` param's Darwin `So14NSUserDefaultsC` mangling rides a machold `rewrites[]` entry → `10Foundation12UserDefaultsC` (the NSBundle precedent). Backing store: an in-process dictionary (cross-launch persistence out of scope); sets invalidate like `@Published`. Renders "v=7". |
| `Form` + `Section` | `D_form` | Form: resilient container → a List of flattened sections. `Section<Parent, Content, Footer>`: unconstrained struct + CONDITIONAL View conformance (`where` all three `: View`) + the Text-header init in a **constrained extension** (`…rlE…` — this one IS extension-mangled, the opposite of Menu's where-on-init; both verified against the binary's imports). Headers render as bold secondary sub-headline rows. |
| `.buttonStyle(.borderedProminent)` | `D_buttonstyle` | Minimal `PrimitiveButtonStyle` protocol (the binary imports only the CONFORMANCE descriptor — self-consistent, no witness dispatched) + resilient `BorderedProminentButtonStyle()` (`.borderedProminent` is AEIC → inlines to the init) + resilient `buttonStyle<S>(_:)` → `_ButtonStyledView` carrying the style TYPE NAME down the environment; `Button` nodes gained a `style` field; host renders borderedProminent as a filled accent chip. |
| `.task {}` | `D_task` | `_TaskModifier` @frozen `{action: @Sendable () async -> Void @0 (16), priority @16 (1)}` = 17/24; the SDK's AEIC `task(...)` gates on `#available(26.4)` → the FALSE availability convention selects the `_TaskModifier` fallback, constructed inline against our layout. MakeView fires the action once per appearance (the `.onAppear` fn-pointer keying): `Task { await action() }` — **the binary's Darwin-compiled async closure runs on Linux's concurrency runtime** ("wait"→"done" frame-verified). Surfaced two cross-cutting fixes: `State.wrappedValue`'s RESILIENT setter now invalidates (out-of-band @State writes — .task/timers — used to be silent, masked by dispatch's post-action re-render), and the host's pendingNode mailbox only pops after the root mounts (a fast early update used to be consumed and dropped). |
| `@EnvironmentObject` + `.environmentObject(_:)` | `D_envobj` / `D_envobj_btn` | First **DynamicProperty-injection** feature. The binary inlines `wrappedValue` (`guard let store = _store else { error() }`) — nothing populates `_store` by symbol call; the environment system must write the per-instance field before `body` runs. Three pieces: (1) `EnvironmentObject` `@frozen {_store: ObjectType? @0, _seed: Int @8}` (16 B, matches Apple's swiftinterface) + resilient `init()`/`error()`/`projectedValue`+`Wrapper` — the probe's 4 type imports; the binary CALLS our `init()`, so the initial nil is ours. (2) `ObservableObject.environmentStore` (the 5th import): a static `WritableKeyPath<EnvironmentValues, Self?>` in an **unconstrained SwiftUI-module extension on Combine's protocol** (mangles `$s7Combine…P7SwiftUIE…`); resilient, so the keypath shape is ours — a subscript keyed by an empty per-type `_EnvironmentObjectKey<T>` into new `EnvironmentValues._objects` storage. The inlined `.environmentObject(m)` = `environment(T.environmentStore, m)` → `_EnvironmentKeyWritingModifier<Model?>`; MakeView's env-write case is now GENERAL via an `_AnyEnvWriter` erasure (`env[keyPath:] = value` onto a copy of the inherited environment; `.foregroundColor` unified through the same path), and `_ViewInputs` threads `env: EnvironmentValues` everywhere (GeometryReader closures capture it). (3) The injection pass: the default `View._makeView` — the single funnel every user `body` goes through — runs `_injectEnvironmentObjects(&v, inputs.env)`: `@_spi(Reflection) _forEachField` enumerates (offset, type), an `_AnyEnvironmentObject` erasure writes `_store` through a raw pointer (reflection can't mutate, and the inlined getter reads the raw field). Re-runs per walk; a missing object leaves nil → the inlined guard calls our `error()` (Apple's diagnostic text). Verified: `D_envobj` renders "0"; `D_envobj_btn` (`Button { m.c += 1 }` mutating the env object) autotap → "n=0"→"n=1" (mutation through the injected instance → `@Published` invalidate → re-walk re-injects). Regression: every deterministic probe's frame **byte-identical** to its pre-change baseline. |
| `Picker` + `.tag` (interactive) | `D_picker` | The "opaque-type wall" is down — and it was never libswiftCore. `.tag`'s opaque descriptor carries **kind-9 (accessor-function) symbolic refs**: the runtime demangler CALLS two in-app accessors, each gating the underlying type on `#available(macOS 26)` — modern `_TagTraitWritingModifier<V>` vs legacy `_TraitWritingModifier<TagValueTraitKey<V?>>`. That check is **clang compiler-rt `os_version_check.c`, statically linked into every macOS binary**: its weak import `__availability_version_check` binds NULL under machold, so it falls back to parsing `SystemVersion.plist` via `dlsym(RTLD_DEFAULT, kCFAllocatorNull/CF*)` — with **Darwin's** `RTLD_DEFAULT = -2`, which glibc dereferences as a `link_map*` → the pinned SIGSEGV. Fixes: (1) machold interposes the app's `dlsym` import (`machold_dlsym`: Darwin pseudo-handles −1/−2/−3/−5 → Linux `RTLD_DEFAULT`; trace with `MACHOLD_TRACE_DLSYM=1`) — the CF lookups then resolve harmlessly against corelibs `libFoundation.so`, the plist `fopen` fails, version stays 0.0.0. (2) **Availability convention: FALSE everywhere** — flipped `machold_os_version_atleast` 1→0 so all three `#available` mechanisms agree (stdlib variant stub, Linux libswiftCore's own `false`, compiler-rt's 0.0.0). Coherence is load-bearing: the inlined body picks the tag's VALUE representation via the stdlib entry while the kind-9 accessors pick the TYPE metadata via compiler-rt — the old `return 1` made them diverge (modern value, legacy metadata = silent layout corruption). (3) MakeView extracts tags from the legacy form too (`_TraitWritingModifier: _AnyTagProvider` via `TagValueTraitKey.Value`, unwrapping the `Optional<V>` lowering of `.tag(x)`). Verified: renders `Pick [One] Two`; `MACHOLD_AUTOTAP` taps option 2 → its tag writes back through the `Binding` → re-render shows `Two` selected (L2 frames). Regression-clean (39/39 probes). |

## Pending — ordered by value ÷ cost

### Newly discovered — sweep 2026-06-21 (probe → machold `UNRESOLVED` work-list)
**Fully drained** (2026-07-02): Label, ProgressView, Stepper, LazyVGrid, Picker (the opaque-type
wall was compiler-rt's availability init calling `dlsym` with Darwin's `RTLD_DEFAULT`(−2)), and
`@EnvironmentObject` (the DynamicProperty-injection task) are all in the Done table.

### Newly discovered — sweep 2026-07-02 (17 probes)
**Fully drained** (same day + next session): all 17 features are in the Done table.

### Newly discovered — sweep 3, 2026-07-02 (30 probes)
**Fully drained — 30/30 render**, including the assessed walls (stroke/border via the
CGCompatShims C module + a machold exact-symbol map; @FocusState; DragGesture with live
pan plumbing). The discovery method has emptied three times. What remains is not more
type reconstruction:
- **Run a real-world macOS binary** and harvest its FATAL list — the project's actual
  milestone test, and the source of the next work-list.
- **Core-Flutter `LayoutBuilder`** → true per-region `GeometryReader` geometry +
  `RadialGradient` fractional radii.
- Engine-graph subsystems when needed: the gesture graph (`_makeGesture`/`_GestureInputs`
  — today only `_ChangedGesture<DragGesture>` is pattern-matched), the animation system
  (everything snaps), a focus engine.

### Cheap, ubiquitous
- **`RadialGradient` point-radii → fractional** (needs box size). Minor polish item.
- **True `GeometryReader` geometry** — needs a real `LayoutBuilder` (build-during-layout). NOT a quick
  add: the base `RenderObject` has no generic `invokeLayoutCallback` (only per-sliver impls), so this
  means a new `RenderConstrainedLayoutBuilder` + element in the **core Flutter framework** (broad blast
  radius). Both this and the RadialGradient radii are blocked on it. Bigger investment — defer until needed.

### High cost
- **ObservableObject is essentially complete** (class realization, `@Published` render, `@StateObject`
  persistence, button + push-based re-render, `.onAppear`, `.sink` subscribe-time delivery — all in
  the Done table). The only loose end is **`.sink` FUTURE-value push** (a sink reacting to *later*
  `@Published` mutations), which needs a subject-backed `Published.Publisher` (shared box + subscriber
  list). Low value — the view already re-renders on every mutation via the setter→invalidate hook, so
  this only matters for `.sink` side-effects that consume ongoing values; deferred until a real app
  needs it.

## Known cosmetic gaps (render, but slightly wrong — not crashes)
- `Date()` reads a wrong clock under machold (shows year 2000).

## Out of scope for the simple probes (would need the above first)
`if/else` and `if let` are now in; `.frame(maxWidth:)` is in. Everything else above still walls.
