// Bridge the macOS-Foundation symbols the binary imports to the Linux toolchain's
// (swift-foundation) equivalents, where the API/ABI diverged: method *signatures*
// (JSONDecoder.decode gained a `configuration:` on Linux), protocol *renames*
// (Foundation.ContiguousBytes → Swift._HasContiguousBytes), and the FormatStyle
// *module split* (the type is in FoundationEssentials but `.abbreviated`/`.shortened`
// are extension members in FoundationInternationalization — a dual-module mangling no
// single rewrite can produce). @_silgen_name forces each shim under the exact macOS
// symbol the binary imports; extension-method shims keep `self` in the swiftself
// register to match the original method ABI. The loader tries the as-is name first,
// so these shims take precedence over the module-rewrite fallbacks.

import Foundation

// JSONDecoder.decode(_:from:) — a thin forward. The 2026-06-08 deep dive (see
// FOUNDATION-WORKLIST.md) PROVED there is NO Data layout/content skew: the binary's
// `Data(s.utf8)` is bit-identical to native Linux's (word0={start,end}u32, word1=storage
// |tag<<48, tag 0x4000, valid heap _bytes, _length=122, correct JSON bytes; storage alive
// w/ refcount 1 at decode entry). The Linux decoder works on it — so this shim just
// receives a real `Data` (the matching Linux Data ABI reinterprets the binary's 16 bytes)
// and forwards to the Linux decoder, whose only API divergence is an added defaulted
// `configuration:` (different mangling → the Darwin symbol is absent on Linux).
//
// The probe still does NOT render: the wall is NOT here. It's the BINARY's Apple-compiled
// ARC of its own `json` Data — releasing it at load()'s scope exit crashes in
// _swift_release_dealloc (an @inlinable-version-skew in the inlined retain/release, not
// layout). That's independent of this shim (reproduces with an empty shim). See worklist.
extension JSONDecoder {
    @_silgen_name("$s10Foundation11JSONDecoderC6decode_4fromxxm_AA4DataVtKSeRzlFTj")
    public func _compatDecode<A: Decodable>(_ type: A.Type, from data: Data) throws -> A {
        // Thin forward. The 2026-06-08 (cont.) deep dive (FOUNDATION-WORKLIST.md) proved a
        // boundary copy here is NOT the fix and there is nothing to repair in this shim:
        //   • The binary's `Data` arrives bit-IDENTICAL to a native Linux `Data` of the same
        //     bytes (word0=0x7a00000000, word1=0x4000|storage, tag=1 .slice, 122 B; verified
        //     by building the identical Data natively). Storage is Linux-built and healthy.
        //   • A FRESH Linux Data of the same JSON decodes fine IN-PROCESS here → decoder + heap
        //     are healthy. Only routing the BINARY's Data through decode corrupts, and the
        //     crash site is non-deterministic (withBufferView base=0 / scanString [Int] append
        //     / InlineData demangle) — heap corruption whose SOURCE is the binary's surrounding
        //     Apple-inlined Foundation code, not the Data value/representation/storage.
        // So no value-marshal at this API boundary helps; the fix is real Foundation (path 2)
        // or an -Onone rebuild (path 3). Kept as a pass-through so the symbol still binds.
        return try decode(type, from: data)
    }
}

// ContiguousBytes.withUnsafeBytes protocol-requirement dispatch thunk (…FTj): handled by
// an asm trampoline in machold (loader/machold.c), NOT here. The thunk uses the
// witness-method convention — x2 = R metadata, x3 = Self metadata, x4 = witness table,
// x20 = indirect self — which no Swift-expressible function can match (Swift lowers both
// concrete-Data and protocol-extension shims with the metadata order swapped). A Swift
// shim under this symbol misreads registers and corrupts the heap; -O binaries hit it
// from the inlined Data.init(Sequence), which casts to ContiguousBytes and calls the
// thunk. See linux/FOUNDATION-ISSUE.md (DataProbe_O bisect).

// Date.formatted(date:time:) convenience.
extension Date {
    @_silgen_name("$s10Foundation4DateV9formatted4date4timeSSAC11FormatStyleV0bG0V_AH04TimeG0VtF")
    public func _compatFormatted(date: Date.FormatStyle.DateStyle, time: Date.FormatStyle.TimeStyle) -> String {
        formatted(date: date, time: time)
    }
}

// Date.FormatStyle.DateStyle/.TimeStyle static getters + metadata accessors.
@_silgen_name("$s10Foundation4DateV11FormatStyleV0bD0V11abbreviatedAGvgZ")
public func _compatDateStyleAbbreviated() -> Date.FormatStyle.DateStyle { .abbreviated }
@_silgen_name("$s10Foundation4DateV11FormatStyleV04TimeD0V9shortenedAGvgZ")
public func _compatTimeStyleShortened() -> Date.FormatStyle.TimeStyle { .shortened }

@_silgen_name("$s10Foundation4DateV11FormatStyleV0bD0VMa")
public func _compatDateStyleMetadata(_ request: UInt) -> (UnsafeRawPointer, UInt) {
    (unsafeBitCast(Date.FormatStyle.DateStyle.self, to: UnsafeRawPointer.self), 0)
}
@_silgen_name("$s10Foundation4DateV11FormatStyleV04TimeD0VMa")
public func _compatTimeStyleMetadata(_ request: UInt) -> (UnsafeRawPointer, UInt) {
    (unsafeBitCast(Date.FormatStyle.TimeStyle.self, to: UnsafeRawPointer.self), 0)
}
