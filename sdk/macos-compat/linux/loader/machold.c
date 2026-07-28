// machold — a minimal Mach-O loader for arm64, running unmodified macOS binaries
// on Linux/arm64. Built for the macos-compat probe (a stock SwiftUI app): it maps
// the Mach-O image, applies LC_DYLD_CHAINED_FIXUPS, binds the ~88 imported symbols
// against our Linux-built SwiftUI.so + the toolchain libswiftCore.so/Foundation.so
// (+ a couple of name rewrites for Darwin↔Linux mangling differences), registers
// the image's Swift metadata sections with the runtime, then jumps to LC_MAIN.
//
// Scope: arm64 only, DYLD_CHAINED_PTR_64_OFFSET fixups, no dyld shared cache, no
// ObjC, no Mach IPC. The whole point of routing the GUI through Flutter is that
// none of those are needed for this class of app — see ../../SUMMARY.md.
//
// SPDX-License-Identifier: MIT

#define _GNU_SOURCE
#ifndef _GNU_SOURCE
#define _GNU_SOURCE   /* qsort_r (glibc) for -sortUsingComparator: */
#endif
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <sys/time.h>
#include <fcntl.h>
#include <unistd.h>
#include <dlfcn.h>
#include <errno.h>
#include <sys/mman.h>
#include <sys/stat.h>

// ───────────────────────────── Mach-O structures ─────────────────────────────
// Inlined (Linux has no <mach-o/*.h>). Field layouts are the stable Apple ABI.

#define MH_MAGIC_64   0xfeedfacf
#define CPU_TYPE_ARM64 0x0100000c

#define LC_REQ_DYLD              0x80000000u
#define LC_SEGMENT_64            0x19
#define LC_SYMTAB                0x02
#define LC_DYSYMTAB              0x0b
#define LC_LOAD_DYLIB            0x0c
#define LC_ID_DYLIB              0x0d
#define LC_LOAD_WEAK_DYLIB       (0x18 | LC_REQ_DYLD)
#define LC_REEXPORT_DYLIB        (0x1f | LC_REQ_DYLD)
#define LC_MAIN                  (0x28 | LC_REQ_DYLD)
#define LC_DYLD_CHAINED_FIXUPS   (0x34 | LC_REQ_DYLD)
#define LC_DYLD_EXPORTS_TRIE     (0x33 | LC_REQ_DYLD)

typedef struct {
    uint32_t magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags, reserved;
} mach_header_64;

typedef struct { uint32_t cmd, cmdsize; } load_command;

typedef struct {
    uint32_t cmd, cmdsize;
    char     segname[16];
    uint64_t vmaddr, vmsize, fileoff, filesize;
    uint32_t maxprot, initprot, nsects, flags;
} segment_command_64;

typedef struct {
    char     sectname[16], segname[16];
    uint64_t addr, size;
    uint32_t offset, align, reloff, nreloc, flags, reserved1, reserved2, reserved3;
} section_64;

typedef struct { uint32_t cmd, cmdsize; uint64_t entryoff, stacksize; } entry_point_command;
typedef struct { uint32_t cmd, cmdsize, dataoff, datasize; } linkedit_data_command;
// LC_LOAD_DYLIB / LC_LOAD_WEAK_DYLIB / LC_REEXPORT_DYLIB / LC_ID_DYLIB: the dylib name
// string follows the command at byte offset `name_offset` from the command start.
typedef struct {
    uint32_t cmd, cmdsize;
    uint32_t name_offset, timestamp, current_version, compatibility_version;
} dylib_command;

// ─────────────────────────── chained-fixups structures ───────────────────────

typedef struct {
    uint32_t fixups_version, starts_offset, imports_offset, symbols_offset;
    uint32_t imports_count, imports_format, symbols_format;
} dyld_chained_fixups_header;

typedef struct {
    uint32_t seg_count;
    uint32_t seg_info_offset[1];   // [seg_count]
} dyld_chained_starts_in_image;

typedef struct {
    uint32_t size;
    uint16_t page_size;
    uint16_t pointer_format;
    uint64_t segment_offset;       // from image base (mach_header)
    uint32_t max_valid_pointer;
    uint16_t page_count;
    uint16_t page_start[1];        // [page_count]
} dyld_chained_starts_in_segment;

#define DYLD_CHAINED_PTR_64             2
#define DYLD_CHAINED_PTR_64_OFFSET      6
#define DYLD_CHAINED_PTR_ARM64E_USERLAND   9   // arm64e, vm-offset targets, 16-bit binds
#define DYLD_CHAINED_PTR_ARM64E_USERLAND24 12  // arm64e, vm-offset targets, 24-bit binds
#define DYLD_CHAINED_PTR_START_NONE  0xFFFF
#define DYLD_CHAINED_PTR_START_MULTI 0x8000
#define DYLD_CHAINED_IMPORT          1

// import entry (DYLD_CHAINED_IMPORT): lib_ordinal:8, weak_import:1, name_offset:23
typedef struct { uint32_t bits; } dyld_chained_import;

// ───────────────────────────────── helpers ───────────────────────────────────

static int g_verbose = 0;
static int g_immortal_data = 0;   // MACHOLD_IMMORTAL_DATA: interpose __DataStorage init
static int g_typelog = 0;         // MACHOLD_TYPELOG: log binary's 10Foundation type lookups
#define LOG(...)  do { if (g_verbose) fprintf(stderr, "[machold] " __VA_ARGS__); } while (0)
#define DIE(...)  do { fprintf(stderr, "[machold] FATAL: " __VA_ARGS__); exit(1); } while (0)

static size_t round_up(size_t v, size_t a) { return (v + a - 1) & ~(a - 1); }

static int prot_from_initprot(uint32_t ip) {
    int p = 0;
    if (ip & 1) p |= PROT_READ;
    if (ip & 2) p |= PROT_WRITE;
    if (ip & 4) p |= PROT_EXEC;
    return p;
}

// Replace every occurrence of `from` with `to` in `dst`, in place, bounded by `cap`.
static void str_replace_all(char *dst, size_t cap, const char *from, const char *to) {
    char *p;
    size_t flen = strlen(from), tlen = strlen(to);
    while ((p = strstr(dst, from)) != NULL) {
        size_t tail = strlen(p + flen);
        if ((size_t)(p - dst) + tlen + tail + 1 > cap) break;
        memmove(p + tlen, p + flen, tail + 1);
        memcpy(p, to, tlen);
    }
}

// Darwin's stack-probe. Swift's dynamic stack allocation (alloca of a
// runtime-sized value) emits: `mov x9, <size>; bl ___chkstk_darwin; sub sp,sp,size`.
// The probe must TOUCH every page between sp and sp-size so the kernel faults them
// in one page at a time — a single large `sub sp` that jumps past the stack guard
// gap (and then writes) would otherwise SIGSEGV instead of growing the stack. Size
// is in x9 (per the binary's call sites). Must preserve all registers except the
// intra-procedure scratch x16/x17; does not modify sp. Capped so a bogus size
// can't loop forever.
extern void machold_chkstk_darwin(void);
__asm__(
    ".text\n"
    ".globl machold_chkstk_darwin\n"
    ".p2align 2\n"
    "machold_chkstk_darwin:\n"
    "    mov  x16, sp\n"            // x16 = probe cursor
    "    sub  x17, sp, x9\n"        // x17 = target low address (sp - size)
    "    cmp  x9, #0x400000\n"      // cap probe span at 4 MB
    "    b.ls 1f\n"
    "    sub  x17, sp, #0x400000\n"
    "1:  cmp  x16, x17\n"
    "    b.ls 2f\n"                 // cursor <= target → done
    "    sub  x16, x16, #4096\n"    // step down one page
    "    ldr  xzr, [x16]\n"         // touch it → kernel grows the stack
    "    b    1b\n"
    "2:  ret\n"
);

// ── Immortal-__DataStorage trampoline (diagnostic, gated by MACHOLD_IMMORTAL_DATA) ──
// FOUNDATION-WORKLIST.md probe knob. The probe's `Data(jsonString.utf8)` builds an
// InlineSlice whose storage the binary allocates itself (swift_allocObject with the
// *Linux* __DataStorage metadata size) and then initializes by calling the imported
// initializing init `__DataStorage.init(bytes:length:)` (cfc). Disassembly of the
// binary's InlineSlice.init pins the ABI: swiftself x20 = self (the allocated object),
// x0 = bytes (UnsafeRawPointer?), x1 = length (Int); returns self in x0. This interposes
// the init: forward unchanged to the real Linux init, then bump the refcount so any
// over-release can't reach zero (leaks ~storage/load — fine for a probe).
// OUTCOME (2026-06-08 cont.): this does NOT make the probe render. It keeps the json
// storage alive (verified: refcount stays healthy, _bytes valid) but the probe still
// crashes downstream — so the wall is NOT the json storage's lifecycle. Kept as a knob
// to isolate storage-lifecycle from the real culprit (the binary's surrounding inlined
// Foundation code corrupting the heap). See the worklist's 2026-06-08 (cont.) section.
void *machold_real_ds_init = 0;   // real Linux __DataStorage.init(bytes:length:) (cfc)
void *machold_swift_retain = 0;   // swift_retain
extern void machold_ds_init_immortal(void);
__asm__(
    ".text\n"
    ".globl machold_ds_init_immortal\n"
    ".p2align 2\n"
    "machold_ds_init_immortal:\n"
    "    stp  x29, x30, [sp, #-32]!\n"   // save fp, lr
    "    mov  x29, sp\n"
    "    stp  x19, x21, [sp, #16]\n"     // save callee-saved we reuse
    // self already in x20 (swiftself), bytes in x0, length in x1 — forward verbatim.
    "    adrp x16, machold_real_ds_init\n"
    "    add  x16, x16, :lo12:machold_real_ds_init\n"
    "    ldr  x16, [x16]\n"
    "    blr  x16\n"                      // real init -> initialized self in x0
    "    mov  x19, x0\n"                  // keep self
    "    mov  w21, #8\n"                  // extra retains
    "1:  cbz  w21, 2f\n"
    "    mov  x0, x19\n"
    "    adrp x16, machold_swift_retain\n"
    "    add  x16, x16, :lo12:machold_swift_retain\n"
    "    ldr  x16, [x16]\n"
    "    blr  x16\n"                      // swift_retain(self) (preserves x19/x21)
    "    sub  w21, w21, #1\n"
    "    b    1b\n"
    "2:  mov  x0, x19\n"                  // return self
    "    ldp  x19, x21, [sp, #16]\n"
    "    ldp  x29, x30, [sp], #32\n"
    "    ret\n"
);

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - ObjC messaging runtime (tier 2) — a minimal from-scratch objc_msgSend
// ══════════════════════════════════════════════════════════════════════════════
// The tier-1 ObjC handling above only REALIZES Swift-interop classes (they are never
// messaged). This is the real thing: dispatch. It stays in machold's "no external
// runtime" philosophy — ~1 asm trampoline + method-list walk, no libobjc, no Darling.
//
// The heavy lifting is already done by machold's chained-fixup pass: __objc_classlist
// entries, each class's isa (→metaclass)/superclass/cache, and every __objc_selrefs slot
// are rebased/bound like any other DATA pointer. So a static ObjC class object arrives
// fully wired; we only need to (a) read its method lists and (b) dispatch.
//
// ObjC class object (Darwin, __objc_data): {isa@0, superclass@8, cache@16, vtable@24, data@32}.
//   data low 3 bits = tag (isSwift/RW); mask &~0x7. data → class_ro_t.
// class_ro_t: {flags@0, instanceStart@4, instanceSize@8, reserved@12, ivarLayout@16,
//   name@24, baseMethods@32, baseProtocols@40, ivars@48, weakIvarLayout@56, baseProperties@64}.
// method_list_t: {uint32 entsizeAndFlags@0, uint32 count@4, method_t[]@8}.
//   small/relative list: (entsizeAndFlags & 0x80000000); entsize = &0xFFFC (=12).
//   small method_t {int32 name@0, int32 types@4, int32 imp@8}, each a SELF-RELATIVE offset.
//     name's target is a SELREF SLOT (in __objc_selrefs) whose content (after fixups) is the
//     char* selector string; imp's target is the code. big method_t {name,types,imp} = 3 ptrs,
//     name = char* directly.
// SEL in our world = the char* selector string (the __objc_stubs load x1 from a selref slot,
//   whose content is the methname pointer). Compare by strcmp — always correct.
#define MACHO_CM_DATA_OFF  32              // class.data (= MACHO_CM_DATA, defined later)
#define MACHO_CM_SUPER_OFF 8               // class.superclass (= MACHO_CM_SUPERCLASS, defined later)
static int g_trace_objc = 0;               // MACHOLD_TRACE_OBJC: log dispatch
static unsigned long g_msgsend_count = 0;  // # of dispatches (tier detector)

// Category side-table: methods added to an existing class by an @implementation Cat(…).
// Our classes dispatch straight from class_ro.baseMethods (no class_rw), so category
// methods live here and the lookup consults them per class BEFORE baseMethods (categories
// override). Populated from __objc_catlist post-fixup (see main).
static struct { void *cls; uint8_t *mlist; } g_categories[256];
static int g_categories_n = 0;

// Scan one method_list_t for `op`; return its IMP, or NULL. Handles small/relative
// (modern arm64: name-rel → selref slot → char*; imp-rel → code) and big (3-ptr) lists.
static void *machold_scan_mlist(uint8_t *ml, const char *op) {
    if (!ml) return NULL;
    uint32_t ef = *(uint32_t *)ml, count = *(uint32_t *)(ml + 4);
    int small = (ef & 0x80000000u) != 0;
    uint32_t es = ef & 0xFFFCu;
    uint8_t *e = ml + 8;
    for (uint32_t i = 0; i < count; i++, e += es) {
        const char *name; void *imp;
        if (small) { name = *(char **)(e + *(int32_t *)e); imp = (void *)(e + 8 + *(int32_t *)(e + 8)); }
        else       { name = *(char **)e;                   imp = *(void **)(e + 16); }
        if (name == op || (name && strcmp(name, op) == 0)) return imp;
    }
    return NULL;
}

// Walk `cls` and its superclass chain for a method named `op`; return its IMP, or NULL.
#define MACHO_RO_ROOT 0x2   // class_ro_t.flags: this is a root class (no real superclass)
__attribute__((used)) void *machold_lookup_imp_from_class(uint8_t *cls, const char *op) {
    while (cls) {
        for (int ci = 0; ci < g_categories_n; ci++)        // categories override base methods
            if (g_categories[ci].cls == cls) {
                void *imp = machold_scan_mlist(g_categories[ci].mlist, op);
                if (imp) return imp;
            }
        uintptr_t data = *(uintptr_t *)(cls + MACHO_CM_DATA_OFF) & ~(uintptr_t)0x7;
        if (!data) break;                                  // unrealized/foreign → stop
        void *imp = machold_scan_mlist(*(uint8_t **)(data + 32), op);  // class_ro_t.baseMethods
        if (imp) return imp;
        // A root class's superclass field is a chained-fixup rebase (→ the mach header,
        // NOT NULL), so terminate on the RO_ROOT flag rather than a null superclass.
        if (*(uint32_t *)data & MACHO_RO_ROOT) break;
        cls = *(uint8_t **)(cls + MACHO_CM_SUPER_OFF);
    }
    return NULL;
}

// C core of the dispatcher: resolve self's class and look up the method.
__attribute__((used)) void *machold_lookup_imp(void *self, const char *op) {
    if (!self) return NULL;
    uint8_t *cls = *(uint8_t **)self;      // isa (raw pointer isa in our world)
    void *imp = machold_lookup_imp_from_class(cls, op);
    if (g_trace_objc)
        fprintf(stderr, "[machold] msgSend(%p, \"%s\") isa=%p -> imp=%p\n", self, op ? op : "(nil)", (void *)cls, imp);
    g_msgsend_count++;
    return imp;
}
// Reported at exit under MACHOLD_TRACE_OBJC — the tier-1→tier-2 crossing signal.
__attribute__((destructor)) static void machold_objc_report(void) {
    if (g_trace_objc) fprintf(stderr, "[machold] objc_msgSend dispatches: %lu\n", g_msgsend_count);
}
// method-not-found. Strict (default): a clear abort (the real runtime would route
// _objc_msgForward / resolveInstanceMethod). Lenient (MACHOLD_OBJC_LENIENT, a discovery
// aid): log the missing class→selector and return nil so one run of a rich probe harvests
// the whole missing-selector work-list instead of dying on the first. Returns the value
// msgSend hands back (tail-branched), so nil in lenient mode.
static int g_objc_lenient = 0;
int machold_obj_type(void *o);   // fwd (machold object-model ABI; defined far below)
// A foreign (Linux Swift/CF) object reached machold's dispatch (its isa isn't a machold class).
// Route common selectors to the CF C-API. Returns (void*)-1 if unhandled. Enables Swift-native
// Foundation objects (needed for a hybrid tool's `as?` casts) to also take machold messages.
static void *machold_foreign_dispatch(void *self, const char *op, void *a2, unsigned long a3, unsigned long a4, unsigned long a5) {
    unsigned long (*cfType)(void *) = (unsigned long (*)(void *))dlsym(RTLD_DEFAULT, "CFGetTypeID");
    if (!cfType) return (void *)-1;
    unsigned long t = cfType(self);
    unsigned long (*dataT)(void) = (unsigned long (*)(void))dlsym(RTLD_DEFAULT, "CFDataGetTypeID");
    unsigned long (*strT)(void)  = (unsigned long (*)(void))dlsym(RTLD_DEFAULT, "CFStringGetTypeID");
    if (dataT && t == dataT()) {
        if (!strcmp(op, "bytes"))  { const void *(*f)(void *) = (const void *(*)(void *))dlsym(RTLD_DEFAULT, "CFDataGetBytePtr"); return f ? (void *)f(self) : NULL; }
        if (!strcmp(op, "length")) { long (*f)(void *) = (long (*)(void *))dlsym(RTLD_DEFAULT, "CFDataGetLength"); return (void *)(long)(f ? f(self) : 0); }
    }
    if (strT && t == strT()) {
        if (!strcmp(op, "length")) { long (*f)(void *) = (long (*)(void *))dlsym(RTLD_DEFAULT, "CFStringGetLength"); return (void *)(long)(f ? f(self) : 0); }
        if (!strcmp(op, "UTF8String")) {
            const char *(*f)(void *, unsigned) = (const char *(*)(void *, unsigned))dlsym(RTLD_DEFAULT, "CFStringGetCStringPtr");
            const char *p = f ? f(self, 0x08000100) : NULL; if (p) return (void *)p;
            // Swift strings have no UTF8 fast pointer → copy into a heap buffer (leaked; matches
            // -UTF8String's autorelease lifetime, and machold never frees anyway).
            long (*gl)(void *) = (long (*)(void *))dlsym(RTLD_DEFAULT, "CFStringGetLength");
            long n = gl ? gl(self) : 0; size_t cap = (size_t)n * 4 + 16; char *buf = (char *)malloc(cap);
            unsigned char (*gc)(void *, char *, long, unsigned) = (unsigned char (*)(void *, char *, long, unsigned))dlsym(RTLD_DEFAULT, "CFStringGetCString");
            if (buf && gc && gc(self, buf, (long)cap, 0x08000100)) return buf;
            free(buf); return NULL;
        }
        if (!strcmp(op, "compare:options:range:locale:") || !strcmp(op, "compare:options:range:") || !strcmp(op, "compare:options:") || !strcmp(op, "compare:")) {
            // CFStringCompareWithOptions(s1, s2, CFRange{loc,len}, flags); range applies to self.
            long (*f)(void *, void *, long, long, unsigned long) = (long (*)(void *, void *, long, long, unsigned long))dlsym(RTLD_DEFAULT, "CFStringCompareWithOptions");
            long len = 0; long (*gl)(void *) = (long (*)(void *))dlsym(RTLD_DEFAULT, "CFStringGetLength"); if (gl) len = gl(self);
            long rloc = strcmp(op, "compare:options:range:") == 0 || strcmp(op, "compare:options:range:locale:") == 0 ? (long)a4 : 0;
            long rlen = strcmp(op, "compare:options:range:") == 0 || strcmp(op, "compare:options:range:locale:") == 0 ? (long)a5 : len;
            unsigned long flags = strncmp(op, "compare:options:", 16) == 0 ? a3 : 0;
            if (f) return (void *)f(self, a2, rloc, rlen, flags);
        }
    }
    return (void *)-1;
}
__attribute__((used)) void *machold_msgSend_fail(void *self, const char *op, void *a2, unsigned long a3, unsigned long a4, unsigned long a5) {
    if (self && op && machold_obj_type(self) == -1) {
        void *r = machold_foreign_dispatch(self, op, a2, a3, a4, a5);
        if (r != (void *)-1) return r;
    }
    const char *cn = "?";
    if (self) {
        uint8_t *cls = *(uint8_t **)self;
        uintptr_t data = cls ? (*(uintptr_t *)(cls + MACHO_CM_DATA_OFF) & ~(uintptr_t)0x7) : 0;
        if (data) cn = *(const char **)(data + 24);
    }
    fprintf(stderr, "[machold] %s selector %s -> \"%s\"\n",
            g_objc_lenient ? "MISSING" : "FATAL: unrecognized", cn, op ? op : "(nil)");
    if (g_objc_lenient) return NULL;
    exit(1);
}

// objc_msgSend: the naked-asm dispatcher. x0=self, x1=SEL, x2-x7 int args, x8 indirect
// result, q0-q7 fp args. Save the arg registers, call the C lookup with (self, SEL) already
// in x0/x1, then restore every arg register verbatim and tail-`br` to the IMP. Precedent:
// machold_ds_init_immortal above. Frame = 0xA0 (x0-x8 + q0-q7 + fp/lr).
extern void machold_objc_msgSend(void);
__asm__(
    ".text\n"
    ".globl machold_objc_msgSend\n"
    ".p2align 2\n"
    "machold_objc_msgSend:\n"
    "    cbz  x0, 3f\n"                     // nil receiver → return 0 (ObjC nil-messaging rule)
    "    stp  x29, x30, [sp, #-0xa0]!\n"
    "    mov  x29, sp\n"
    "    stp  x0, x1, [sp, #0x10]\n"        // self, SEL
    "    stp  x2, x3, [sp, #0x20]\n"
    "    stp  x4, x5, [sp, #0x30]\n"
    "    stp  x6, x7, [sp, #0x40]\n"
    "    str  x8,     [sp, #0x50]\n"        // indirect-result ptr
    "    stp  q0, q1, [sp, #0x60]\n"
    "    stp  q2, q3, [sp, #0x80]\n"        // (q4-q7 rarely used by our probes; save the common 4)
    "    bl   machold_lookup_imp\n"         // x0=self, x1=SEL already → imp in x0
    "    mov  x16, x0\n"
    "    ldp  x0, x1, [sp, #0x10]\n"
    "    ldp  x2, x3, [sp, #0x20]\n"
    "    ldp  x4, x5, [sp, #0x30]\n"
    "    ldp  x6, x7, [sp, #0x40]\n"
    "    ldr  x8,     [sp, #0x50]\n"
    "    ldp  q0, q1, [sp, #0x60]\n"
    "    ldp  q2, q3, [sp, #0x80]\n"
    "    ldp  x29, x30, [sp], #0xa0\n"
    "    cbz  x16, 2f\n"
    "    br   x16\n"                         // tail-call the method with args intact
    "2:  b    machold_msgSend_fail\n"        // not found (x0=self, x1=SEL) → abort
    "3:  mov  x0, #0\n"
    "    ret\n"
);

// objc_msgSendSuper2(struct objc_super {id receiver@0, Class current@8} *sup, SEL, ...):
// start the lookup at current->superclass, then dispatch on the real receiver.
extern void machold_objc_msgSendSuper2(void);
__asm__(
    ".text\n"
    ".globl machold_objc_msgSendSuper2\n"
    ".p2align 2\n"
    "machold_objc_msgSendSuper2:\n"
    "    stp  x29, x30, [sp, #-0xa0]!\n"
    "    mov  x29, sp\n"
    "    ldr  x9,  [x0]\n"                   // receiver = sup->receiver
    "    ldr  x10, [x0, #8]\n"               // current class
    "    ldr  x10, [x10, #8]\n"              // start = current->superclass
    "    str  x9, [sp, #0x10]\n"            // stash receiver (becomes x0)
    "    str  x1, [sp, #0x18]\n"
    "    stp  x2, x3, [sp, #0x20]\n"
    "    stp  x4, x5, [sp, #0x30]\n"
    "    stp  x6, x7, [sp, #0x40]\n"
    "    str  x8,     [sp, #0x50]\n"
    "    stp  q0, q1, [sp, #0x60]\n"
    "    stp  q2, q3, [sp, #0x80]\n"
    "    mov  x0, x10\n"                      // lookup_from_class(start, SEL)
    "    bl   machold_lookup_imp_from_class\n"
    "    mov  x16, x0\n"
    "    ldp  x0, x1, [sp, #0x10]\n"          // x0 = receiver (not &objc_super)
    "    ldp  x2, x3, [sp, #0x20]\n"
    "    ldp  x4, x5, [sp, #0x30]\n"
    "    ldp  x6, x7, [sp, #0x40]\n"
    "    ldr  x8,     [sp, #0x50]\n"
    "    ldp  q0, q1, [sp, #0x60]\n"
    "    ldp  q2, q3, [sp, #0x80]\n"
    "    ldp  x29, x30, [sp], #0xa0\n"
    "    cbz  x16, 2f\n"
    "    br   x16\n"
    "2:  b    machold_msgSend_fail\n"
);

// C runtime helpers (plain functions returned from resolve_symbol). Objects are malloc'd
// (NOT swift heap objects), so ObjC retain/release are identity/no-op — leaks are fine for
// the compat host, and it avoids swift_release misreading a non-swift refcount header.
static void *machold_class_createInstance(uint8_t *cls, size_t extra) {
    if (!cls) return NULL;
    uintptr_t data = *(uintptr_t *)(cls + MACHO_CM_DATA_OFF) & ~(uintptr_t)0x7;
    uint32_t sz = data ? *(uint32_t *)(data + 8) : 16;   // class_ro_t.instanceSize
    if (sz < 16) sz = 16;
    void *o = calloc(1, sz + extra);
    if (o) *(void **)o = cls;                             // isa = class
    return o;
}
static void *machold_objc_alloc(uint8_t *cls) {
    return ((void *(*)(void *, const char *))machold_objc_msgSend)(cls, "alloc");
}
static void *machold_objc_alloc_init(uint8_t *cls) {
    void *o = ((void *(*)(void *, const char *))machold_objc_msgSend)(cls, "alloc");
    return ((void *(*)(void *, const char *))machold_objc_msgSend)(o, "init");
}
static int g_prog_argc = 0;         // the loaded program's argc/argv (set before entry) —
static char **g_prog_argv = NULL;   // NSProcessInfo.arguments reads these.
static void *machold_object_getClass(void *o) { return o ? *(void **)o : NULL; }
static void *machold_objc_identity(void *o) { return o; }   // retain/autorelease/opt_self
static void machold_objc_noop(void *o) { (void)o; }         // release
static void machold_objc_storeStrong(void **loc, void *v) { if (loc) *loc = v; }  // no refcount
// Class registry (name→cls). Declared here so the isa-walkers (opt_class/isKind/cast) can gate on
// "is a machold class" before walking a chain — a foreign Swift/CF object's isa is NOT machold-
// shaped, so reading class_ro off it crashes.
static struct { const char *name; void *cls; } g_class_reg[512];
static int g_class_reg_n = 0;
static int machold_is_machold_class(void *cls) {
    for (int i = 0; i < g_class_reg_n; i++) if (g_class_reg[i].cls == cls) return 1;
    return 0;
}
// [obj class] optimized: for an instance return its isa (class); for a class object (whose isa
// is a metaclass) return the object itself — object_getClass would wrongly give the metaclass.
static void *machold_objc_opt_class(void *obj) {
    if (!obj) return NULL;
    uint8_t *isa = *(uint8_t **)obj;
    if (!isa) return NULL;
    if (!machold_is_machold_class(isa)) return isa;   // foreign (Swift/CF): its isa IS its class
    uintptr_t data = *(uintptr_t *)(isa + MACHO_CM_DATA_OFF) & ~(uintptr_t)0x7;
    if (data && (*(uint32_t *)data & 0x1 /* RO_META */)) return obj;   // obj is a class
    return isa;
}
// [obj isKindOfClass:cls]: walk obj's isa→superclass chain (terminate at a root class).
static char machold_objc_isKind(void *obj, void *cls) {
    if (!obj || !cls) return 0;
    uint8_t *c = *(uint8_t **)obj;
    if (!machold_is_machold_class(c)) return 0;   // foreign object — not walkable as a machold class
    for (int i = 0; c && i < 32; i++) {
        if ((void *)c == cls) return 1;
        uintptr_t data = *(uintptr_t *)(c + MACHO_CM_DATA_OFF) & ~(uintptr_t)0x7;
        if (data && (*(uint32_t *)data & MACHO_RO_ROOT)) break;
        c = *(uint8_t **)(c + MACHO_CM_SUPER_OFF);
    }
    return 0;
}
// [Class new] = [[Class alloc] init].
static void *machold_objc_opt_new(void *cls) {
    if (!cls) return NULL;
    void *o = machold_class_createInstance((uint8_t *)cls, 0);
    void *imp = machold_lookup_imp_from_class((uint8_t *)cls, "init");
    return imp ? ((void *(*)(void *, const char *))imp)(o, "init") : o;
}
// Synthesized-property accessors. atomic/copy ignored (machold refcounting is identity).
static void *machold_getProperty(void *self, const char *cmd, long off, char atomic) {
    (void)cmd; (void)atomic; return *(void **)((char *)self + off);
}
static void machold_setProperty(void *self, const char *cmd, void *val, long off) {   // _atomic/_nonatomic(_copy)
    (void)cmd; *(void **)((char *)self + off) = val;
}
static void machold_setProperty_full(void *self, const char *cmd, long off, void *val, char atomic, signed char copy) {
    (void)cmd; (void)atomic; (void)copy; *(void **)((char *)self + off) = val;
}
static const char *machold_sel_registerName(const char *s) { return s; }          // SEL = the string

// Class registry (name → Class): the app's __objc_classlist classes (registered post-fixup,
// see main) plus our synthesized Foundation classes (registered in their init). Backs
// objc_getClass / objc_lookUpClass / NSClassFromString.
static void machold_register_class(const char *name, void *cls) {
    if (name && cls && g_class_reg_n < 512) {
        g_class_reg[g_class_reg_n].name = name;
        g_class_reg[g_class_reg_n].cls = cls;
        g_class_reg_n++;
    }
}
static void *machold_objc_getClass(const char *name) {
    if (!name) return NULL;
    for (int i = 0; i < g_class_reg_n; i++)
        if (strcmp(g_class_reg[i].name, name) == 0) return g_class_reg[i].cls;
    return NULL;
}
// Register a category's method list against a class (side-table consulted by lookup).
static void machold_add_category(void *cls, uint8_t *mlist) {
    if (cls && mlist && g_categories_n < 256) {
        g_categories[g_categories_n].cls = cls;
        g_categories[g_categories_n].mlist = mlist;
        g_categories_n++;
    }
}

// ── Messageable NSObject (tier 2, O2) ────────────────────────────────────────
// A real ObjC class hierarchy rooted at NSObject that machold SYNTHESIZES (like the
// _SwiftObject tier-1 synthesis, but with actual methods so it's messageable). The
// binary's subclass (in __objc_classlist) has its superclass field bound to these, so
// [[Foo alloc] init] resolves +alloc/-init here. Built in the Darwin class layout our
// machold_lookup_imp already walks: big (non-relative) method lists.
typedef struct { const char *name; const char *types; void *imp; } machold_method_t;
typedef struct { uint32_t entsize; uint32_t count; machold_method_t methods[48]; } machold_mlist_t;
typedef struct {
    uint32_t flags; uint32_t instanceStart; uint32_t instanceSize; uint32_t reserved;
    const void *ivarLayout; const char *name; const void *baseMethods;
    const void *baseProtocols; const void *ivars; const void *weakIvarLayout; const void *baseProperties;
} machold_class_ro_t;
typedef struct { void *isa; void *superclass; void *cache; void *vtable; uintptr_t data; } machold_class_t;

// NSObject method imps (called by msgSend: x0=self, x1=SEL). Minimal, leak-tolerant.
static void *machold_ns_self(void *self, const char *cmd)  { (void)cmd; return self; }
static void  machold_ns_noop(void *self, const char *cmd)  { (void)self; (void)cmd; }
static void *machold_ns_alloc(void *cls, const char *cmd)  { (void)cmd; return machold_class_createInstance(cls, 0); }
static void *machold_ns_new(void *cls, const char *cmd)    { (void)cmd; return machold_objc_alloc_init(cls); }
static void *machold_ns_getclass(void *self, const char *cmd) { (void)cmd; return self ? *(void **)self : NULL; }

static machold_mlist_t machold_nsobj_imethods, machold_nsobj_cmethods;
static machold_class_ro_t machold_nsobj_ro, machold_nsobj_meta_ro;
static machold_class_t machold_nsobj_cls, machold_nsobj_meta;
static int machold_nsobject_inited = 0;
static void machold_init_nsobject(void) {
    if (machold_nsobject_inited) return; machold_nsobject_inited = 1;
    machold_method_t im[] = {
        {"init", "@16@0:8", (void *)machold_ns_self},
        {"self", "@16@0:8", (void *)machold_ns_self},
        {"retain", "@16@0:8", (void *)machold_ns_self},
        {"autorelease", "@16@0:8", (void *)machold_ns_self},
        {"release", "v16@0:8", (void *)machold_ns_noop},
        {"dealloc", "v16@0:8", (void *)machold_ns_noop},
        {"class", "#16@0:8", (void *)machold_ns_getclass},
    };
    machold_method_t cm[] = {
        {"alloc", "@16#0:8", (void *)machold_ns_alloc},
        {"new", "@16#0:8", (void *)machold_ns_new},
        {"class", "#16#0:8", (void *)machold_ns_self},
    };
    machold_nsobj_imethods.entsize = sizeof(machold_method_t);   // 24 → big method list
    machold_nsobj_imethods.count = sizeof(im) / sizeof(im[0]);
    memcpy(machold_nsobj_imethods.methods, im, sizeof(im));
    machold_nsobj_cmethods.entsize = sizeof(machold_method_t);
    machold_nsobj_cmethods.count = sizeof(cm) / sizeof(cm[0]);
    memcpy(machold_nsobj_cmethods.methods, cm, sizeof(cm));

    machold_nsobj_ro.flags = 0x2;              // RO_ROOT → lookup terminates here
    machold_nsobj_ro.instanceSize = 8;         // bare NSObject = isa only
    machold_nsobj_ro.name = "NSObject";
    machold_nsobj_ro.baseMethods = &machold_nsobj_imethods;
    machold_nsobj_meta_ro.flags = 0x1 | 0x2;   // RO_META | RO_ROOT
    machold_nsobj_meta_ro.instanceSize = 40;
    machold_nsobj_meta_ro.name = "NSObject";
    machold_nsobj_meta_ro.baseMethods = &machold_nsobj_cmethods;

    machold_nsobj_cls.isa = &machold_nsobj_meta;
    machold_nsobj_cls.superclass = NULL;                       // root class
    machold_nsobj_cls.cache = NULL;                            // our msgSend never reads cache
    machold_nsobj_cls.data = (uintptr_t)&machold_nsobj_ro;
    machold_nsobj_meta.isa = &machold_nsobj_meta;              // root metaclass isa = self
    machold_nsobj_meta.superclass = &machold_nsobj_cls;        // convention: root meta → root class
    machold_nsobj_meta.cache = NULL;
    machold_nsobj_meta.data = (uintptr_t)&machold_nsobj_meta_ro;
    machold_register_class("NSObject", &machold_nsobj_cls);
}

// ── Messageable constant NSString (@"…", tier 2, O3) ─────────────────────────
// A `@"…"` literal is a static struct {isa, flags, const char *str@16, long len@24}
// whose isa is bound to ___CFConstantStringClassReference. Provide that class with the
// common string messages, reading the struct directly. Strings built at runtime
// (stringByAppendingString:) use the same layout, so the same methods serve both.
static machold_class_t machold_cfstring_cls, machold_cfstring_meta;  // fwd (isa set in init)
// Make a heap NSString of our layout {isa, flags, char* str@16, long len@24} owning a
// fresh copy of [bytes,len). Shared by all string-producing methods.
static void *machold_make_string(const char *bytes, long len) {
    if (len < 0) len = 0;
    char *buf = (char *)malloc((size_t)len + 1);
    if (bytes) memcpy(buf, bytes, (size_t)len);
    buf[len] = 0;
    char *obj = (char *)calloc(1, 32);
    *(void **)obj = &machold_cfstring_cls;
    *(const char **)(obj + 16) = buf;
    *(long *)(obj + 24) = len;
    return obj;
}
// NSFastEnumerationState {state@0, id* itemsPtr@8, unsigned long* mutationsPtr@16,
// unsigned long extra[5]@24}. Return the whole collection in one batch via itemsPtr
// (the "internal storage" pattern): first call sets state + itemsPtr and returns count;
// second call returns 0. mutationsPtr → a stable zero (our collections don't trip the
// mutation guard here). Shared by NSConstantArray/NSMutableArray/NSMutableSet for-in.
static unsigned long machold_zero_mutation = 0;
static unsigned long machold_fastenum(unsigned long *st, void **items, long count) {
    if (st[0]) return 0;
    st[0] = 1;
    st[1] = (unsigned long)items;                 // itemsPtr
    st[2] = (unsigned long)&machold_zero_mutation; // mutationsPtr
    return (unsigned long)count;
}
static void machold_enum_mutation(void *o) { (void)o; }   // objc_enumerationMutation (no-op)
static void *machold_make_data(const void *bytes, long len);   // fwd (NSData; defined below)
static void *machold_obj_description(void *self, const char *cmd);   // fwd (OpenStep-plist -description)
int machold_obj_type(void *o);   // fwd (machold object-model ABI; defined below)

// ── ObjC blocks ──────────────────────────────────────────────────────────────
// A block is {isa@0, int flags@8, int reserved@12, void* invoke@16, void* descriptor@24,
// captures…}. We never introspect the isa (the concrete-block class symbols are dummy
// buffers so the literal's isa field binds); invoking a block = call invoke(block, args…).
// Block_copy/_Block_object_assign are identity/no-ops — blocks here are invoked
// synchronously in-place (not escaped/copied), so __block byrefs stay on the stack.
static uint8_t machold_block_class[128];              // _NSConcrete{Stack,Global,Malloc}Block isa
static void *machold_block_copy(void *b) { return b; }
static void machold_block_noop(void) {}
static long machold_objc_personality(void) { return 0; }   // never invoked without exceptions
// Invoke an enumerate-style block ^(id obj, NSUInteger idx, BOOL *stop) over items.
typedef void (*machold_enum_blk)(void *blk, void *obj, unsigned long idx, char *stop);
static void machold_enum_block_over(void **items, long count, void *block) {
    if (!block) return;
    machold_enum_blk invoke = *(machold_enum_blk *)((char *)block + 16);   // Block.invoke
    char stop = 0;
    for (long i = 0; i < count && !stop; i++) invoke(block, items[i], (unsigned long)i, &stop);
}

// String-aware object equality (our NSStrings by content, else pointer). Shared by
// dictionary keys, NSArray containsObject:/indexOfObject:.
static int machold_obj_eq(void *a, void *b) {
    if (a == b) return 1;
    if (!a || !b) return 0;
    if (*(void **)a == &machold_cfstring_cls && *(void **)b == &machold_cfstring_cls) {
        const char *sa = *(const char **)((char *)a + 16), *sb = *(const char **)((char *)b + 16);
        return sa && sb && strcmp(sa, sb) == 0;
    }
    return 0;
}
static long  machold_cfstr_length(void *self, const char *cmd) { (void)cmd; return *(long *)((char *)self + 24); }
static const char *machold_cfstr_utf8(void *self, const char *cmd) { (void)cmd; return *(const char **)((char *)self + 16); }
static void *machold_cfstr_append(void *self, const char *cmd, void *other) {
    (void)cmd;
    const char *a = *(const char **)((char *)self + 16);  long al = *(long *)((char *)self + 24);
    const char *b = other ? *(const char **)((char *)other + 16) : ""; long bl = other ? *(long *)((char *)other + 24) : 0;
    char *buf = (char *)malloc(al + bl + 1);
    memcpy(buf, a, al); memcpy(buf + al, b, bl); buf[al + bl] = 0;
    void *r = machold_make_string(buf, al + bl); free(buf); return r;
}
static long machold_cfstr_isEqual(void *self, const char *cmd, void *other) {
    (void)cmd; return machold_obj_eq(self, other);
}
static long machold_cfstr_hasPrefix(void *self, const char *cmd, void *pre) {
    (void)cmd; if (!pre) return 0;
    const char *s = *(const char **)((char *)self + 16), *p = *(const char **)((char *)pre + 16);
    return s && p && strncmp(s, p, strlen(p)) == 0;
}
static long machold_cfstr_hasSuffix(void *self, const char *cmd, void *suf) {
    (void)cmd; if (!suf) return 0;
    const char *s = *(const char **)((char *)self + 16), *p = *(const char **)((char *)suf + 16);
    if (!s || !p) return 0;
    size_t ls = strlen(s), lp = strlen(p);
    return lp <= ls && strcmp(s + ls - lp, p) == 0;
}
static long machold_cfstr_contains(void *self, const char *cmd, void *sub) {
    (void)cmd; if (!sub) return 0;
    const char *s = *(const char **)((char *)self + 16), *p = *(const char **)((char *)sub + 16);
    return s && p && strstr(s, p) != NULL;
}
// rangeOfString: returns an NSRange {location, length} by value (x0:x1). NSNotFound =
// NSIntegerMax. Byte offsets ≈ char offsets for ASCII.
typedef struct { unsigned long loc, len; } machold_nsrange;
static machold_nsrange machold_cfstr_rangeOf(void *self, const char *cmd, void *needle) {
    (void)cmd;
    machold_nsrange r = { 0x7fffffffffffffffUL, 0 };
    const char *h = self ? *(const char **)((char *)self + 16) : NULL;
    const char *n = needle ? *(const char **)((char *)needle + 16) : NULL;
    if (h && n && *n) { const char *hit = strstr(h, n); if (hit) { r.loc = (unsigned long)(hit - h); r.len = strlen(n); } }
    return r;
}
// -compare:options:range:locale: → NSComparisonResult. NSRange passes by value (rloc,rlen in
// x4,x5). Range applies to self; options bit0 = NSCaseInsensitiveSearch. Lexicographic.
static long machold_cfstr_compareOpts(void *self, const char *cmd, void *other, unsigned long opts,
                                      unsigned long rloc, unsigned long rlen, void *locale) {
    (void)cmd; (void)locale;
    const char *a = *(const char **)((char *)self + 16); long alen = *(long *)((char *)self + 24);
    const char *b = other ? *(const char **)((char *)other + 16) : ""; long blen = other ? *(long *)((char *)other + 24) : 0;
    if ((long)rloc <= alen) { a += rloc; long avail = alen - (long)rloc; alen = ((long)rlen <= avail) ? (long)rlen : avail; }
    long m = alen < blen ? alen : blen; int c = 0;
    for (long i = 0; i < m && c == 0; i++) {
        int ca = (unsigned char)a[i], cb = (unsigned char)b[i];
        if (opts & 1) { ca = tolower(ca); cb = tolower(cb); }
        c = ca - cb;
    }
    if (c == 0) c = (alen < blen) ? -1 : (alen > blen ? 1 : 0);
    return c < 0 ? -1 : (c > 0 ? 1 : 0);
}
static void *machold_cfstr_expandTilde(void *self, const char *cmd) {
    (void)cmd;
    const char *s = *(const char **)((char *)self + 16); long n = *(long *)((char *)self + 24);
    if (n > 0 && s[0] == '~') {
        const char *home = getenv("HOME"); if (!home) home = "";
        char buf[4096]; int k = snprintf(buf, sizeof(buf), "%s%s", home, s + 1);
        return machold_make_string(buf, k > 0 ? k : 0);
    }
    return self;
}
static void *machold_cfstr_appendPathExt(void *self, const char *cmd, void *ext) {
    (void)cmd;
    const char *s = *(const char **)((char *)self + 16);
    const char *e = ext ? *(const char **)((char *)ext + 16) : "";
    char buf[4096]; int k = snprintf(buf, sizeof(buf), "%s.%s", s ? s : "", e ? e : "");
    return machold_make_string(buf, k > 0 ? k : 0);
}
static void *machold_cfstr_lastPathComp(void *self, const char *cmd) {
    (void)cmd; const char *s = *(const char **)((char *)self + 16); if (!s) return self;
    const char *sl = strrchr(s, '/'); const char *b = sl ? sl + 1 : s;
    return machold_make_string(b, (long)strlen(b));
}
static void *machold_cfstr_case(void *self, const char *cmd, int upper) {
    (void)cmd;
    const char *s = *(const char **)((char *)self + 16); long n = *(long *)((char *)self + 24);
    char *buf = (char *)malloc((size_t)n + 1);
    for (long i = 0; i < n; i++) buf[i] = upper ? (char)toupper((unsigned char)s[i]) : (char)tolower((unsigned char)s[i]);
    buf[n] = 0; void *r = machold_make_string(buf, n); free(buf); return r;
}
static void *machold_cfstr_upper(void *self, const char *cmd) { return machold_cfstr_case(self, cmd, 1); }
static void *machold_cfstr_lower(void *self, const char *cmd) { return machold_cfstr_case(self, cmd, 0); }
static void *machold_cfstr_substrFrom(void *self, const char *cmd, long i) {
    (void)cmd;
    const char *s = *(const char **)((char *)self + 16); long n = *(long *)((char *)self + 24);
    if (i < 0) i = 0; if (i > n) i = n;
    return machold_make_string(s + i, n - i);
}
static int machold_cfstr_intValue(void *self, const char *cmd) {
    (void)cmd; const char *s = *(const char **)((char *)self + 16); return s ? (int)strtol(s, NULL, 10) : 0;
}
static double machold_cfstr_doubleValue(void *self, const char *cmd) {
    (void)cmd; const char *s = *(const char **)((char *)self + 16); return s ? strtod(s, NULL) : 0;
}
static void *machold_cfstr_dataUsing(void *self, const char *cmd, unsigned long enc) {
    (void)cmd; (void)enc;
    return machold_make_data(*(const char **)((char *)self + 16), *(long *)((char *)self + 24));
}
static void *machold_cfstr_dataUsingLossy(void *self, const char *cmd, unsigned long enc, signed char lossy) {
    (void)cmd; (void)enc; (void)lossy;
    return machold_make_data(*(const char **)((char *)self + 16), *(long *)((char *)self + 24));
}
// stringByTrimmingCharactersInSet: — trim leading/trailing chars for which the set is a member
// (our NSCharacterSet is whitespace-only; good enough for the common trim).
static void *machold_cfstr_trim(void *self, const char *cmd, void *set) {
    (void)cmd; (void)set;
    const char *s = *(const char **)((char *)self + 16); long n = *(long *)((char *)self + 24);
    long a = 0, b = n;
    while (a < b && (s[a] == ' ' || s[a] == '\t' || s[a] == '\n' || s[a] == '\r')) a++;
    while (b > a && (s[b - 1] == ' ' || s[b - 1] == '\t' || s[b - 1] == '\n' || s[b - 1] == '\r')) b--;
    return machold_make_string(s + a, b - a);
}
static void machold_arr_addObject(void *self, const char *cmd, void *obj);  // fwd
static void *machold_arr_new(void);                                          // fwd (empty NSMutableArray)
static void *machold_cfstr_components(void *self, const char *cmd, void *sepobj) {
    (void)cmd;
    const char *s = *(const char **)((char *)self + 16);
    const char *sep = sepobj ? *(const char **)((char *)sepobj + 16) : NULL;
    void *arr = machold_arr_new();
    if (!s) return arr;
    size_t sl = sep ? strlen(sep) : 0;
    if (!sl) { machold_arr_addObject(arr, "addObject:", machold_make_string(s, (long)strlen(s))); return arr; }
    const char *p = s, *hit;
    while ((hit = strstr(p, sep))) {
        machold_arr_addObject(arr, "addObject:", machold_make_string(p, hit - p));
        p = hit + sl;
    }
    machold_arr_addObject(arr, "addObject:", machold_make_string(p, (long)strlen(p)));
    return arr;
}
static machold_mlist_t machold_cfstring_methods;
static machold_class_ro_t machold_cfstring_ro, machold_cfstring_meta_ro;
static int machold_cfstring_inited = 0;
static void machold_init_nsstring(void);   // fwd (wires the NSString metaclass methods)
static void *machold_format_to_string(void *fmtobj, uint64_t *va);   // fwd (format walker)
static void *machold_cfstr_alloc(void *cls, const char *cmd) { (void)cls; (void)cmd; return machold_make_string("", 0); }
// -initWithFormat:arguments: — Darwin va_list is a char* to the packed stack args → uint64_t*.
static void *machold_str_initFormatArgs(void *self, const char *cmd, void *fmt, void *va) {
    (void)self; (void)cmd; return machold_format_to_string(fmt, (uint64_t *)va);
}
static void machold_init_cfstring(void) {
    if (machold_cfstring_inited) return; machold_cfstring_inited = 1;
    machold_method_t m[] = {
        {"initWithFormat:arguments:", "@32@0:8@16^v24", (void *)machold_str_initFormatArgs},
        {"length", "Q16@0:8", (void *)machold_cfstr_length},
        {"count", "Q16@0:8", (void *)machold_cfstr_length},
        {"UTF8String", "*16@0:8", (void *)machold_cfstr_utf8},
        {"cString", "*16@0:8", (void *)machold_cfstr_utf8},
        {"stringByAppendingString:", "@24@0:8@16", (void *)machold_cfstr_append},
        {"isEqualToString:", "c24@0:8@16", (void *)machold_cfstr_isEqual},
        {"isEqual:", "c24@0:8@16", (void *)machold_cfstr_isEqual},
        {"hasPrefix:", "c24@0:8@16", (void *)machold_cfstr_hasPrefix},
        {"hasSuffix:", "c24@0:8@16", (void *)machold_cfstr_hasSuffix},
        {"containsString:", "c24@0:8@16", (void *)machold_cfstr_contains},
        {"rangeOfString:", "{_NSRange=QQ}24@0:8@16", (void *)machold_cfstr_rangeOf},
        {"compare:options:range:locale:", "q56@0:8@16Q24{_NSRange=QQ}32@48", (void *)machold_cfstr_compareOpts},
        {"stringByExpandingTildeInPath", "@16@0:8", (void *)machold_cfstr_expandTilde},
        {"stringByStandardizingPath", "@16@0:8", (void *)machold_cfstr_expandTilde},
        {"stringByAppendingPathExtension:", "@24@0:8@16", (void *)machold_cfstr_appendPathExt},
        {"lastPathComponent", "@16@0:8", (void *)machold_cfstr_lastPathComp},
        {"uppercaseString", "@16@0:8", (void *)machold_cfstr_upper},
        {"lowercaseString", "@16@0:8", (void *)machold_cfstr_lower},
        {"substringFromIndex:", "@24@0:8Q16", (void *)machold_cfstr_substrFrom},
        {"componentsSeparatedByString:", "@24@0:8@16", (void *)machold_cfstr_components},
        {"intValue", "i16@0:8", (void *)machold_cfstr_intValue},
        {"integerValue", "q16@0:8", (void *)machold_cfstr_intValue},
        {"doubleValue", "d16@0:8", (void *)machold_cfstr_doubleValue},
        {"dataUsingEncoding:", "@24@0:8Q16", (void *)machold_cfstr_dataUsing},
        {"dataUsingEncoding:allowLossyConversion:", "@28@0:8Q16c24", (void *)machold_cfstr_dataUsingLossy},
        {"stringByTrimmingCharactersInSet:", "@24@0:8@16", (void *)machold_cfstr_trim},
        {"self", "@16@0:8", (void *)machold_ns_self},
        {"description", "@16@0:8", (void *)machold_ns_self},
    };
    machold_cfstring_methods.entsize = sizeof(machold_method_t);
    machold_cfstring_methods.count = sizeof(m) / sizeof(m[0]);
    memcpy(machold_cfstring_methods.methods, m, sizeof(m));
    machold_cfstring_ro.flags = 0x2;           // RO_ROOT
    machold_cfstring_ro.instanceSize = 32;
    machold_cfstring_ro.name = "__NSCFConstantString";
    machold_cfstring_ro.baseMethods = &machold_cfstring_methods;
    machold_cfstring_meta_ro.flags = 0x1 | 0x2;
    machold_cfstring_meta_ro.instanceSize = 40;
    machold_cfstring_meta_ro.name = "__NSCFConstantString";
    machold_cfstring_cls.isa = &machold_cfstring_meta;
    machold_cfstring_cls.superclass = NULL;
    machold_cfstring_cls.data = (uintptr_t)&machold_cfstring_ro;
    machold_cfstring_meta.isa = &machold_cfstring_meta;
    machold_cfstring_meta.superclass = &machold_cfstring_cls;
    machold_cfstring_meta.data = (uintptr_t)&machold_cfstring_meta_ro;
    machold_register_class("NSString", &machold_cfstring_cls);
    machold_register_class("__NSCFConstantString", &machold_cfstring_cls);
    machold_init_nsstring();   // always wire the metaclass class methods (+alloc/+stringWithFormat:…)
}

// ── Messageable NSMutableArray (tier 2, O4) ──────────────────────────────────
// A hand-written messageable collection rooted at our NSObject: instance layout
// {isa@0, void **items@8, long count@16, long cap@24} = 32 B, C-backed (realloc grows,
// leak-tolerant). +alloc is inherited from NSObject's metaclass (class_createInstance
// reads THIS class's instanceSize=32). No real CoreFoundation / class cluster.
static void *machold_arr_init(void *self, const char *cmd) { (void)cmd; return self; }  // calloc'd → empty
static void machold_arr_addObject(void *self, const char *cmd, void *obj) {
    (void)cmd; char *s = (char *)self;
    void **items = *(void ***)(s + 8);
    long count = *(long *)(s + 16), cap = *(long *)(s + 24);
    if (count >= cap) {
        cap = cap ? cap * 2 : 4;
        items = (void **)realloc(items, (size_t)cap * sizeof(void *));
        *(void ***)(s + 8) = items; *(long *)(s + 24) = cap;
    }
    items[count] = obj; *(long *)(s + 16) = count + 1;
}
static long machold_arr_count(void *self, const char *cmd) { (void)cmd; return *(long *)((char *)self + 16); }
static void *machold_arr_objectAtIndex(void *self, const char *cmd, long i) {
    (void)cmd; long count = *(long *)((char *)self + 16);
    if (i < 0 || i >= count) return NULL;
    return (*(void ***)((char *)self + 8))[i];
}
static void *machold_arr_lastObject(void *self, const char *cmd) {
    (void)cmd; long count = *(long *)((char *)self + 16);
    return count ? (*(void ***)((char *)self + 8))[count - 1] : NULL;
}
static void machold_arr_insertAtIndex(void *self, const char *cmd, void *obj, long idx) {
    (void)cmd; char *s = (char *)self;
    long count = *(long *)(s + 16);
    if (idx < 0 || idx > count) return;
    machold_arr_addObject(self, cmd, NULL);                 // grow by one
    void **items = *(void ***)(s + 8);
    for (long i = count; i > idx; i--) items[i] = items[i - 1];
    items[idx] = obj;
}
static void machold_arr_removeAtIndex(void *self, const char *cmd, long idx) {
    (void)cmd; char *s = (char *)self;
    long count = *(long *)(s + 16);
    if (idx < 0 || idx >= count) return;
    void **items = *(void ***)(s + 8);
    for (long i = idx; i < count - 1; i++) items[i] = items[i + 1];
    *(long *)(s + 16) = count - 1;
}
static void machold_arr_removeLast(void *self, const char *cmd) {
    (void)cmd; long count = *(long *)((char *)self + 16);
    if (count) *(long *)((char *)self + 16) = count - 1;
}
static long machold_arr_indexOf(void *self, const char *cmd, void *obj) {
    (void)cmd; char *s = (char *)self;
    void **items = *(void ***)(s + 8); long count = *(long *)(s + 16);
    for (long i = 0; i < count; i++) if (machold_obj_eq(items[i], obj)) return i;
    return (long)0x7fffffffffffffffL;                       // NSNotFound
}
static long machold_arr_contains(void *self, const char *cmd, void *obj) {
    return machold_arr_indexOf(self, cmd, obj) != (long)0x7fffffffffffffffL;
}
static void *machold_arr_firstObject(void *self, const char *cmd) {
    (void)cmd; long count = *(long *)((char *)self + 16);
    return count ? (*(void ***)((char *)self + 8))[0] : NULL;
}
static unsigned long machold_arr_fastEnum(void *self, const char *cmd, void *st, void *buf, unsigned long len) {
    (void)cmd; (void)buf; (void)len;
    return machold_fastenum((unsigned long *)st, *(void ***)((char *)self + 8), *(long *)((char *)self + 16));
}
static void machold_arr_enumBlock(void *self, const char *cmd, void *block) {
    (void)cmd; machold_enum_block_over(*(void ***)((char *)self + 8), *(long *)((char *)self + 16), block);
}
// sortUsingComparator: a comparator block ^NSComparisonResult(id, id). qsort_r calls the
// block's invoke per pair.
static int machold_cmp_block(const void *pa, const void *pb, void *blk) {
    long (*fn)(void *, void *, void *) = *(long (**)(void *, void *, void *))((char *)blk + 16);
    long r = fn(blk, *(void **)pa, *(void **)pb);
    return r < 0 ? -1 : (r > 0 ? 1 : 0);
}
static void machold_arr_sortComparator(void *self, const char *cmd, void *block) {
    (void)cmd; if (!block) return;
    qsort_r(*(void ***)((char *)self + 8), (size_t)*(long *)((char *)self + 16), sizeof(void *),
            machold_cmp_block, block);
}
// sortedArrayUsingFunction:context: — a C comparator fn(id,id,ctx)→NSInteger. Returns a new
// sorted array (leaves self unchanged).
struct machold_cmpfn_pack { long (*fn)(void *, void *, void *); void *ctx; };
static int machold_cmp_fn(const void *pa, const void *pb, void *arg) {
    struct machold_cmpfn_pack *p = (struct machold_cmpfn_pack *)arg;
    long r = p->fn(*(void **)pa, *(void **)pb, p->ctx);
    return r < 0 ? -1 : (r > 0 ? 1 : 0);
}
static void *machold_arr_new(void);   // fwd
static void *machold_arr_sortedFn(void *self, const char *cmd, void *cmpfn, void *ctx) {
    (void)cmd;
    void *out = machold_arr_new();
    long n = *(long *)((char *)self + 16); void **items = *(void ***)((char *)self + 8);
    for (long i = 0; i < n; i++) machold_arr_addObject(out, "addObject:", items[i]);
    struct machold_cmpfn_pack pk = { (long (*)(void *, void *, void *))cmpfn, ctx };
    if (cmpfn) qsort_r(*(void ***)((char *)out + 8), (size_t)*(long *)((char *)out + 16), sizeof(void *), machold_cmp_fn, &pk);
    return out;
}
static void *machold_arr_mutableCopy(void *self, const char *cmd) {
    (void)cmd; void *m = machold_arr_new();
    void **items = *(void ***)((char *)self + 8); long c = *(long *)((char *)self + 16);
    for (long i = 0; i < c; i++) machold_arr_addObject(m, "addObject:", items[i]);
    return m;
}
static void *machold_arr_joined(void *self, const char *cmd, void *sepobj) {
    (void)cmd; char *s = (char *)self;
    void **items = *(void ***)(s + 8); long count = *(long *)(s + 16);
    const char *sep = sepobj ? *(const char **)((char *)sepobj + 16) : "";
    size_t sl = strlen(sep), total = 0;
    for (long i = 0; i < count; i++) {
        if (items[i] && *(void **)items[i] == &machold_cfstring_cls) total += (size_t)*(long *)((char *)items[i] + 24);
        if (i) total += sl;
    }
    char *buf = (char *)malloc(total + 1); buf[0] = 0; size_t at = 0;
    for (long i = 0; i < count; i++) {
        if (i && sl) { memcpy(buf + at, sep, sl); at += sl; }
        if (items[i] && *(void **)items[i] == &machold_cfstring_cls) {
            const char *e = *(const char **)((char *)items[i] + 16); long el = *(long *)((char *)items[i] + 24);
            memcpy(buf + at, e, (size_t)el); at += (size_t)el;
        }
    }
    buf[at] = 0; void *r = machold_make_string(buf, (long)at); free(buf); return r;
}
static machold_mlist_t machold_nsarray_methods;
static machold_class_ro_t machold_nsarray_ro, machold_nsarray_meta_ro;
static machold_class_t machold_nsarray_cls, machold_nsarray_meta;
static machold_mlist_t machold_nsarray_cmethods;
static int machold_nsarray_inited = 0;
static void machold_init_nsarray(void);   // fwd
// Empty NSMutableArray for internal producers (componentsSeparatedByString:).
static void *machold_arr_new(void) { machold_init_nsarray(); return machold_class_createInstance((uint8_t *)&machold_nsarray_cls, 0); }
static void *machold_arr_cls_new(void *cls, const char *cmd) { (void)cls; (void)cmd; return machold_arr_new(); }
static void *machold_arr_withObject(void *cls, const char *cmd, void *o) {
    (void)cls; (void)cmd; void *a = machold_arr_new(); if (o) machold_arr_addObject(a, "addObject:", o); return a;
}
static void *machold_arr_withObjectsCount(void *cls, const char *cmd, void **objs, unsigned long n) {
    (void)cls; (void)cmd; void *a = machold_arr_new();
    for (unsigned long i = 0; objs && i < n; i++) machold_arr_addObject(a, "addObject:", objs[i]);
    return a;
}
static void machold_init_nsarray(void) {
    if (machold_nsarray_inited) return; machold_nsarray_inited = 1;
    machold_init_nsobject();                                // roots at NSObject
    machold_method_t m[] = {
        {"init", "@16@0:8", (void *)machold_arr_init},
        {"addObject:", "v24@0:8@16", (void *)machold_arr_addObject},
        {"count", "Q16@0:8", (void *)machold_arr_count},
        {"objectAtIndex:", "@24@0:8Q16", (void *)machold_arr_objectAtIndex},
        {"objectAtIndexedSubscript:", "@24@0:8Q16", (void *)machold_arr_objectAtIndex},
        {"lastObject", "@16@0:8", (void *)machold_arr_lastObject},
        {"firstObject", "@16@0:8", (void *)machold_arr_firstObject},
        {"insertObject:atIndex:", "v32@0:8@16Q24", (void *)machold_arr_insertAtIndex},
        {"removeObjectAtIndex:", "v24@0:8Q16", (void *)machold_arr_removeAtIndex},
        {"removeLastObject", "v16@0:8", (void *)machold_arr_removeLast},
        {"containsObject:", "c24@0:8@16", (void *)machold_arr_contains},
        {"indexOfObject:", "Q24@0:8@16", (void *)machold_arr_indexOf},
        {"componentsJoinedByString:", "@24@0:8@16", (void *)machold_arr_joined},
        {"countByEnumeratingWithState:objects:count:", "Q40@0:8^v16^@24Q32", (void *)machold_arr_fastEnum},
        {"enumerateObjectsUsingBlock:", "v24@0:8@?16", (void *)machold_arr_enumBlock},
        {"sortUsingComparator:", "v24@0:8@?16", (void *)machold_arr_sortComparator},
        {"sortedArrayUsingFunction:context:", "@32@0:8^?16^v24", (void *)machold_arr_sortedFn},
        {"mutableCopy", "@16@0:8", (void *)machold_arr_mutableCopy},
        {"copy", "@16@0:8", (void *)machold_ns_self},
        {"description", "@16@0:8", (void *)machold_obj_description},
    };
    machold_nsarray_methods.entsize = sizeof(machold_method_t);
    machold_nsarray_methods.count = sizeof(m) / sizeof(m[0]);
    memcpy(machold_nsarray_methods.methods, m, sizeof(m));
    machold_nsarray_ro.flags = 0;              // NOT root → -retain/-release fall through to NSObject
    machold_nsarray_ro.instanceSize = 32;      // {isa, items, count, cap}
    machold_nsarray_ro.name = "NSMutableArray";
    machold_nsarray_ro.baseMethods = &machold_nsarray_methods;
    machold_method_t cm[] = {
        {"array", "@16#0:8", (void *)machold_arr_cls_new},
        {"arrayWithObject:", "@24#0:8@16", (void *)machold_arr_withObject},
        {"arrayWithObjects:count:", "@32#0:8^@16Q24", (void *)machold_arr_withObjectsCount},
    };
    machold_nsarray_cmethods.entsize = sizeof(machold_method_t);
    machold_nsarray_cmethods.count = sizeof(cm) / sizeof(cm[0]);
    memcpy(machold_nsarray_cmethods.methods, cm, sizeof(cm));
    machold_nsarray_meta_ro.flags = 0x1;       // RO_META
    machold_nsarray_meta_ro.instanceSize = 40;
    machold_nsarray_meta_ro.name = "NSMutableArray";
    machold_nsarray_meta_ro.baseMethods = &machold_nsarray_cmethods;
    machold_nsarray_cls.isa = &machold_nsarray_meta;
    machold_nsarray_cls.superclass = &machold_nsobj_cls;        // NSObject (for +alloc, -retain…)
    machold_nsarray_cls.data = (uintptr_t)&machold_nsarray_ro;
    machold_nsarray_meta.isa = &machold_nsobj_meta;
    machold_nsarray_meta.superclass = &machold_nsobj_meta;      // +alloc resolves in NSObject metaclass
    machold_nsarray_meta.data = (uintptr_t)&machold_nsarray_meta_ro;
    machold_register_class("NSMutableArray", &machold_nsarray_cls);
    machold_register_class("NSArray", &machold_nsarray_cls);
}

// ── Messageable NSNumber / constant @N (tier 2, O5) ──────────────────────────
// A `@42` literal is a static NSConstantIntegerNumber {isa@0, encoding@8, long value@16}
// = 24 B (isa bound to _OBJC_CLASS_$_NSConstantIntegerNumber). We provide that class with
// the value accessors reading @16. (Runtime-boxed numbers via +numberWithInt: would use
// the same class + a malloc'd 24-B instance — added if a probe needs it.)
// @8 = type tag for machold-created numbers: 0=int/long, 1=double, 2=bool. Constant @N
// literals instead put the ObjC encoding char here ('q','d',…); we treat tag 1 or 'd'/'f'
// as double and read @16 (long) otherwise.
static int machold_num_is_double(void *self) {
    long t = *(long *)((char *)self + 8); return t == 1 || t == 'd' || t == 'f';
}
static double machold_num_dbl(void *self, const char *cmd) {
    (void)cmd;
    if (machold_num_is_double(self)) { double d; memcpy(&d, (char *)self + 16, 8); return d; }
    return (double)*(long *)((char *)self + 16);
}
static long machold_num_long(void *self, const char *cmd) {
    (void)cmd;
    if (machold_num_is_double(self)) { double d; memcpy(&d, (char *)self + 16, 8); return (long)d; }
    return *(long *)((char *)self + 16);
}
static int  machold_num_int(void *self, const char *cmd)  { return (int)machold_num_long(self, cmd); }
static long machold_num_bool(void *self, const char *cmd) { return machold_num_long(self, cmd) != 0; }
static machold_class_t machold_nsnum_cls;   // fwd (isa for boxed instances)
// Runtime boxing: +numberWithInt:/… create a heap NSNumber {isa, encoding@8, value@16}.
// Split by width: an `int` param reads w2 (the 32-bit arg register, correctly sign-
// extended), a `long` param reads x2 — reading a 32-bit arg as long would take garbage
// high bits.
static void *machold_num_mk(long v) {
    char *o = (char *)calloc(1, 24);
    *(void **)o = &machold_nsnum_cls;   // tag @8 stays 0 (long) from calloc
    *(long *)(o + 16) = v;
    return o;
}
static void *machold_num_mk_double(double d) {
    char *o = (char *)calloc(1, 24);
    *(void **)o = &machold_nsnum_cls; *(long *)(o + 8) = 1; memcpy(o + 16, &d, 8);
    return o;
}
static void *machold_num_mk_bool(int b) {
    char *o = (char *)calloc(1, 24);
    *(void **)o = &machold_nsnum_cls; *(long *)(o + 8) = 2; *(long *)(o + 16) = b ? 1 : 0;
    return o;
}
static void *machold_num_box_int(void *cls, const char *cmd, int v)  { (void)cls; (void)cmd; return machold_num_mk(v); }
static void *machold_num_box_long(void *cls, const char *cmd, long v) { (void)cls; (void)cmd; return machold_num_mk(v); }
static machold_mlist_t machold_nsnum_methods, machold_nsnum_cmethods;
static machold_class_ro_t machold_nsnum_ro, machold_nsnum_meta_ro;
static machold_class_t machold_nsnum_meta;
static int machold_nsnum_inited = 0;
static void machold_init_nsnumber(void) {
    if (machold_nsnum_inited) return; machold_nsnum_inited = 1;
    machold_init_nsobject();
    machold_method_t m[] = {
        {"intValue", "i16@0:8", (void *)machold_num_int},
        {"integerValue", "q16@0:8", (void *)machold_num_long},
        {"longValue", "q16@0:8", (void *)machold_num_long},
        {"longLongValue", "q16@0:8", (void *)machold_num_long},
        {"unsignedIntegerValue", "Q16@0:8", (void *)machold_num_long},
        {"boolValue", "c16@0:8", (void *)machold_num_bool},
        {"doubleValue", "d16@0:8", (void *)machold_num_dbl},
        {"floatValue", "f16@0:8", (void *)machold_num_dbl},
        {"description", "@16@0:8", (void *)machold_obj_description},
        {"stringValue", "@16@0:8", (void *)machold_obj_description},
    };
    machold_nsnum_methods.entsize = sizeof(machold_method_t);
    machold_nsnum_methods.count = sizeof(m) / sizeof(m[0]);
    memcpy(machold_nsnum_methods.methods, m, sizeof(m));
    machold_method_t cm[] = {   // class methods (runtime boxing)
        {"numberWithInt:", "@20#0:8i16", (void *)machold_num_box_int},
        {"numberWithBool:", "@20#0:8c16", (void *)machold_num_box_int},
        {"numberWithInteger:", "@24#0:8q16", (void *)machold_num_box_long},
        {"numberWithLong:", "@24#0:8q16", (void *)machold_num_box_long},
        {"numberWithUnsignedInteger:", "@24#0:8Q16", (void *)machold_num_box_long},
    };
    machold_nsnum_cmethods.entsize = sizeof(machold_method_t);
    machold_nsnum_cmethods.count = sizeof(cm) / sizeof(cm[0]);
    memcpy(machold_nsnum_cmethods.methods, cm, sizeof(cm));
    machold_nsnum_ro.flags = 0;
    machold_nsnum_ro.instanceSize = 24;
    machold_nsnum_ro.name = "NSNumber";
    machold_nsnum_ro.baseMethods = &machold_nsnum_methods;
    machold_nsnum_meta_ro.flags = 0x1;
    machold_nsnum_meta_ro.instanceSize = 40;
    machold_nsnum_meta_ro.name = "NSNumber";
    machold_nsnum_meta_ro.baseMethods = &machold_nsnum_cmethods;
    machold_nsnum_cls.isa = &machold_nsnum_meta;
    machold_nsnum_cls.superclass = &machold_nsobj_cls;
    machold_nsnum_cls.data = (uintptr_t)&machold_nsnum_ro;
    machold_nsnum_meta.isa = &machold_nsobj_meta;
    machold_nsnum_meta.superclass = &machold_nsobj_meta;
    machold_nsnum_meta.data = (uintptr_t)&machold_nsnum_meta_ro;
    machold_register_class("NSNumber", &machold_nsnum_cls);
}

// ── Messageable NSMutableDictionary (tier 2, O5) ─────────────────────────────
// Instance {isa@0, void** keys@8, void** vals@16, long count@24, long cap@32} = 40 B,
// linear parallel arrays. Keys compared string-aware (our constant/created NSStrings by
// content, else pointer) — covers the NSString-key case, no hashing/-isEqual: plumbing.
static int machold_key_eq(void *a, void *b) {
    if (a == b) return 1;
    if (!a || !b) return 0;
    if (*(void **)a == &machold_cfstring_cls && *(void **)b == &machold_cfstring_cls) {
        const char *sa = *(const char **)((char *)a + 16), *sb = *(const char **)((char *)b + 16);
        return sa && sb && strcmp(sa, sb) == 0;
    }
    return 0;
}
static void *machold_dict_init(void *self, const char *cmd) { (void)cmd; return self; }
static long machold_dict_count(void *self, const char *cmd) { (void)cmd; return *(long *)((char *)self + 24); }
static void *machold_arr_new(void);   // fwd
static void *machold_dict_allKeys(void *self, const char *cmd) {
    (void)cmd; void *arr = machold_arr_new();
    long n = *(long *)((char *)self + 24); void **k = *(void ***)((char *)self + 8);
    for (long i = 0; i < n; i++) machold_arr_addObject(arr, "addObject:", k[i]);
    return arr;
}
static void *machold_dict_allValues(void *self, const char *cmd) {
    (void)cmd; void *arr = machold_arr_new();
    long n = *(long *)((char *)self + 24); void **v = *(void ***)((char *)self + 16);
    for (long i = 0; i < n; i++) machold_arr_addObject(arr, "addObject:", v[i]);
    return arr;
}
static void machold_dict_getObjectsAndKeys(void *self, const char *cmd, void **objs, void **keys, unsigned long count) {
    (void)cmd;
    long n = *(long *)((char *)self + 24);
    void **k = *(void ***)((char *)self + 8); void **v = *(void ***)((char *)self + 16);
    if ((long)count < n) n = (long)count;
    for (long i = 0; i < n; i++) { if (objs) objs[i] = v[i]; if (keys) keys[i] = k[i]; }
}
static void *machold_dict_objectForKey(void *self, const char *cmd, void *key) {
    (void)cmd; char *s = (char *)self;
    void **keys = *(void ***)(s + 8), **vals = *(void ***)(s + 16);
    long count = *(long *)(s + 24);
    for (long i = 0; i < count; i++) if (machold_key_eq(keys[i], key)) return vals[i];
    return NULL;
}
static machold_class_t machold_nsdict_cls, machold_nsdict_meta;   // fwd (for +dictionary)
static void *machold_dict_new(void *cls, const char *cmd) {
    (void)cls; (void)cmd; return machold_class_createInstance((uint8_t *)&machold_nsdict_cls, 0);
}
static void machold_dict_enumBlock(void *self, const char *cmd, void *block) {
    (void)cmd; if (!block) return;
    void (*invoke)(void *, void *, void *, char *) = *(void (**)(void *, void *, void *, char *))((char *)block + 16);
    char *s = (char *)self; void **keys = *(void ***)(s + 8), **vals = *(void ***)(s + 16);
    long count = *(long *)(s + 24); char stop = 0;
    for (long i = 0; i < count && !stop; i++) invoke(block, keys[i], vals[i], &stop);
}
static void machold_dict_setObjectForKey(void *self, const char *cmd, void *obj, void *key) {
    (void)cmd; char *s = (char *)self;
    void **keys = *(void ***)(s + 8), **vals = *(void ***)(s + 16);
    long count = *(long *)(s + 24), cap = *(long *)(s + 32);
    for (long i = 0; i < count; i++) if (machold_key_eq(keys[i], key)) { vals[i] = obj; return; }
    if (count >= cap) {
        cap = cap ? cap * 2 : 4;
        keys = (void **)realloc(keys, (size_t)cap * sizeof(void *));
        vals = (void **)realloc(vals, (size_t)cap * sizeof(void *));
        *(void ***)(s + 8) = keys; *(void ***)(s + 16) = vals; *(long *)(s + 32) = cap;
    }
    keys[count] = key; vals[count] = obj; *(long *)(s + 24) = count + 1;
}
static machold_mlist_t machold_nsdict_methods, machold_nsdict_cmethods;
static machold_class_ro_t machold_nsdict_ro, machold_nsdict_meta_ro;
static int machold_nsdict_inited = 0;
static void machold_init_nsdict(void) {
    if (machold_nsdict_inited) return; machold_nsdict_inited = 1;
    machold_init_nsobject();
    machold_method_t m[] = {
        {"init", "@16@0:8", (void *)machold_dict_init},
        {"count", "Q16@0:8", (void *)machold_dict_count},
        {"objectForKey:", "@24@0:8@16", (void *)machold_dict_objectForKey},
        {"allKeys", "@16@0:8", (void *)machold_dict_allKeys},
        {"allValues", "@16@0:8", (void *)machold_dict_allValues},
        {"getObjects:andKeys:count:", "v40@0:8^@16^@24Q32", (void *)machold_dict_getObjectsAndKeys},
        {"objectForKeyedSubscript:", "@24@0:8@16", (void *)machold_dict_objectForKey},
        {"setObject:forKey:", "v32@0:8@16@24", (void *)machold_dict_setObjectForKey},
        {"setObject:forKeyedSubscript:", "v32@0:8@16@24", (void *)machold_dict_setObjectForKey},
        {"enumerateKeysAndObjectsUsingBlock:", "v24@0:8@?16", (void *)machold_dict_enumBlock},
        {"description", "@16@0:8", (void *)machold_obj_description},
    };
    machold_method_t cm[] = {
        {"dictionary", "@16#0:8", (void *)machold_dict_new},
    };
    machold_nsdict_methods.entsize = sizeof(machold_method_t);
    machold_nsdict_methods.count = sizeof(m) / sizeof(m[0]);
    memcpy(machold_nsdict_methods.methods, m, sizeof(m));
    machold_nsdict_cmethods.entsize = sizeof(machold_method_t);
    machold_nsdict_cmethods.count = sizeof(cm) / sizeof(cm[0]);
    memcpy(machold_nsdict_cmethods.methods, cm, sizeof(cm));
    machold_nsdict_ro.flags = 0;
    machold_nsdict_ro.instanceSize = 40;
    machold_nsdict_ro.name = "NSMutableDictionary";
    machold_nsdict_ro.baseMethods = &machold_nsdict_methods;
    machold_nsdict_meta_ro.flags = 0x1;
    machold_nsdict_meta_ro.instanceSize = 40;
    machold_nsdict_meta_ro.name = "NSMutableDictionary";
    machold_nsdict_meta_ro.baseMethods = &machold_nsdict_cmethods;
    machold_nsdict_cls.isa = &machold_nsdict_meta;
    machold_nsdict_cls.superclass = &machold_nsobj_cls;
    machold_nsdict_cls.data = (uintptr_t)&machold_nsdict_ro;
    machold_nsdict_meta.isa = &machold_nsobj_meta;
    machold_nsdict_meta.superclass = &machold_nsobj_meta;
    machold_nsdict_meta.data = (uintptr_t)&machold_nsdict_meta_ro;
    machold_register_class("NSMutableDictionary", &machold_nsdict_cls);
    machold_register_class("NSDictionary", &machold_nsdict_cls);
}

// ── Variadic printf shims (Darwin stack-varargs → glibc register-varargs) ────
// Darwin arm64 passes ALL variadic args on the stack; glibc/AAPCS reads them from
// x1-x7/v0-v7 then the stack. So a Darwin `printf(fmt, 42)` (fmt in x0, 42 at [sp])
// misprints under glibc printf (reads 42 from x1). Each shim captures the caller sp
// (= &first vararg) BEFORE touching the stack, builds an AAPCS64 va_list with both
// register offsets exhausted (__gr_offs = __vr_offs = 0 → all args from __stack), and
// tail-calls the glibc v* variant. va_list = {__stack@0, __gr_top@8, __vr_top@16,
// __gr_offs@24, __vr_offs@28}. Fixed args stay in their registers unchanged.
#define MACHOLD_VA_TRAMP(NAME, VFN, VAREG)     \
    extern void NAME(void);                    \
    __asm__(".text\n.globl " #NAME "\n.p2align 2\n" #NAME ":\n"  \
        "    mov  x9, sp\n"                     \
        "    sub  sp, sp, #0x30\n"             \
        "    stp  x29, x30, [sp, #0x20]\n"     \
        "    add  x29, sp, #0x20\n"            \
        "    str  x9,  [sp, #0]\n"             \
        "    str  xzr, [sp, #8]\n"             \
        "    str  xzr, [sp, #16]\n"            \
        "    str  wzr, [sp, #24]\n"            \
        "    str  wzr, [sp, #28]\n"            \
        "    add  " VAREG ", sp, #0\n"         \
        "    bl   " #VFN "\n"                  \
        "    ldp  x29, x30, [sp, #0x20]\n"     \
        "    add  sp, sp, #0x30\n"             \
        "    ret\n")
MACHOLD_VA_TRAMP(machold_printf,   vprintf,   "x1");  // printf(fmt=x0, …)
MACHOLD_VA_TRAMP(machold_sprintf,  vsprintf,  "x2");  // sprintf(buf=x0, fmt=x1, …)
MACHOLD_VA_TRAMP(machold_snprintf, vsnprintf, "x3");  // snprintf(buf=x0, size=x1, fmt=x2, …)

// ── NSLog (tier 2, O7) ───────────────────────────────────────────────────────
// void NSLog(NSString *format, ...). The format is an NSString* (arg0), the rest are
// Darwin stack-varargs (one 8-byte slot each, ints AND doubles). We walk the format's
// UTF8, pulling one slot per conversion; %@ formats an object (our NSString → its bytes,
// else "<Class: ptr>"). Writes the message + newline to stderr (no NSLog timestamp prefix
// — the clock is wrong under machold anyway).
// Core format walker: writes the formatted output (no trailing newline) to `out`. Shared
// by NSLog (→stderr) and stringWithFormat:/appendFormat: (→a memstream, then an NSString).
static void machold_format_stream(FILE *out, void *fmtobj, uint64_t *va) {
    const char *f = (fmtobj && *(void **)fmtobj == &machold_cfstring_cls)
                        ? *(const char **)((char *)fmtobj + 16) : "(null format)";
    int ai = 0;
    for (const char *p = f; *p; p++) {
        if (*p != '%') { fputc(*p, out); continue; }
        p++;
        if (*p == '%') { fputc('%', out); continue; }
        while (*p && strchr("-+ #0123456789.", *p)) p++;   // skip flags/width/precision
        int lng = 0;
        while (*p == 'l') { lng++; p++; }
        if (*p == 'z' || *p == 'q') { lng = 2; p++; }
        char c = *p;
        switch (c) {
        case '@': {
            void *o = (void *)va[ai++];
            if (o && *(void **)o == &machold_cfstring_cls) fputs(*(const char **)((char *)o + 16), out);
            else if (o) { uintptr_t d = *(uintptr_t *)((char *)o + 32) & ~(uintptr_t)0x7;
                          fprintf(out, "<%s: %p>", d ? *(const char **)(d + 24) : "?", o); }
            else fputs("(null)", out);
            break; }
        case 'd': case 'i':
            if (lng >= 2) fprintf(out, "%lld", (long long)va[ai++]);
            else if (lng == 1) fprintf(out, "%ld", (long)va[ai++]);
            else fprintf(out, "%d", (int)va[ai++]);
            break;
        case 'u': if (lng) fprintf(out, "%lu", (unsigned long)va[ai++]); else fprintf(out, "%u", (unsigned)va[ai++]); break;
        case 'x': if (lng) fprintf(out, "%lx", (unsigned long)va[ai++]); else fprintf(out, "%x", (unsigned)va[ai++]); break;
        case 'p': fprintf(out, "%p", (void *)va[ai++]); break;
        case 's': fprintf(out, "%s", (char *)va[ai++]); break;
        case 'c': fprintf(out, "%c", (int)va[ai++]); break;
        case 'f': case 'g': case 'e': { union { uint64_t u; double d; } x; x.u = va[ai++]; fprintf(out, "%g", x.d); break; }
        default: fputc('%', out); if (c) fputc(c, out); break;
        }
    }
}
__attribute__((used)) void machold_nslog_impl(void *fmtobj, uint64_t *va) {
    machold_format_stream(stderr, fmtobj, va);
    fputc('\n', stderr);
}
// Format into a fresh NSString (our layout) via open_memstream. Used by the variadic
// string methods below.
static void *machold_format_to_string(void *fmtobj, uint64_t *va) {
    char *buf = NULL; size_t sz = 0;
    FILE *ms = open_memstream(&buf, &sz);
    if (!ms) return machold_make_string("", 0);
    machold_format_stream(ms, fmtobj, va);
    fclose(ms);
    void *r = machold_make_string(buf, (long)sz);
    free(buf);
    return r;
}
extern void machold_nslog(void);
__asm__(
    ".text\n.globl machold_nslog\n.p2align 2\nmachold_nslog:\n"
    "    mov  x9, sp\n"                 // &first vararg (Darwin stack)
    "    stp  x29, x30, [sp, #-0x10]!\n"
    "    mov  x29, sp\n"
    "    mov  x1, x9\n"                 // va pointer (x0 = format NSString*, unchanged)
    "    bl   machold_nslog_impl\n"
    "    ldp  x29, x30, [sp], #0x10\n"
    "    ret\n");

// ── NSString class methods + NSMutableString (tier 2, O9) ────────────────────
// +[NSString stringWithFormat:] is variadic: x0=cls, x1=SEL, x2=format, varargs at [sp].
// The naked IMP captures sp (varargs) and calls the C formatter, which builds an NSString.
__attribute__((used)) void *machold_str_format_impl(void *fmtobj, uint64_t *va) {
    return machold_format_to_string(fmtobj, va);
}
extern void machold_str_format(void);
__asm__(
    ".text\n.globl machold_str_format\n.p2align 2\nmachold_str_format:\n"
    "    mov  x9, sp\n"
    "    stp  x29, x30, [sp, #-0x10]!\n"
    "    mov  x29, sp\n"
    "    mov  x0, x2\n"                 // format NSString*
    "    mov  x1, x9\n"                 // va
    "    bl   machold_str_format_impl\n"
    "    ldp  x29, x30, [sp], #0x10\n"
    "    ret\n");
static void *machold_str_withUTF8(void *cls, const char *cmd, const char *cstr) {
    (void)cls; (void)cmd; return machold_make_string(cstr, cstr ? (long)strlen(cstr) : 0);
}
static machold_mlist_t machold_cfstring_cmethods;
static int machold_nsstring_inited = 0;
static void machold_init_nsstring(void) {   // adds class methods to the NSString metaclass
    machold_init_cfstring();
    if (machold_nsstring_inited) return; machold_nsstring_inited = 1;
    machold_method_t cm[] = {
        {"stringWithFormat:", "@24#0:8@16", (void *)machold_str_format},
        {"stringWithUTF8String:", "@24#0:8*16", (void *)machold_str_withUTF8},
        {"string", "@16#0:8", (void *)machold_str_withUTF8},   // +string → empty (cstr=nil → "")
        {"alloc", "@16#0:8", (void *)machold_cfstr_alloc},     // → empty string; -initWithFormat:… fills it
    };
    machold_cfstring_cmethods.entsize = sizeof(machold_method_t);
    machold_cfstring_cmethods.count = sizeof(cm) / sizeof(cm[0]);
    memcpy(machold_cfstring_cmethods.methods, cm, sizeof(cm));
    machold_cfstring_meta_ro.baseMethods = &machold_cfstring_cmethods;
    machold_register_class("NSString", &machold_cfstring_cls);
}

// NSMutableString: growable string {isa@0, flags@8, char* str@16, long len@24, long cap@32}
// = 40 B. Read accessors (length/UTF8String/append) reuse the cfstring imps (same @16/@24);
// mutation grows the malloc'd buffer.
static void machold_mstr_ensure(char *s, long need) {
    long cap = *(long *)(s + 32);
    if (need + 1 > cap) {
        cap = (need + 1 > cap * 2) ? need + 1 : cap * 2;
        char *b = (char *)realloc(*(char **)(s + 16), (size_t)cap);
        *(char **)(s + 16) = b; *(long *)(s + 32) = cap;
    }
}
static void machold_mstr_appendBytes(void *self, const char *b, long bl) {
    char *s = (char *)self; long len = *(long *)(s + 24);
    machold_mstr_ensure(s, len + bl);
    char *buf = *(char **)(s + 16);
    memcpy(buf + len, b, (size_t)bl); buf[len + bl] = 0; *(long *)(s + 24) = len + bl;
}
static void *machold_mstr_init(void *self, const char *cmd) {
    (void)cmd; char *s = (char *)self;
    if (!*(char **)(s + 16)) { char *b = (char *)malloc(1); b[0] = 0; *(char **)(s + 16) = b; *(long *)(s + 32) = 1; }
    return self;
}
static void machold_mstr_appendString(void *self, const char *cmd, void *other) {
    (void)cmd; if (!other) return;
    machold_mstr_appendBytes(self, *(const char **)((char *)other + 16), *(long *)((char *)other + 24));
}
static void machold_mstr_setString(void *self, const char *cmd, void *other) {
    (void)cmd; char *s = (char *)self;
    *(long *)(s + 24) = 0; if (*(char **)(s + 16)) (*(char **)(s + 16))[0] = 0;
    machold_mstr_appendString(self, cmd, other);
}
__attribute__((used)) void machold_mstr_appendFormat_impl(void *self, void *fmtobj, uint64_t *va) {
    char *buf = NULL; size_t sz = 0;
    FILE *ms = open_memstream(&buf, &sz);
    if (!ms) return;
    machold_format_stream(ms, fmtobj, va);
    fclose(ms);
    machold_mstr_appendBytes(self, buf, (long)sz);
    free(buf);
}
extern void machold_mstr_appendFormat(void);   // x0=self, x1=SEL, x2=format, varargs at [sp]
__asm__(
    ".text\n.globl machold_mstr_appendFormat\n.p2align 2\nmachold_mstr_appendFormat:\n"
    "    mov  x9, sp\n"
    "    stp  x29, x30, [sp, #-0x10]!\n"
    "    mov  x29, sp\n"
    "    mov  x1, x2\n"                 // format (x0=self stays)
    "    mov  x2, x9\n"                 // va
    "    bl   machold_mstr_appendFormat_impl\n"
    "    ldp  x29, x30, [sp], #0x10\n"
    "    ret\n");
static machold_class_t machold_mstr_cls, machold_mstr_meta;
static void *machold_mstr_new(void *cls, const char *cmd) {   // +string
    (void)cls; (void)cmd;
    void *o = machold_class_createInstance((uint8_t *)&machold_mstr_cls, 0);
    return machold_mstr_init(o, "init");
}
static machold_mlist_t machold_mstr_methods, machold_mstr_cmethods;
static machold_class_ro_t machold_mstr_ro, machold_mstr_meta_ro;
static int machold_mstr_inited = 0;
static void machold_init_nsmutstr(void) {
    if (machold_mstr_inited) return; machold_mstr_inited = 1;
    machold_init_cfstring();   // for machold_cfstring_cls (append returns a cfstring) + accessors
    machold_method_t m[] = {
        {"init", "@16@0:8", (void *)machold_mstr_init},
        {"length", "Q16@0:8", (void *)machold_cfstr_length},
        {"count", "Q16@0:8", (void *)machold_cfstr_length},
        {"UTF8String", "*16@0:8", (void *)machold_cfstr_utf8},
        {"appendString:", "v24@0:8@16", (void *)machold_mstr_appendString},
        {"appendFormat:", "v24@0:8@16", (void *)machold_mstr_appendFormat},
        {"setString:", "v24@0:8@16", (void *)machold_mstr_setString},
        {"stringByAppendingString:", "@24@0:8@16", (void *)machold_cfstr_append},
        {"isEqualToString:", "c24@0:8@16", (void *)machold_cfstr_isEqual},
        {"isEqual:", "c24@0:8@16", (void *)machold_cfstr_isEqual},
        {"self", "@16@0:8", (void *)machold_ns_self},
    };
    machold_method_t cm[] = {
        {"string", "@16#0:8", (void *)machold_mstr_new},
    };
    machold_mstr_methods.entsize = sizeof(machold_method_t);
    machold_mstr_methods.count = sizeof(m) / sizeof(m[0]);
    memcpy(machold_mstr_methods.methods, m, sizeof(m));
    machold_mstr_cmethods.entsize = sizeof(machold_method_t);
    machold_mstr_cmethods.count = sizeof(cm) / sizeof(cm[0]);
    memcpy(machold_mstr_cmethods.methods, cm, sizeof(cm));
    machold_mstr_ro.flags = 0;
    machold_mstr_ro.instanceSize = 40;
    machold_mstr_ro.name = "NSMutableString";
    machold_mstr_ro.baseMethods = &machold_mstr_methods;
    machold_mstr_meta_ro.flags = 0x1;
    machold_mstr_meta_ro.instanceSize = 40;
    machold_mstr_meta_ro.name = "NSMutableString";
    machold_mstr_meta_ro.baseMethods = &machold_mstr_cmethods;
    machold_mstr_cls.isa = &machold_mstr_meta;
    machold_mstr_cls.superclass = &machold_nsobj_cls;
    machold_mstr_cls.data = (uintptr_t)&machold_mstr_ro;
    machold_mstr_meta.isa = &machold_nsobj_meta;
    machold_mstr_meta.superclass = &machold_nsobj_meta;
    machold_mstr_meta.data = (uintptr_t)&machold_mstr_meta_ro;
    machold_register_class("NSMutableString", &machold_mstr_cls);
}

// ── NSData (tier 2, O10) ─────────────────────────────────────────────────────
// {isa@0, void* bytes@8, long len@16} = 24 B, owning a copy of the bytes. Produced by
// -[NSString dataUsingEncoding:] and +dataWithBytes:length:.
static machold_class_t machold_nsdata_cls, machold_nsdata_meta;
static void *machold_make_data(const void *bytes, long len) {
    void machold_init_nsdata(void); machold_init_nsdata();
    if (len < 0) len = 0;
    char *o = (char *)calloc(1, 24);
    *(void **)o = &machold_nsdata_cls;
    void *b = malloc((size_t)(len ? len : 1));
    if (bytes) memcpy(b, bytes, (size_t)len);
    *(void **)(o + 8) = b; *(long *)(o + 16) = len;
    return o;
}
static long machold_data_length(void *self, const char *cmd) { (void)cmd; return *(long *)((char *)self + 16); }
static const void *machold_data_bytes(void *self, const char *cmd) { (void)cmd; return *(void **)((char *)self + 8); }
static void *machold_data_withBytes(void *cls, const char *cmd, const void *bytes, long len) {
    (void)cls; (void)cmd; return machold_make_data(bytes, len);
}
// Bytes+len of an NSData that may be machold-native (type 4) OR a real Linux Swift/CF NSData
// (from the from_file/from_bytes bridge). Lets machold's serializers/writeData consume both.
static const void *machold_nsdata_ptr(void *data, long *outlen) {
    if (!data) { if (outlen) *outlen = 0; return NULL; }
    if (machold_obj_type(data) == 4) { if (outlen) *outlen = *(long *)((char *)data + 16); return *(void **)((char *)data + 8); }
    const void *(*gp)(void *) = (const void *(*)(void *))dlsym(RTLD_DEFAULT, "CFDataGetBytePtr");
    long (*gl)(void *) = (long (*)(void *))dlsym(RTLD_DEFAULT, "CFDataGetLength");
    if (outlen) *outlen = gl ? gl(data) : 0;
    return gp ? gp(data) : NULL;
}
// +dataWithContentsOfFile: returns a REAL Linux NSData (so a hybrid tool's `as Data` cast
// works). machold reads it back via machold_nsdata_ptr.
static void *machold_data_withFile(void *cls, const char *cmd, void *path) {
    (void)cls; (void)cmd;
    const char *p = path ? *(const char **)((char *)path + 16) : NULL;
    if (!p) return NULL;
    void *(*fn)(const char *) = (void *(*)(const char *))dlsym(RTLD_DEFAULT, "machold_fusion_data_from_file");
    return fn ? fn(p) : NULL;
}
static machold_mlist_t machold_nsdata_methods, machold_nsdata_cmethods;
static machold_class_ro_t machold_nsdata_ro, machold_nsdata_meta_ro;
static int machold_nsdata_inited = 0;
void machold_init_nsdata(void) {
    if (machold_nsdata_inited) return; machold_nsdata_inited = 1;
    machold_init_nsobject();
    machold_method_t m[] = {
        {"length", "Q16@0:8", (void *)machold_data_length},
        {"bytes", "^v16@0:8", (void *)machold_data_bytes},
    };
    machold_method_t cm[] = {
        {"dataWithBytes:length:", "@32#0:8^v16Q24", (void *)machold_data_withBytes},
        {"dataWithContentsOfFile:options:error:", "@40#0:8@16Q24^@32", (void *)machold_data_withFile},
        {"dataWithContentsOfFile:", "@24#0:8@16", (void *)machold_data_withFile},
    };
    machold_nsdata_methods.entsize = sizeof(machold_method_t);
    machold_nsdata_methods.count = sizeof(m) / sizeof(m[0]);
    memcpy(machold_nsdata_methods.methods, m, sizeof(m));
    machold_nsdata_cmethods.entsize = sizeof(machold_method_t);
    machold_nsdata_cmethods.count = sizeof(cm) / sizeof(cm[0]);
    memcpy(machold_nsdata_cmethods.methods, cm, sizeof(cm));
    machold_nsdata_ro.flags = 0; machold_nsdata_ro.instanceSize = 24;
    machold_nsdata_ro.name = "NSData"; machold_nsdata_ro.baseMethods = &machold_nsdata_methods;
    machold_nsdata_meta_ro.flags = 0x1; machold_nsdata_meta_ro.instanceSize = 40;
    machold_nsdata_meta_ro.name = "NSData"; machold_nsdata_meta_ro.baseMethods = &machold_nsdata_cmethods;
    machold_nsdata_cls.isa = &machold_nsdata_meta; machold_nsdata_cls.superclass = &machold_nsobj_cls;
    machold_nsdata_cls.data = (uintptr_t)&machold_nsdata_ro;
    machold_nsdata_meta.isa = &machold_nsobj_meta; machold_nsdata_meta.superclass = &machold_nsobj_meta;
    machold_nsdata_meta.data = (uintptr_t)&machold_nsdata_meta_ro;
    machold_register_class("NSData", &machold_nsdata_cls);
    machold_register_class("NSMutableData", &machold_nsdata_cls);
}

// ── NSConstantArray (@[…] literal) (tier 2, O10) ─────────────────────────────
// A `@[…]` literal is a static {isa@0, long count@8, id* objects@16} (objects → a C array
// of the element pointers, in __objc_arraydata). Read-only; fast-enum returns the C array.
static long machold_carr_count(void *self, const char *cmd) { (void)cmd; return *(long *)((char *)self + 8); }
static void **machold_carr_items(void *self) { return *(void ***)((char *)self + 16); }
static void *machold_carr_objAt(void *self, const char *cmd, long i) {
    (void)cmd; long c = *(long *)((char *)self + 8);
    return (i >= 0 && i < c) ? machold_carr_items(self)[i] : NULL;
}
static void *machold_carr_first(void *self, const char *cmd) {
    (void)cmd; long c = *(long *)((char *)self + 8); return c ? machold_carr_items(self)[0] : NULL;
}
static void *machold_carr_last(void *self, const char *cmd) {
    (void)cmd; long c = *(long *)((char *)self + 8); return c ? machold_carr_items(self)[c - 1] : NULL;
}
static long machold_carr_indexOf(void *self, const char *cmd, void *o) {
    (void)cmd; long c = *(long *)((char *)self + 8); void **it = machold_carr_items(self);
    for (long i = 0; i < c; i++) if (machold_obj_eq(it[i], o)) return i;
    return (long)0x7fffffffffffffffL;
}
static long machold_carr_contains(void *self, const char *cmd, void *o) {
    return machold_carr_indexOf(self, cmd, o) != (long)0x7fffffffffffffffL;
}
static unsigned long machold_carr_fastEnum(void *self, const char *cmd, void *st, void *buf, unsigned long len) {
    (void)cmd; (void)buf; (void)len;
    return machold_fastenum((unsigned long *)st, machold_carr_items(self), *(long *)((char *)self + 8));
}
static void machold_carr_enumBlock(void *self, const char *cmd, void *block) {
    (void)cmd; machold_enum_block_over(machold_carr_items(self), *(long *)((char *)self + 8), block);
}
static void *machold_carr_mutableCopy(void *self, const char *cmd) {
    (void)cmd; void *m = machold_arr_new();
    void **items = machold_carr_items(self); long c = *(long *)((char *)self + 8);
    for (long i = 0; i < c; i++) machold_arr_addObject(m, "addObject:", items[i]);
    return m;
}
static machold_mlist_t machold_carr_methods;
static machold_class_ro_t machold_carr_ro, machold_carr_meta_ro;
static machold_class_t machold_carr_cls, machold_carr_meta;
static int machold_carr_inited = 0;
static void machold_init_carr(void) {
    if (machold_carr_inited) return; machold_carr_inited = 1;
    machold_init_nsobject();
    // Read/enum set matching the @[…] layout (count@8, objects@16). componentsJoinedBy-
    // String: is omitted (it'd need a carr-specific join over this layout) — harvest later.
    machold_method_t m[] = {
        {"count", "Q16@0:8", (void *)machold_carr_count},
        {"objectAtIndex:", "@24@0:8Q16", (void *)machold_carr_objAt},
        {"objectAtIndexedSubscript:", "@24@0:8Q16", (void *)machold_carr_objAt},
        {"firstObject", "@16@0:8", (void *)machold_carr_first},
        {"lastObject", "@16@0:8", (void *)machold_carr_last},
        {"indexOfObject:", "Q24@0:8@16", (void *)machold_carr_indexOf},
        {"containsObject:", "c24@0:8@16", (void *)machold_carr_contains},
        {"countByEnumeratingWithState:objects:count:", "Q40@0:8^v16^@24Q32", (void *)machold_carr_fastEnum},
        {"enumerateObjectsUsingBlock:", "v24@0:8@?16", (void *)machold_carr_enumBlock},
        {"mutableCopy", "@16@0:8", (void *)machold_carr_mutableCopy},
    };
    machold_carr_methods.entsize = sizeof(machold_method_t);
    machold_carr_methods.count = sizeof(m) / sizeof(m[0]);
    memcpy(machold_carr_methods.methods, m, sizeof(m));
    machold_carr_ro.flags = 0; machold_carr_ro.instanceSize = 24;
    machold_carr_ro.name = "NSConstantArray"; machold_carr_ro.baseMethods = &machold_carr_methods;
    machold_carr_meta_ro.flags = 0x1; machold_carr_meta_ro.instanceSize = 40;
    machold_carr_meta_ro.name = "NSConstantArray";
    machold_carr_cls.isa = &machold_carr_meta; machold_carr_cls.superclass = &machold_nsobj_cls;
    machold_carr_cls.data = (uintptr_t)&machold_carr_ro;
    machold_carr_meta.isa = &machold_nsobj_meta; machold_carr_meta.superclass = &machold_nsobj_meta;
    machold_carr_meta.data = (uintptr_t)&machold_carr_meta_ro;
    machold_register_class("NSConstantArray", &machold_carr_cls);
}

// ── NSMutableSet (tier 2, O10) ───────────────────────────────────────────────
// Same layout as NSMutableArray {isa, items@8, count@16, cap@24} — reuse arr_* for
// count/contains/enum; addObject: dedups.
static void machold_set_add(void *self, const char *cmd, void *obj) {
    if (!machold_arr_contains(self, cmd, obj)) machold_arr_addObject(self, cmd, obj);
}
static machold_class_t machold_nsset_cls, machold_nsset_meta;
static void *machold_set_new(void *cls, const char *cmd) {
    (void)cls; (void)cmd; return machold_class_createInstance((uint8_t *)&machold_nsset_cls, 0);
}
static void *machold_set_member(void *self, const char *cmd, void *obj) {
    return machold_arr_contains(self, cmd, obj) ? obj : NULL;
}
static machold_mlist_t machold_nsset_methods, machold_nsset_cmethods;
static machold_class_ro_t machold_nsset_ro, machold_nsset_meta_ro;
static int machold_nsset_inited = 0;
static void machold_init_nsset(void) {
    if (machold_nsset_inited) return; machold_nsset_inited = 1;
    machold_init_nsarray();   // reuse arr_* imps
    machold_method_t m[] = {
        {"init", "@16@0:8", (void *)machold_arr_init},
        {"addObject:", "v24@0:8@16", (void *)machold_set_add},
        {"containsObject:", "c24@0:8@16", (void *)machold_arr_contains},
        {"member:", "@24@0:8@16", (void *)machold_set_member},
        {"count", "Q16@0:8", (void *)machold_arr_count},
        {"allObjects", "@16@0:8", (void *)machold_ns_self},   // rough: not a real NSArray copy
        {"countByEnumeratingWithState:objects:count:", "Q40@0:8^v16^@24Q32", (void *)machold_arr_fastEnum},
    };
    machold_method_t cm[] = {
        {"set", "@16#0:8", (void *)machold_set_new},
    };
    machold_nsset_methods.entsize = sizeof(machold_method_t);
    machold_nsset_methods.count = sizeof(m) / sizeof(m[0]);
    memcpy(machold_nsset_methods.methods, m, sizeof(m));
    machold_nsset_cmethods.entsize = sizeof(machold_method_t);
    machold_nsset_cmethods.count = sizeof(cm) / sizeof(cm[0]);
    memcpy(machold_nsset_cmethods.methods, cm, sizeof(cm));
    machold_nsset_ro.flags = 0; machold_nsset_ro.instanceSize = 32;
    machold_nsset_ro.name = "NSMutableSet"; machold_nsset_ro.baseMethods = &machold_nsset_methods;
    machold_nsset_meta_ro.flags = 0x1; machold_nsset_meta_ro.instanceSize = 40;
    machold_nsset_meta_ro.name = "NSMutableSet"; machold_nsset_meta_ro.baseMethods = &machold_nsset_cmethods;
    machold_nsset_cls.isa = &machold_nsset_meta; machold_nsset_cls.superclass = &machold_nsobj_cls;
    machold_nsset_cls.data = (uintptr_t)&machold_nsset_ro;
    machold_nsset_meta.isa = &machold_nsobj_meta; machold_nsset_meta.superclass = &machold_nsobj_meta;
    machold_nsset_meta.data = (uintptr_t)&machold_nsset_meta_ro;
    machold_register_class("NSMutableSet", &machold_nsset_cls);
    machold_register_class("NSSet", &machold_nsset_cls);
}

// ── NSDate (tier 2, O12) ─────────────────────────────────────────────────────
// {isa@0, double time@8} = 16 B, time = seconds since 1970 (real Linux epoch via
// gettimeofday — no Darwin clock). +date/+dateWithTimeIntervalSince1970:, -timeInterval*.
static machold_class_t machold_nsdate_cls, machold_nsdate_meta;
static double machold_now(void) { struct timeval tv; gettimeofday(&tv, NULL); return (double)tv.tv_sec + tv.tv_usec / 1e6; }
static void machold_init_nsdate(void);
static void *machold_make_date(double t) {
    machold_init_nsdate();
    char *o = (char *)calloc(1, 16); *(void **)o = &machold_nsdate_cls; *(double *)(o + 8) = t; return o;
}
static double machold_date_ts(void *self, const char *cmd) { (void)cmd; return *(double *)((char *)self + 8); }
static double machold_date_since(void *self, const char *cmd, void *other) {
    (void)cmd; return *(double *)((char *)self + 8) - (other ? *(double *)((char *)other + 8) : 0);
}
static void *machold_date_now(void *cls, const char *cmd) { (void)cls; (void)cmd; return machold_make_date(machold_now()); }
static void *machold_date_withTS(void *cls, const char *cmd, double t) { (void)cls; (void)cmd; return machold_make_date(t); }
static machold_mlist_t machold_nsdate_methods, machold_nsdate_cmethods;
static machold_class_ro_t machold_nsdate_ro, machold_nsdate_meta_ro;
static int machold_nsdate_inited = 0;
static void machold_init_nsdate(void) {
    if (machold_nsdate_inited) return; machold_nsdate_inited = 1;
    machold_init_nsobject();
    machold_method_t m[] = {
        {"timeIntervalSince1970", "d16@0:8", (void *)machold_date_ts},
        {"timeIntervalSinceReferenceDate", "d16@0:8", (void *)machold_date_ts},
        {"timeIntervalSinceDate:", "d24@0:8@16", (void *)machold_date_since},
    };
    machold_method_t cm[] = {
        {"date", "@16#0:8", (void *)machold_date_now},
        {"dateWithTimeIntervalSince1970:", "@24#0:8d16", (void *)machold_date_withTS},
    };
    machold_nsdate_methods.entsize = sizeof(machold_method_t);
    machold_nsdate_methods.count = sizeof(m) / sizeof(m[0]);
    memcpy(machold_nsdate_methods.methods, m, sizeof(m));
    machold_nsdate_cmethods.entsize = sizeof(machold_method_t);
    machold_nsdate_cmethods.count = sizeof(cm) / sizeof(cm[0]);
    memcpy(machold_nsdate_cmethods.methods, cm, sizeof(cm));
    machold_nsdate_ro.flags = 0; machold_nsdate_ro.instanceSize = 16;
    machold_nsdate_ro.name = "NSDate"; machold_nsdate_ro.baseMethods = &machold_nsdate_methods;
    machold_nsdate_meta_ro.flags = 0x1; machold_nsdate_meta_ro.instanceSize = 40;
    machold_nsdate_meta_ro.name = "NSDate"; machold_nsdate_meta_ro.baseMethods = &machold_nsdate_cmethods;
    machold_nsdate_cls.isa = &machold_nsdate_meta; machold_nsdate_cls.superclass = &machold_nsobj_cls;
    machold_nsdate_cls.data = (uintptr_t)&machold_nsdate_ro;
    machold_nsdate_meta.isa = &machold_nsobj_meta; machold_nsdate_meta.superclass = &machold_nsobj_meta;
    machold_nsdate_meta.data = (uintptr_t)&machold_nsdate_meta_ro;
    machold_register_class("NSDate", &machold_nsdate_cls);
}

// ── NSError (Foundation-fusion phase 1) ──────────────────────────────────────
// {isa@0, domain@8, long code@16, userInfo@24} = 32. The common Foundation error carrier;
// binaries create it (errorWithDomain:code:userInfo:) and read code/domain/userInfo.
static machold_class_t machold_nserror_cls, machold_nserror_meta;
static void machold_init_nserror(void);
static void *machold_err_make(void *cls, const char *cmd, void *domain, long code, void *userInfo) {
    (void)cls; (void)cmd; machold_init_nserror();
    void *o = machold_class_createInstance((uint8_t *)&machold_nserror_cls, 0);
    *(void **)((char *)o + 8) = domain; *(long *)((char *)o + 16) = code; *(void **)((char *)o + 24) = userInfo;
    return o;
}
static long machold_err_code(void *self, const char *cmd) { (void)cmd; return *(long *)((char *)self + 16); }
static void *machold_err_domain(void *self, const char *cmd) { (void)cmd; return *(void **)((char *)self + 8); }
static void *machold_err_userInfo(void *self, const char *cmd) { (void)cmd; return *(void **)((char *)self + 24); }
static void *machold_err_localizedDesc(void *self, const char *cmd) { (void)cmd; return *(void **)((char *)self + 8); }
static machold_mlist_t machold_nserror_m, machold_nserror_cm;
static machold_class_ro_t machold_nserror_ro, machold_nserror_mro;
static int machold_nserror_inited = 0;
static void machold_init_nserror(void) {
    if (machold_nserror_inited) return; machold_nserror_inited = 1;
    machold_init_nsobject();
    machold_method_t m[] = {
        {"code", "q16@0:8", (void *)machold_err_code},
        {"domain", "@16@0:8", (void *)machold_err_domain},
        {"userInfo", "@16@0:8", (void *)machold_err_userInfo},
        {"localizedDescription", "@16@0:8", (void *)machold_err_localizedDesc},
    };
    machold_method_t cm[] = {
        {"errorWithDomain:code:userInfo:", "@40#0:8@16q24@32", (void *)machold_err_make},
    };
    machold_nserror_m.entsize = sizeof(machold_method_t);
    machold_nserror_m.count = sizeof(m) / sizeof(m[0]);
    memcpy(machold_nserror_m.methods, m, sizeof(m));
    machold_nserror_cm.entsize = sizeof(machold_method_t);
    machold_nserror_cm.count = sizeof(cm) / sizeof(cm[0]);
    memcpy(machold_nserror_cm.methods, cm, sizeof(cm));
    machold_nserror_ro.flags = 0; machold_nserror_ro.instanceSize = 32;
    machold_nserror_ro.name = "NSError"; machold_nserror_ro.baseMethods = &machold_nserror_m;
    machold_nserror_mro.flags = 0x1; machold_nserror_mro.instanceSize = 40;
    machold_nserror_mro.name = "NSError"; machold_nserror_mro.baseMethods = &machold_nserror_cm;
    machold_nserror_cls.isa = &machold_nserror_meta; machold_nserror_cls.superclass = &machold_nsobj_cls;
    machold_nserror_cls.data = (uintptr_t)&machold_nserror_ro;
    machold_nserror_meta.isa = &machold_nsobj_meta; machold_nserror_meta.superclass = &machold_nsobj_meta;
    machold_nserror_meta.data = (uintptr_t)&machold_nserror_mro;
    machold_register_class("NSError", &machold_nserror_cls);
}

// ── NSException + ObjC exceptions (mini-unwinder, X-series) ───────────────────
// {isa@0, name@8, reason@16, userInfo@24} = 32. Thrown via objc_exception_throw, caught by
// machold's own compact-unwind reader (Apple arm64 has no DWARF eh_frame to drive libgcc).
static machold_class_t machold_nsexc_cls, machold_nsexc_meta;
extern void machold_objc_exception_throw(void);   // fwd (naked, defined near resolve_symbol)
// objc_typeinfo the LSDA ttype slots resolve to: {vtable, name, Class} — we match by .cls.
static struct { const void *vtable; const char *name; void *cls; } machold_ehtype_nsexc;
static long machold_exc_getfield(void *self, const char *cmd, long off) { (void)cmd; return *(long *)((char *)self + off); }
static void *machold_exc_name(void *self, const char *cmd) { (void)cmd; return *(void **)((char *)self + 8); }
static void *machold_exc_reason(void *self, const char *cmd) { (void)cmd; return *(void **)((char *)self + 16); }
static void *machold_exc_userInfo(void *self, const char *cmd) { (void)cmd; return *(void **)((char *)self + 24); }
static void machold_exc_raise(void *self, const char *cmd) {
    (void)cmd; ((void (*)(void *))machold_objc_exception_throw)(self);
}
static machold_class_t machold_nsexc_cls, machold_nsexc_meta;
static void *machold_exc_make(void *cls, const char *cmd, void *name, void *reason, void *userInfo) {
    (void)cls; (void)cmd;
    void *o = machold_class_createInstance((uint8_t *)&machold_nsexc_cls, 0);
    *(void **)((char *)o + 8) = name; *(void **)((char *)o + 16) = reason; *(void **)((char *)o + 24) = userInfo;
    return o;
}
static machold_mlist_t machold_nsexc_m, machold_nsexc_cm;
static machold_class_ro_t machold_nsexc_ro, machold_nsexc_mro;
static int machold_nsexc_inited = 0;
static void machold_init_nsexception(void) {
    if (machold_nsexc_inited) return; machold_nsexc_inited = 1;
    machold_init_nsobject();
    (void)machold_exc_getfield;
    machold_method_t m[] = {
        {"name", "@16@0:8", (void *)machold_exc_name},
        {"reason", "@16@0:8", (void *)machold_exc_reason},
        {"userInfo", "@16@0:8", (void *)machold_exc_userInfo},
        {"raise", "v16@0:8", (void *)machold_exc_raise},
    };
    machold_method_t cm[] = {
        {"exceptionWithName:reason:userInfo:", "@40#0:8@16@24@32", (void *)machold_exc_make},
    };
    machold_nsexc_m.entsize = sizeof(machold_method_t); machold_nsexc_m.count = sizeof(m)/sizeof(m[0]);
    memcpy(machold_nsexc_m.methods, m, sizeof(m));
    machold_nsexc_cm.entsize = sizeof(machold_method_t); machold_nsexc_cm.count = sizeof(cm)/sizeof(cm[0]);
    memcpy(machold_nsexc_cm.methods, cm, sizeof(cm));
    machold_nsexc_ro.flags = 0; machold_nsexc_ro.instanceSize = 32; machold_nsexc_ro.name = "NSException"; machold_nsexc_ro.baseMethods = &machold_nsexc_m;
    machold_nsexc_mro.flags = 0x1; machold_nsexc_mro.instanceSize = 40; machold_nsexc_mro.name = "NSException"; machold_nsexc_mro.baseMethods = &machold_nsexc_cm;
    machold_nsexc_cls.isa = &machold_nsexc_meta; machold_nsexc_cls.superclass = &machold_nsobj_cls; machold_nsexc_cls.data = (uintptr_t)&machold_nsexc_ro;
    machold_nsexc_meta.isa = &machold_nsobj_meta; machold_nsexc_meta.superclass = &machold_nsobj_meta; machold_nsexc_meta.data = (uintptr_t)&machold_nsexc_mro;
    machold_ehtype_nsexc.name = "NSException"; machold_ehtype_nsexc.cls = &machold_nsexc_cls;
    machold_register_class("NSException", &machold_nsexc_cls);
}

// ── NSProcessInfo + NSFileManager (Foundation-fusion phase 2) ─────────────────
// Singletons CLI tools lean on. NSProcessInfo.arguments = the program's argv; NSFileManager
// does real POSIX file checks/reads.
static machold_class_t machold_procinfo_cls, machold_procinfo_meta;
static machold_class_t machold_filemgr_cls, machold_filemgr_meta;
static void *g_procinfo_singleton = NULL, *g_filemgr_singleton = NULL;
static void machold_init_procinfo(void), machold_init_filemgr(void);

static void *machold_pi_shared(void *cls, const char *cmd) {
    (void)cmd; machold_init_procinfo();
    if (!g_procinfo_singleton) g_procinfo_singleton = machold_class_createInstance((uint8_t *)&machold_procinfo_cls, 0);
    return g_procinfo_singleton;
}
static void *machold_pi_arguments(void *self, const char *cmd) {
    (void)self; (void)cmd;
    void *arr = machold_arr_new();
    for (int i = 0; i < g_prog_argc; i++)
        machold_arr_addObject(arr, "addObject:", machold_make_string(g_prog_argv[i], (long)strlen(g_prog_argv[i])));
    return arr;
}
static void *machold_pi_processName(void *self, const char *cmd) {
    (void)self; (void)cmd;
    const char *p = (g_prog_argc > 0 && g_prog_argv[0]) ? g_prog_argv[0] : "machold";
    const char *base = strrchr(p, '/'); base = base ? base + 1 : p;
    return machold_make_string(base, (long)strlen(base));
}
static long machold_pi_pid(void *self, const char *cmd) { (void)self; (void)cmd; return (long)getpid(); }

static void *machold_fm_default(void *cls, const char *cmd) {
    (void)cmd; machold_init_filemgr();
    if (!g_filemgr_singleton) g_filemgr_singleton = machold_class_createInstance((uint8_t *)&machold_filemgr_cls, 0);
    return g_filemgr_singleton;
}
static char machold_fm_exists(void *self, const char *cmd, void *path) {
    (void)self; (void)cmd;
    const char *p = path ? *(const char **)((char *)path + 16) : NULL;
    return (p && access(p, F_OK) == 0) ? 1 : 0;
}
static void *machold_fm_contents(void *self, const char *cmd, void *path) {
    (void)self; (void)cmd;
    const char *p = path ? *(const char **)((char *)path + 16) : NULL;
    if (!p) return NULL;
    FILE *f = fopen(p, "rb"); if (!f) return NULL;
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    if (n < 0) { fclose(f); return NULL; }
    char *buf = (char *)malloc((size_t)(n ? n : 1));
    long got = (long)fread(buf, 1, (size_t)n, f); fclose(f);
    void *d = machold_make_data(buf, got); free(buf); return d;
}
static machold_mlist_t machold_procinfo_m, machold_procinfo_cm, machold_filemgr_m, machold_filemgr_cm;
static machold_class_ro_t machold_procinfo_ro, machold_procinfo_mro, machold_filemgr_ro, machold_filemgr_mro;
static int machold_procinfo_inited = 0, machold_filemgr_inited = 0;
static void machold_init_procinfo(void) {
    if (machold_procinfo_inited) return; machold_procinfo_inited = 1;
    machold_init_nsobject();
    machold_method_t m[] = {
        {"arguments", "@16@0:8", (void *)machold_pi_arguments},
        {"processName", "@16@0:8", (void *)machold_pi_processName},
        {"processIdentifier", "i16@0:8", (void *)machold_pi_pid},
    };
    machold_method_t cm[] = { {"processInfo", "@16#0:8", (void *)machold_pi_shared} };
    machold_procinfo_m.entsize = sizeof(machold_method_t); machold_procinfo_m.count = sizeof(m)/sizeof(m[0]);
    memcpy(machold_procinfo_m.methods, m, sizeof(m));
    machold_procinfo_cm.entsize = sizeof(machold_method_t); machold_procinfo_cm.count = sizeof(cm)/sizeof(cm[0]);
    memcpy(machold_procinfo_cm.methods, cm, sizeof(cm));
    machold_procinfo_ro.flags = 0; machold_procinfo_ro.instanceSize = 16;
    machold_procinfo_ro.name = "NSProcessInfo"; machold_procinfo_ro.baseMethods = &machold_procinfo_m;
    machold_procinfo_mro.flags = 0x1; machold_procinfo_mro.instanceSize = 40;
    machold_procinfo_mro.name = "NSProcessInfo"; machold_procinfo_mro.baseMethods = &machold_procinfo_cm;
    machold_procinfo_cls.isa = &machold_procinfo_meta; machold_procinfo_cls.superclass = &machold_nsobj_cls;
    machold_procinfo_cls.data = (uintptr_t)&machold_procinfo_ro;
    machold_procinfo_meta.isa = &machold_nsobj_meta; machold_procinfo_meta.superclass = &machold_nsobj_meta;
    machold_procinfo_meta.data = (uintptr_t)&machold_procinfo_mro;
    machold_register_class("NSProcessInfo", &machold_procinfo_cls);
}
static void machold_init_filemgr(void) {
    if (machold_filemgr_inited) return; machold_filemgr_inited = 1;
    machold_init_nsobject();
    machold_method_t m[] = {
        {"fileExistsAtPath:", "c24@0:8@16", (void *)machold_fm_exists},
        {"contentsAtPath:", "@24@0:8@16", (void *)machold_fm_contents},
    };
    machold_method_t cm[] = { {"defaultManager", "@16#0:8", (void *)machold_fm_default} };
    machold_filemgr_m.entsize = sizeof(machold_method_t); machold_filemgr_m.count = sizeof(m)/sizeof(m[0]);
    memcpy(machold_filemgr_m.methods, m, sizeof(m));
    machold_filemgr_cm.entsize = sizeof(machold_method_t); machold_filemgr_cm.count = sizeof(cm)/sizeof(cm[0]);
    memcpy(machold_filemgr_cm.methods, cm, sizeof(cm));
    machold_filemgr_ro.flags = 0; machold_filemgr_ro.instanceSize = 16;
    machold_filemgr_ro.name = "NSFileManager"; machold_filemgr_ro.baseMethods = &machold_filemgr_m;
    machold_filemgr_mro.flags = 0x1; machold_filemgr_mro.instanceSize = 40;
    machold_filemgr_mro.name = "NSFileManager"; machold_filemgr_mro.baseMethods = &machold_filemgr_cm;
    machold_filemgr_cls.isa = &machold_filemgr_meta; machold_filemgr_cls.superclass = &machold_nsobj_cls;
    machold_filemgr_cls.data = (uintptr_t)&machold_filemgr_ro;
    machold_filemgr_meta.isa = &machold_nsobj_meta; machold_filemgr_meta.superclass = &machold_nsobj_meta;
    machold_filemgr_meta.data = (uintptr_t)&machold_filemgr_mro;
    machold_register_class("NSFileManager", &machold_filemgr_cls);
}

// ── NSNull (singleton) ───────────────────────────────────────────────────────
static machold_class_t machold_nsnull_cls, machold_nsnull_meta;
static machold_mlist_t machold_nsnull_cm;
static machold_class_ro_t machold_nsnull_ro, machold_nsnull_mro;
static char machold_nsnull_inst[16];   // the shared [NSNull null] (isa filled at init)
static int machold_nsnull_inited = 0;
static void machold_init_nsnull(void);
static void *machold_nsnull_get(void *cls, const char *cmd) { (void)cls; (void)cmd; machold_init_nsnull(); return machold_nsnull_inst; }
static void machold_init_nsnull(void) {
    if (machold_nsnull_inited) return; machold_nsnull_inited = 1;
    machold_init_nsobject();
    machold_method_t cm[] = { {"null", "@16#0:8", (void *)machold_nsnull_get} };
    machold_nsnull_cm.entsize = sizeof(machold_method_t); machold_nsnull_cm.count = 1;
    memcpy(machold_nsnull_cm.methods, cm, sizeof(cm));
    machold_nsnull_ro.flags = 0; machold_nsnull_ro.instanceSize = 16; machold_nsnull_ro.name = "NSNull";
    machold_nsnull_mro.flags = 0x1; machold_nsnull_mro.instanceSize = 40; machold_nsnull_mro.name = "NSNull";
    machold_nsnull_mro.baseMethods = &machold_nsnull_cm;
    machold_nsnull_cls.isa = &machold_nsnull_meta; machold_nsnull_cls.superclass = &machold_nsobj_cls;
    machold_nsnull_cls.data = (uintptr_t)&machold_nsnull_ro;
    machold_nsnull_meta.isa = &machold_nsobj_meta; machold_nsnull_meta.superclass = &machold_nsobj_meta;
    machold_nsnull_meta.data = (uintptr_t)&machold_nsnull_mro;
    *(void **)machold_nsnull_inst = &machold_nsnull_cls;
    machold_register_class("NSNull", &machold_nsnull_cls);
}

// ═════════════════════════════════════════════════════════════════════════════
// MARK: - machold object model ⇄ Swift-Any bridge ABI (used by FoundationFusion.swift)
// ═════════════════════════════════════════════════════════════════════════════
// Exported (non-static; machold links --export-dynamic) so the Swift helper in
// libcompat_host can build/read machold-native objects at the serializer boundary. Types:
// 0 string, 1 number, 2 array, 3 dict, 4 data, 5 null.
#define MOBJ __attribute__((used))
MOBJ void *machold_obj_string(const char *b, long n) { machold_init_cfstring(); return machold_make_string(b, n); }
MOBJ void *machold_obj_number_ll(long long v) { machold_init_nsnumber(); return machold_num_mk((long)v); }
MOBJ void *machold_obj_number_d(double d) { machold_init_nsnumber(); return machold_num_mk_double(d); }
MOBJ void *machold_obj_bool(int b) { machold_init_nsnumber(); return machold_num_mk_bool(b); }
MOBJ void *machold_obj_null(void) { machold_init_nsnull(); return machold_nsnull_inst; }
MOBJ void *machold_obj_array(void) { return machold_arr_new(); }
MOBJ void machold_obj_array_add(void *a, void *o) { machold_arr_addObject(a, "addObject:", o); }
MOBJ void *machold_obj_dict(void) { machold_init_nsdict(); return machold_class_createInstance((uint8_t *)&machold_nsdict_cls, 0); }
MOBJ void machold_obj_dict_set(void *d, void *k, void *v) { machold_dict_setObjectForKey(d, "setObject:forKey:", v, k); }
MOBJ void *machold_obj_data(const void *b, long n) { return machold_make_data(b, n); }

MOBJ int machold_obj_type(void *o) {
    if (!o) return 5;
    void *isa = *(void **)o;
    if (isa == &machold_cfstring_cls || isa == &machold_mstr_cls) return 0;
    if (isa == &machold_nsnum_cls) return 1;
    if (isa == &machold_nsarray_cls || isa == &machold_carr_cls) return 2;
    if (isa == &machold_nsdict_cls) return 3;
    if (isa == &machold_nsdata_cls) return 4;
    if (isa == &machold_nsnull_cls) return 5;
    return -1;
}
MOBJ const char *machold_obj_str(void *o) { return *(const char **)((char *)o + 16); }
MOBJ long machold_obj_strlen(void *o) { return *(long *)((char *)o + 24); }
MOBJ int machold_obj_num_kind(void *o) { long t = *(long *)((char *)o + 8); return (t == 2) ? 2 : (machold_num_is_double(o) ? 1 : 0); }  // 0 int,1 double,2 bool
MOBJ double machold_obj_num_double(void *o) { return machold_num_dbl(o, ""); }
MOBJ long long machold_obj_num_ll(void *o) { return (long long)machold_num_long(o, ""); }
MOBJ long machold_obj_arr_count(void *o) {   // NSMutableArray items@8/count@16, NSConstantArray count@8/objects@16
    return (*(void **)o == &machold_carr_cls) ? *(long *)((char *)o + 8) : *(long *)((char *)o + 16);
}
MOBJ void *machold_obj_arr_at(void *o, long i) {
    if (*(void **)o == &machold_carr_cls) return (*(void ***)((char *)o + 16))[i];
    return (*(void ***)((char *)o + 8))[i];
}
MOBJ long machold_obj_dict_count(void *o) { return *(long *)((char *)o + 24); }
MOBJ void *machold_obj_dict_key(void *o, long i) { return (*(void ***)((char *)o + 8))[i]; }
MOBJ void *machold_obj_dict_val(void *o, long i) { return (*(void ***)((char *)o + 16))[i]; }
MOBJ const void *machold_obj_data_bytes(void *o) { return *(void **)((char *)o + 8); }
MOBJ long machold_obj_data_len(void *o) { return *(long *)((char *)o + 16); }
#undef MOBJ

// ── -description: OpenStep-plist rendering of a machold-native tree (what `defaults` prints) ──
static void machold_describe_into(FILE *out, void *o, int indent);
static void machold_desc_indent(FILE *out, int n) { for (int i = 0; i < n; i++) fputs("    ", out); }
static int machold_str_simple(const char *s) {
    if (!s || !*s) return 0;
    for (const char *p = s; *p; p++)
        if (!(isalnum((unsigned char)*p) || *p == '.' || *p == '_' || *p == '/' || *p == '$' || *p == '-' || *p == ':')) return 0;
    return 1;
}
static void machold_describe_into(FILE *out, void *o, int indent) {
    switch (machold_obj_type(o)) {
    case 0: {
        const char *s = machold_obj_str(o);
        if (machold_str_simple(s)) fputs(s, out);
        else { fputc('"', out); for (const char *p = s ? s : ""; *p; p++) { if (*p == '"' || *p == '\\') fputc('\\', out); fputc(*p, out); } fputc('"', out); }
        break; }
    case 1:
        if (machold_obj_num_kind(o) == 2) fputs(machold_obj_num_ll(o) ? "1" : "0", out);
        else if (machold_obj_num_kind(o) == 1) fprintf(out, "%g", machold_obj_num_double(o));
        else fprintf(out, "%lld", machold_obj_num_ll(o));
        break;
    case 2: {
        long n = machold_obj_arr_count(o); fputs("(\n", out);
        for (long i = 0; i < n; i++) { machold_desc_indent(out, indent + 1); machold_describe_into(out, machold_obj_arr_at(o, i), indent + 1); fputs(i < n - 1 ? ",\n" : "\n", out); }
        machold_desc_indent(out, indent); fputc(')', out); break; }
    case 3: {
        long n = machold_obj_dict_count(o); fputs("{\n", out);
        for (long i = 0; i < n; i++) { machold_desc_indent(out, indent + 1); machold_describe_into(out, machold_obj_dict_key(o, i), indent + 1); fputs(" = ", out); machold_describe_into(out, machold_obj_dict_val(o, i), indent + 1); fputs(";\n", out); }
        machold_desc_indent(out, indent); fputc('}', out); break; }
    case 4: fputs("<data>", out); break;
    default: fputs("(null)", out); break;
    }
}
static void *machold_obj_description(void *self, const char *cmd) {
    (void)cmd;
    char *buf = NULL; size_t sz = 0; FILE *ms = open_memstream(&buf, &sz);
    if (!ms) return machold_make_string("", 0);
    machold_describe_into(ms, self, 0); fclose(ms);
    void *s = machold_make_string(buf, (long)sz); free(buf); return s;
}

// ── Reverse-impedance: machold-aware CF C functions ──────────────────────────
// The mirror of the bridge: CF-heavy ObjC tools (e.g. `defaults`) feed our machold-native
// objects INTO Linux CF's C API (CFEqual/CFGetTypeID/…), where CF misreads them as Swift
// objects and dynamic-cast-crashes. These wrappers detect a machold object (machold_obj_type
// != -1) and handle it natively; for a real Linux CF object they forward to the real function
// (dlsym resolves the un-shadowed Linux CF symbol). Reusable for any CF-heavy tool.
static unsigned long machold_cf_typeid_of(const char *fn) {
    unsigned long (*f)(void) = (unsigned long (*)(void))dlsym(RTLD_DEFAULT, fn);
    return f ? f() : 0;
}
static unsigned long machold_cf_getTypeID(void *o) {
    int t = machold_obj_type(o);
    if (t == -1) { unsigned long (*f)(void *) = (unsigned long (*)(void *))dlsym(RTLD_DEFAULT, "CFGetTypeID"); return f ? f(o) : 0; }
    switch (t) {
    case 0: return machold_cf_typeid_of("CFStringGetTypeID");
    case 1: return machold_cf_typeid_of(machold_obj_num_kind(o) == 2 ? "CFBooleanGetTypeID" : "CFNumberGetTypeID");
    case 2: return machold_cf_typeid_of("CFArrayGetTypeID");
    case 3: return machold_cf_typeid_of("CFDictionaryGetTypeID");
    case 4: return machold_cf_typeid_of("CFDataGetTypeID");
    case 5: return machold_cf_typeid_of("CFNullGetTypeID");
    }
    return 0;
}
static unsigned char machold_cf_equal(void *a, void *b) {
    if (a == b) return 1;
    if (machold_obj_type(a) != -1 || machold_obj_type(b) != -1) return machold_obj_eq(a, b) ? 1 : 0;
    unsigned char (*f)(void *, void *) = (unsigned char (*)(void *, void *))dlsym(RTLD_DEFAULT, "CFEqual");
    return f ? f(a, b) : 0;
}
static void machold_cf_release(void *o) {
    if (!o || machold_obj_type(o) != -1) return;   // machold objects aren't refcounted
    void (*f)(void *) = (void (*)(void *))dlsym(RTLD_DEFAULT, "CFRelease"); if (f) f(o);
}
static long machold_cf_strlen(void *s) {
    if (machold_obj_type(s) == 0) return machold_obj_strlen(s);
    long (*f)(void *) = (long (*)(void *))dlsym(RTLD_DEFAULT, "CFStringGetLength"); return f ? f(s) : 0;
}
static unsigned char machold_cf_hasPrefix(void *s, void *pfx) {
    if (machold_obj_type(s) == 0 && machold_obj_type(pfx) == 0) {
        const char *a = machold_obj_str(s), *b = machold_obj_str(pfx);
        return (a && b && strncmp(a, b, strlen(b)) == 0) ? 1 : 0;
    }
    unsigned char (*f)(void *, void *) = (unsigned char (*)(void *, void *))dlsym(RTLD_DEFAULT, "CFStringHasPrefix");
    return f ? f(s, pfx) : 0;
}
static unsigned char machold_cf_numIsFloat(void *n) {
    if (machold_obj_type(n) == 1) return machold_obj_num_kind(n) == 1 ? 1 : 0;
    unsigned char (*f)(void *) = (unsigned char (*)(void *))dlsym(RTLD_DEFAULT, "CFNumberIsFloatType");
    return f ? f(n) : 0;
}

// ── CFPreferences intercept (Linux CF's own CFPreferences crashes) ───────────
// `defaults read <domain>` treats the arg as a prefs domain. Emulate a domain by reading its
// <domain>.plist file via the bridged plist parser → a machold-native dict (messageable + CF-
// wrapper-compatible). Makes `defaults read <path>` produce output without a real prefs store.
static void *machold_prefs_read_domain(void *appID) {
    char tmp[2048]; const char *dom = NULL;
    if (appID) {
        if (machold_obj_type(appID) == 0) dom = machold_obj_str(appID);
        else { unsigned char (*g)(void *, char *, long, unsigned) = (unsigned char (*)(void *, char *, long, unsigned))dlsym(RTLD_DEFAULT, "CFStringGetCString");
               if (g && g(appID, tmp, sizeof(tmp), 0x08000100)) dom = tmp; }
    }
    if (!dom || !*dom) return NULL;
    char path[2200];
    if (strstr(dom, ".plist")) snprintf(path, sizeof(path), "%s", dom);
    else snprintf(path, sizeof(path), "%s.plist", dom);
    FILE *f = fopen(path, "rb"); if (!f) return NULL;
    fseek(f, 0, SEEK_END); long len = ftell(f); fseek(f, 0, SEEK_SET);
    if (len <= 0) { fclose(f); return NULL; }
    char *buf = (char *)malloc((size_t)len); long got = (long)fread(buf, 1, (size_t)len, f); fclose(f);
    int fmt = 0;
    void *(*parse)(const void *, long, int *) = (void *(*)(const void *, long, int *))dlsym(RTLD_DEFAULT, "machold_fusion_plist_parse");
    void *d = parse ? parse(buf, got, &fmt) : NULL; free(buf);
    if (g_verbose) fprintf(stderr, "[machold] prefs domain \"%s\" path=%s len=%ld dict=%p count=%ld\n",
                           dom, path, got, d, d ? machold_obj_dict_count(d) : -1);
    return d;
}
static void *machold_prefs_multiple(void *keys, void *appID, void *user, void *host) {
    (void)keys; (void)user; (void)host;
    if (g_verbose) fprintf(stderr, "[machold] CFPreferencesCopyMultiple appID=%p type=%d\n", appID, appID ? machold_obj_type(appID) : -9);
    return machold_prefs_read_domain(appID);
}
static void *machold_prefs_keylist(void *appID, void *user, void *host) {
    (void)user; (void)host;
    void *d = machold_prefs_read_domain(appID); if (!d) return NULL;
    void *arr = machold_arr_new(); long nkeys = machold_obj_dict_count(d);
    for (long i = 0; i < nkeys; i++) machold_arr_addObject(arr, "addObject:", machold_obj_dict_key(d, i));
    return arr;
}
static void *machold_prefs_value(void *key, void *appID, void *user, void *host) {
    (void)user; (void)host;
    void *d = machold_prefs_read_domain(appID); if (!d) return NULL;
    return machold_dict_objectForKey(d, "objectForKey:", key);
}
static long machold_ret_true(void) { return 1; }

// ── Runtime/libSystem stubs a Swift+ObjC hybrid (plutil) needs ────────────────
static void *machold_class_getSuperclass(void *cls) { return cls ? *(void **)((char *)cls + MACHO_CM_SUPER_OFF) : NULL; }
static void *machold_objc_allocWithZone(void *cls) { return machold_class_createInstance((uint8_t *)cls, 0); }
static void *machold_NSStringFromClass(void *cls) {
    if (!cls) return NULL;
    uintptr_t data = *(uintptr_t *)((char *)cls + MACHO_CM_DATA_OFF) & ~(uintptr_t)0x7;
    const char *nm = data ? *(const char **)(data + 24) : "";
    return machold_make_string(nm, (long)strlen(nm));
}
static long machold_os_feature_off(void) { return 0; }
static char machold_NSIsNSString(void *o) { return machold_obj_type(o) == 0 ? 1 : 0; }
static void *machold_alloc_obj_array(unsigned long n) { return calloc(n ? n : 1, sizeof(void *)); }
static void machold_free_obj_array(void *a, unsigned long n) { (void)n; free(a); }
static void *machold_swift_castObjC(void *obj, void *cls) {
    if (obj && !machold_is_machold_class(*(void **)obj)) return obj;   // foreign (Swift): let the Swift bridge take it
    return machold_objc_isKind(obj, cls) ? obj : NULL;
}
static void *machold_ident1(void *a) { return a; }   // swift_getObjCClassMetadata / _bridgeAnyObjectToObjectiveC

// ── NSJSONSerialization / NSPropertyListSerialization (routed to FoundationFusion.swift) ──
// Class-method trampolines: read the input NSData bytes ({isa, bytes@8, len@16}), call the
// Swift helper (dlsym'd from libcompat_host), and return the machold-native tree it built; or
// serialize a machold-native tree → a fresh NSData. NSData arg/return keeps it messageable.
static machold_class_t machold_nsjson_cls, machold_nsjson_meta, machold_nsplist_cls, machold_nsplist_meta;
static void *machold_json_parse(void *cls, const char *cmd, void *data, unsigned long opts, void **err) {
    (void)cls; (void)cmd; (void)opts; if (err) *err = NULL; if (!data) return NULL;
    void *(*fn)(const void *, long) = (void *(*)(const void *, long))dlsym(RTLD_DEFAULT, "machold_fusion_json_parse");
    long len; const void *b = machold_nsdata_ptr(data, &len);
    return fn ? fn(b, len) : NULL;
}
static void *machold_json_serialize(void *cls, const char *cmd, void *obj, unsigned long opts, void **err) {
    (void)cls; (void)cmd; if (err) *err = NULL; long n = 0;
    void *(*fn)(void *, long *, int) = (void *(*)(void *, long *, int))dlsym(RTLD_DEFAULT, "machold_fusion_json_serialize");
    void *buf = fn ? fn(obj, &n, (opts & 1) ? 1 : 0) : NULL;   // NSJSONWritingPrettyPrinted = 1
    if (!buf) return NULL;
    void *d = machold_make_data(buf, n); free(buf); return d;
}
static void *machold_plist_parse(void *cls, const char *cmd, void *data, unsigned long opts, void *fmtOut, void **err) {
    (void)cls; (void)cmd; (void)opts; if (err) *err = NULL; if (!data) return NULL;
    int fmt = 0;
    void *(*fn)(const void *, long, int *) = (void *(*)(const void *, long, int *))dlsym(RTLD_DEFAULT, "machold_fusion_plist_parse");
    long len; const void *b = machold_nsdata_ptr(data, &len);
    void *r = fn ? fn(b, len, &fmt) : NULL;
    if (fmtOut) *(long *)fmtOut = fmt ? 200 : 100;   // NSPropertyListBinaryFormat_v1_0=200, XML=100
    return r;
}
static void *machold_plist_serialize(void *cls, const char *cmd, void *obj, unsigned long fmt, unsigned long opts, void **err) {
    (void)cls; (void)cmd; (void)opts; if (err) *err = NULL; long n = 0;
    void *(*fn)(void *, int, long *) = (void *(*)(void *, int, long *))dlsym(RTLD_DEFAULT, "machold_fusion_plist_serialize");
    void *buf = fn ? fn(obj, (fmt == 200) ? 1 : 0, &n) : NULL;
    if (!buf) return NULL;
    void *d = machold_make_data(buf, n); free(buf); return d;
}
static machold_mlist_t machold_nsjson_cm, machold_nsplist_cm;
static machold_class_ro_t machold_nsjson_ro, machold_nsjson_mro, machold_nsplist_ro, machold_nsplist_mro;
static int machold_nsjson_inited = 0;
static void machold_init_serializers(void) {
    if (machold_nsjson_inited) return; machold_nsjson_inited = 1;
    machold_init_nsobject(); machold_init_nsdata();
    machold_method_t jcm[] = {
        {"JSONObjectWithData:options:error:", "@32#0:8@16Q24^@28", (void *)machold_json_parse},
        {"dataWithJSONObject:options:error:", "@32#0:8@16Q24^@28", (void *)machold_json_serialize},
    };
    machold_method_t pcm[] = {
        {"propertyListWithData:options:format:error:", "@40#0:8@16Q24^Q32^@36", (void *)machold_plist_parse},
        {"dataWithPropertyList:format:options:error:", "@40#0:8@16Q24Q32^@36", (void *)machold_plist_serialize},
    };
    machold_nsjson_cm.entsize = sizeof(machold_method_t); machold_nsjson_cm.count = sizeof(jcm)/sizeof(jcm[0]);
    memcpy(machold_nsjson_cm.methods, jcm, sizeof(jcm));
    machold_nsplist_cm.entsize = sizeof(machold_method_t); machold_nsplist_cm.count = sizeof(pcm)/sizeof(pcm[0]);
    memcpy(machold_nsplist_cm.methods, pcm, sizeof(pcm));
    machold_nsjson_ro.flags = 0; machold_nsjson_ro.instanceSize = 16; machold_nsjson_ro.name = "NSJSONSerialization";
    machold_nsjson_mro.flags = 0x1; machold_nsjson_mro.instanceSize = 40; machold_nsjson_mro.name = "NSJSONSerialization";
    machold_nsjson_mro.baseMethods = &machold_nsjson_cm;
    machold_nsjson_cls.isa = &machold_nsjson_meta; machold_nsjson_cls.superclass = &machold_nsobj_cls;
    machold_nsjson_cls.data = (uintptr_t)&machold_nsjson_ro;
    machold_nsjson_meta.isa = &machold_nsobj_meta; machold_nsjson_meta.superclass = &machold_nsobj_meta;
    machold_nsjson_meta.data = (uintptr_t)&machold_nsjson_mro;
    machold_register_class("NSJSONSerialization", &machold_nsjson_cls);
    machold_nsplist_ro.flags = 0; machold_nsplist_ro.instanceSize = 16; machold_nsplist_ro.name = "NSPropertyListSerialization";
    machold_nsplist_mro.flags = 0x1; machold_nsplist_mro.instanceSize = 40; machold_nsplist_mro.name = "NSPropertyListSerialization";
    machold_nsplist_mro.baseMethods = &machold_nsplist_cm;
    machold_nsplist_cls.isa = &machold_nsplist_meta; machold_nsplist_cls.superclass = &machold_nsobj_cls;
    machold_nsplist_cls.data = (uintptr_t)&machold_nsplist_ro;
    machold_nsplist_meta.isa = &machold_nsobj_meta; machold_nsplist_meta.superclass = &machold_nsobj_meta;
    machold_nsplist_meta.data = (uintptr_t)&machold_nsplist_mro;
    machold_register_class("NSPropertyListSerialization", &machold_nsplist_cls);
}

// ── NSDateFormatter (wrapped through the bridge) ──────────────────────────────
// {isa, dateFormat@8 (NSString)}. Formats/parses NSDate ({isa, double time@8}) via the Swift
// DateFormatter helper — reuses machold NSString/NSDate, so results are messageable.
static machold_class_t machold_df_cls, machold_df_meta;
static void *machold_df_init(void *self, const char *cmd) { (void)cmd; return self; }
static void machold_df_setFormat(void *self, const char *cmd, void *fmt) { (void)cmd; *(void **)((char *)self + 8) = fmt; }
static void *machold_df_format(void *self, const char *cmd) { (void)cmd; return *(void **)((char *)self + 8); }
static void *machold_df_stringFromDate(void *self, const char *cmd, void *date) {
    (void)cmd;
    double ts = date ? *(double *)((char *)date + 8) : 0;
    void *f = *(void **)((char *)self + 8);
    const char *fmt = f ? *(const char **)((char *)f + 16) : ""; long flen = f ? *(long *)((char *)f + 24) : 0;
    long n = 0;
    void *(*fn)(double, const char *, long, long *) = (void *(*)(double, const char *, long, long *))dlsym(RTLD_DEFAULT, "machold_fusion_date_format");
    void *buf = fn ? fn(ts, fmt, flen, &n) : NULL;
    if (!buf) return machold_make_string("", 0);
    void *s = machold_make_string((const char *)buf, n); free(buf); return s;
}
static void *machold_df_dateFromString(void *self, const char *cmd, void *str) {
    (void)cmd;
    const char *s = str ? *(const char **)((char *)str + 16) : ""; long slen = str ? *(long *)((char *)str + 24) : 0;
    void *f = *(void **)((char *)self + 8);
    const char *fmt = f ? *(const char **)((char *)f + 16) : ""; long flen = f ? *(long *)((char *)f + 24) : 0;
    double (*fn)(const char *, long, const char *, long) = (double (*)(const char *, long, const char *, long))dlsym(RTLD_DEFAULT, "machold_fusion_date_parse");
    double ts = fn ? fn(s, slen, fmt, flen) : 0.0;
    if (!fn || ts != ts) return NULL;   // NaN → nil
    return machold_make_date(ts);
}
static machold_mlist_t machold_df_m;
static machold_class_ro_t machold_df_ro, machold_df_mro;
static int machold_df_inited = 0;
static void machold_init_dateformatter(void) {
    if (machold_df_inited) return; machold_df_inited = 1;
    machold_init_nsobject(); machold_init_nsdate();
    machold_method_t m[] = {
        {"init", "@16@0:8", (void *)machold_df_init},
        {"setDateFormat:", "v24@0:8@16", (void *)machold_df_setFormat},
        {"dateFormat", "@16@0:8", (void *)machold_df_format},
        {"stringFromDate:", "@24@0:8@16", (void *)machold_df_stringFromDate},
        {"dateFromString:", "@24@0:8@16", (void *)machold_df_dateFromString},
    };
    machold_df_m.entsize = sizeof(machold_method_t); machold_df_m.count = sizeof(m)/sizeof(m[0]);
    memcpy(machold_df_m.methods, m, sizeof(m));
    machold_df_ro.flags = 0; machold_df_ro.instanceSize = 16; machold_df_ro.name = "NSDateFormatter";
    machold_df_ro.baseMethods = &machold_df_m;
    machold_df_mro.flags = 0x1; machold_df_mro.instanceSize = 40; machold_df_mro.name = "NSDateFormatter";
    machold_df_cls.isa = &machold_df_meta; machold_df_cls.superclass = &machold_nsobj_cls;
    machold_df_cls.data = (uintptr_t)&machold_df_ro;
    machold_df_meta.isa = &machold_nsobj_meta; machold_df_meta.superclass = &machold_nsobj_meta;
    machold_df_meta.data = (uintptr_t)&machold_df_mro;
    machold_register_class("NSDateFormatter", &machold_df_cls);
}

// ── NSFileHandle / NSAutoreleasePool / NSCharacterSet (real CLI-tool plumbing) ──
// NSFileHandle {isa, long fd@8}: how tools write output (fileHandleWithStandardOutput +
// writeData:). NSAutoreleasePool is a no-op (machold never autoreleases). NSCharacterSet is
// minimal (whitespace membership) for string trimming.
static machold_class_t machold_fh_cls, machold_fh_meta;
static machold_class_t machold_nsarp_cls, machold_nsarp_meta;
static machold_class_t machold_chset_cls, machold_chset_meta;
static void machold_init_filehandle(void), machold_init_nsarp(void), machold_init_charset(void);

static void *machold_fh_make(long fd) {
    machold_init_filehandle();
    void *o = machold_class_createInstance((uint8_t *)&machold_fh_cls, 0);
    *(long *)((char *)o + 8) = fd; return o;
}
static void *machold_fh_stdout(void *cls, const char *cmd) { (void)cls; (void)cmd; return machold_fh_make(1); }
static void *machold_fh_stderr(void *cls, const char *cmd) { (void)cls; (void)cmd; return machold_fh_make(2); }
static void *machold_fh_stdin(void *cls, const char *cmd)  { (void)cls; (void)cmd; return machold_fh_make(0); }
static long machold_fh_fd(void *self, const char *cmd) { (void)cmd; return *(long *)((char *)self + 8); }
static void machold_fh_writeData(void *self, const char *cmd, void *data) {
    (void)cmd; if (!data) return;
    const void *b; long n;
    if (machold_obj_type(data) == 4) {                    // machold NSData
        b = *(void **)((char *)data + 8); n = *(long *)((char *)data + 16);
    } else {                                              // real Linux CF/NS data
        const void *(*gp)(void *) = (const void *(*)(void *))dlsym(RTLD_DEFAULT, "CFDataGetBytePtr");
        long (*gl)(void *) = (long (*)(void *))dlsym(RTLD_DEFAULT, "CFDataGetLength");
        b = gp ? gp(data) : NULL; n = gl ? gl(data) : 0;
    }
    if (g_verbose) fprintf(stderr, "[machold] writeData fd=%ld type=%d len=%ld\n", *(long *)((char *)self + 8), machold_obj_type(data), n);
    if (b && n > 0) { ssize_t w = write((int)*(long *)((char *)self + 8), b, (size_t)n); (void)w; }
}
static void machold_init_filehandle(void) {
    static int done = 0; if (done) return; done = 1; machold_init_nsobject();
    static machold_mlist_t m; static machold_mlist_t cm; static machold_class_ro_t ro, mro;
    machold_method_t im[] = {
        {"writeData:", "v24@0:8@16", (void *)machold_fh_writeData},
        {"fileDescriptor", "i16@0:8", (void *)machold_fh_fd},
    };
    machold_method_t icm[] = {
        {"fileHandleWithStandardOutput", "@16#0:8", (void *)machold_fh_stdout},
        {"fileHandleWithStandardError", "@16#0:8", (void *)machold_fh_stderr},
        {"fileHandleWithStandardInput", "@16#0:8", (void *)machold_fh_stdin},
    };
    m.entsize = sizeof(machold_method_t); m.count = sizeof(im)/sizeof(im[0]); memcpy(m.methods, im, sizeof(im));
    cm.entsize = sizeof(machold_method_t); cm.count = sizeof(icm)/sizeof(icm[0]); memcpy(cm.methods, icm, sizeof(icm));
    ro.flags = 0; ro.instanceSize = 16; ro.name = "NSFileHandle"; ro.baseMethods = &m;
    mro.flags = 0x1; mro.instanceSize = 40; mro.name = "NSFileHandle"; mro.baseMethods = &cm;
    machold_fh_cls.isa = &machold_fh_meta; machold_fh_cls.superclass = &machold_nsobj_cls; machold_fh_cls.data = (uintptr_t)&ro;
    machold_fh_meta.isa = &machold_nsobj_meta; machold_fh_meta.superclass = &machold_nsobj_meta; machold_fh_meta.data = (uintptr_t)&mro;
    machold_register_class("NSFileHandle", &machold_fh_cls);
}
static void *machold_nsarp_self(void *self, const char *cmd) { (void)cmd; return self; }
static void machold_nsarp_noop(void *self, const char *cmd) { (void)self; (void)cmd; }
static void machold_init_nsarp(void) {
    static int done = 0; if (done) return; done = 1; machold_init_nsobject();
    static machold_mlist_t m; static machold_class_ro_t ro, mro;
    machold_method_t im[] = {
        {"init", "@16@0:8", (void *)machold_nsarp_self},
        {"drain", "v16@0:8", (void *)machold_nsarp_noop},
        {"release", "v16@0:8", (void *)machold_nsarp_noop},
    };
    m.entsize = sizeof(machold_method_t); m.count = sizeof(im)/sizeof(im[0]); memcpy(m.methods, im, sizeof(im));
    ro.flags = 0; ro.instanceSize = 16; ro.name = "NSAutoreleasePool"; ro.baseMethods = &m;
    mro.flags = 0x1; mro.instanceSize = 40; mro.name = "NSAutoreleasePool";
    machold_nsarp_cls.isa = &machold_nsarp_meta; machold_nsarp_cls.superclass = &machold_nsobj_cls; machold_nsarp_cls.data = (uintptr_t)&ro;
    machold_nsarp_meta.isa = &machold_nsobj_meta; machold_nsarp_meta.superclass = &machold_nsobj_meta; machold_nsarp_meta.data = (uintptr_t)&mro;
    machold_register_class("NSAutoreleasePool", &machold_nsarp_cls);
}
static char machold_charset_member(void *self, const char *cmd, unsigned short c) {
    (void)self; (void)cmd; return (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f' || c == 0x0b) ? 1 : 0;
}
static void *machold_charset_shared(void *cls, const char *cmd) { (void)cmd; machold_init_charset(); return machold_class_createInstance((uint8_t *)&machold_chset_cls, 0); }
static void *machold_charset_withString(void *cls, const char *cmd, void *s) { (void)cmd; (void)s; return machold_charset_shared(cls, cmd); }
static void machold_init_charset(void) {
    static int done = 0; if (done) return; done = 1; machold_init_nsobject();
    static machold_mlist_t m; static machold_mlist_t cm; static machold_class_ro_t ro, mro;
    machold_method_t im[] = { {"characterIsMember:", "c18@0:8S16", (void *)machold_charset_member} };
    machold_method_t icm[] = {
        {"whitespaceCharacterSet", "@16#0:8", (void *)machold_charset_shared},
        {"whitespaceAndNewlineCharacterSet", "@16#0:8", (void *)machold_charset_shared},
        {"newlineCharacterSet", "@16#0:8", (void *)machold_charset_shared},
        {"characterSetWithCharactersInString:", "@24#0:8@16", (void *)machold_charset_withString},
    };
    m.entsize = sizeof(machold_method_t); m.count = sizeof(im)/sizeof(im[0]); memcpy(m.methods, im, sizeof(im));
    cm.entsize = sizeof(machold_method_t); cm.count = sizeof(icm)/sizeof(icm[0]); memcpy(cm.methods, icm, sizeof(icm));
    ro.flags = 0; ro.instanceSize = 16; ro.name = "NSCharacterSet"; ro.baseMethods = &m;
    mro.flags = 0x1; mro.instanceSize = 40; mro.name = "NSCharacterSet"; mro.baseMethods = &cm;
    machold_chset_cls.isa = &machold_chset_meta; machold_chset_cls.superclass = &machold_nsobj_cls; machold_chset_cls.data = (uintptr_t)&ro;
    machold_chset_meta.isa = &machold_nsobj_meta; machold_chset_meta.superclass = &machold_nsobj_meta; machold_chset_meta.data = (uintptr_t)&mro;
    machold_register_class("NSCharacterSet", &machold_chset_cls);
}
// NSSearchPathForDirectoriesInDomains → empty array (no macOS dir layout on Linux).
static void *machold_nssearchpath(unsigned long d, unsigned long dom, signed char expand) {
    (void)d; (void)dom; (void)expand; return machold_arr_new();
}
static char machold_ehtype_id[64];   // _OBJC_EHTYPE_id dummy (exception type-info; never introspected)

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - AppKit → Flutter render bridge (tier-2 GUI, G-series)
// ══════════════════════════════════════════════════════════════════════════════
// An unmodified ObjC/AppKit app builds an NSWindow of NSViews and calls [NSApp run].
// Instead of WindowServer, our -[NSApplication run] walks the key window's view tree into
// the SAME RNode JSON the Flutter host renders (Host.swift) and calls swiftui_compat_run
// (blocks in the GLFW loop). Reuses the entire tier-1 render path.
//   NSApplication instance {isa@0, void* delegate@8}
//   NSWindow      {isa@0, void* contentView@8, void* title@16}
//   NSView        {isa@0, void** subviews@8, long count@16, long cap@24}   (like an array)
//   NSTextField   {isa@0, void* stringValue@8}
//   NSButton      {isa@0, void* title@8, void* target@16, const char* action@24}
static machold_class_t machold_nsapp_cls, machold_nsapp_meta;
static machold_class_t machold_nswindow_cls, machold_nswindow_meta;
static machold_class_t machold_nsview_cls, machold_nsview_meta;
static machold_class_t machold_nstextfield_cls, machold_nstextfield_meta;
static machold_class_t machold_nsbutton_cls, machold_nsbutton_meta;
static machold_class_t machold_nsstackview_cls, machold_nsstackview_meta;
static machold_class_t machold_nsslider_cls, machold_nsslider_meta;
static machold_class_t machold_nsimage_cls, machold_nsimage_meta;
static machold_class_t machold_nsimageview_cls, machold_nsimageview_meta;
static machold_class_t machold_nsprogress_cls, machold_nsprogress_meta;
static machold_class_t machold_nstableview_cls, machold_nstableview_meta;
static machold_class_t machold_nstablecol_cls, machold_nstablecol_meta;
static machold_class_t machold_nspopup_cls, machold_nspopup_meta;
static void *g_key_window = NULL;
static void *g_shared_app = NULL;
static void machold_init_appkit(void);

// JSON helpers (C): quote+escape a string; walk a view subtree into RNode JSON.
static void machold_json_str(FILE *out, const char *s) {
    fputc('"', out);
    for (const char *p = s ? s : ""; *p; p++) {
        if (*p == '"' || *p == '\\') { fputc('\\', out); fputc(*p, out); }
        else if (*p == '\n') fputs("\\n", out);
        else fputc(*p, out);
    }
    fputc('"', out);
}
// Per-button dispatch registry (filled during the tree walk; used by swiftui_compat_dispatch).
// popup/optidx are set for NSPopUpButton options: dispatch sets the popup's selectedIndex.
static struct { void *target; const char *action; void *sender; void *popup; long optidx; } g_btn[256];
static int g_btn_n = 0;
// Per-editable-field registry (filled during the walk; used by swiftui_compat_text).
static struct { void *field; void *target; const char *action; void *delegate; } g_field[128];
static int g_field_n = 0;
// Display bytes for an object we can stringify (our NSString/NSMutableString: char* @16).
static const char *machold_display_bytes(void *o) {
    if (!o) return NULL;
    void *isa = *(void **)o;
    if (isa == &machold_cfstring_cls || isa == &machold_mstr_cls) return *(const char **)((char *)o + 16);
    return NULL;
}
static void machold_json_view(FILE *out, void *v);
static void machold_json_column(FILE *out, void *container) {   // container = an NSView
    void **subs = *(void ***)((char *)container + 8);
    long n = *(long *)((char *)container + 16);
    fputs("{\"t\":\"column\",\"sp\":12,\"align\":0,\"children\":[", out);
    for (long i = 0; i < n; i++) { if (i) fputc(',', out); machold_json_view(out, subs[i]); }
    fputs("]}", out);
}
static void machold_json_view(FILE *out, void *v) {
    if (!v) { fputs("{\"t\":\"empty\"}", out); return; }
    void *isa = *(void **)v;
    if (isa == &machold_nstextfield_cls) {
        void *sv = *(void **)((char *)v + 8);
        const char *s = sv ? *(const char **)((char *)sv + 16) : "";
        if (*(long *)((char *)v + 16)) {   // editable → textfield node + register for text dispatch
            int fid = g_field_n < 128 ? g_field_n++ : 0;
            g_field[fid].field = v; g_field[fid].target = *(void **)((char *)v + 24);
            g_field[fid].action = *(const char **)((char *)v + 32); g_field[fid].delegate = *(void **)((char *)v + 40);
            fprintf(out, "{\"t\":\"textfield\",\"id\":%d,\"text\":", fid);
            machold_json_str(out, s); fputc('}', out);
        } else {
            fputs("{\"t\":\"text\",\"s\":", out); machold_json_str(out, s); fputc('}', out);
        }
    } else if (isa == &machold_nsbutton_cls) {
        int id = g_btn_n < 256 ? g_btn_n++ : 0;
        g_btn[id].target = *(void **)((char *)v + 16);
        g_btn[id].action = *(const char **)((char *)v + 24);
        g_btn[id].sender = v; g_btn[id].popup = NULL;
        void *title = *(void **)((char *)v + 8);
        const char *ts = title ? *(const char **)((char *)title + 16) : "";
        long kind = *(long *)((char *)v + 32);
        fprintf(out, "{\"t\":\"button\",\"id\":%d,\"child\":{\"t\":\"text\",\"s\":", id);
        if (kind == 1) {   // checkbox: prefix an ASCII marker reflecting state (font-safe)
            char label[512];
            snprintf(label, sizeof(label), "[%s] %s", (*(long *)((char *)v + 40) ? "x" : " "), ts);
            machold_json_str(out, label);
        } else {
            machold_json_str(out, ts);
        }
        fputs("}}", out);
    } else if (isa == &machold_nspopup_cls) {
        // NSPopUpButton → picker node: options + selectedIndex + a dispatch id per option.
        void **titles = *(void ***)((char *)v + 8); long n = *(long *)((char *)v + 16);
        long sel = *(long *)((char *)v + 32);
        fputs("{\"t\":\"picker\",\"label\":{\"t\":\"text\",\"s\":\"\"},\"options\":[", out);
        for (long i = 0; i < n; i++) {
            if (i) fputc(',', out);
            const char *ts = machold_display_bytes(titles[i]);
            fputs("{\"t\":\"text\",\"s\":", out); machold_json_str(out, ts ? ts : ""); fputc('}', out);
        }
        fprintf(out, "],\"sel\":%ld,\"ids\":[", sel);
        for (long i = 0; i < n; i++) {
            if (i) fputc(',', out);
            int bid = g_btn_n < 256 ? g_btn_n++ : 0;
            g_btn[bid].popup = v; g_btn[bid].optidx = i; g_btn[bid].sender = v;
            g_btn[bid].target = *(void **)((char *)v + 40); g_btn[bid].action = *(const char **)((char *)v + 48);
            fprintf(out, "%d", bid);
        }
        fputs("]}", out);
    } else if (isa == &machold_nsslider_cls) {
        double val = *(double *)((char *)v + 8), mn = *(double *)((char *)v + 16), mx = *(double *)((char *)v + 24);
        double frac = (mx > mn) ? (val - mn) / (mx - mn) : 0;
        fprintf(out, "{\"t\":\"slider\",\"value\":%g}", frac);
    } else if (isa == &machold_nsimageview_cls) {
        void *img = *(void **)((char *)v + 8);                 // NSImage
        void *nm = img ? *(void **)((char *)img + 8) : NULL;   // NSString (symbol/name)
        fputs("{\"t\":\"image\",\"name\":", out);
        machold_json_str(out, nm ? *(const char **)((char *)nm + 16) : "");
        fputc('}', out);
    } else if (isa == &machold_nsprogress_cls) {
        double val = *(double *)((char *)v + 8), mn = *(double *)((char *)v + 16), mx = *(double *)((char *)v + 24);
        if (*(long *)((char *)v + 32)) fputs("{\"t\":\"progress\",\"value\":null}", out);   // indeterminate
        else fprintf(out, "{\"t\":\"progress\",\"value\":%g}", (mx > mn) ? (val - mn) / (mx - mn) : val);
    } else if (isa == &machold_nsstackview_cls) {
        long orient = *(long *)((char *)v + 32);   // NSUserInterfaceLayoutOrientation: 0=horizontal, 1=vertical
        void **subs = *(void ***)((char *)v + 8); long n = *(long *)((char *)v + 16);
        fprintf(out, "{\"t\":\"%s\",\"sp\":12,\"align\":1,\"children\":[", orient == 0 ? "row" : "column");
        for (long i = 0; i < n; i++) { if (i) fputc(',', out); machold_json_view(out, subs[i]); }
        fputs("]}", out);
    } else if (isa == &machold_nstableview_cls) {
        // Pull the data by messaging the dataSource (numberOfRowsInTableView: then
        // tableView:objectValueForTableColumn:row: per row) → a column of text rows.
        void *ds = *(void **)((char *)v + 8);
        void **cols = *(void ***)((char *)v + 16); long ncol = *(long *)((char *)v + 24);
        void *col0 = ncol ? cols[0] : NULL;
        long nrows = 0; void *ovImp = NULL;
        if (ds) {
            void *nrImp = machold_lookup_imp_from_class(*(uint8_t **)ds, "numberOfRowsInTableView:");
            if (nrImp) nrows = ((long (*)(void *, const char *, void *))nrImp)(ds, "numberOfRowsInTableView:", v);
            ovImp = machold_lookup_imp_from_class(*(uint8_t **)ds, "tableView:objectValueForTableColumn:row:");
        }
        fputs("{\"t\":\"column\",\"sp\":6,\"align\":0,\"children\":[", out);
        for (long r = 0; r < nrows; r++) {
            if (r) fputc(',', out);
            void *val = ovImp ? ((void *(*)(void *, const char *, void *, void *, long))ovImp)
                                    (ds, "tableView:objectValueForTableColumn:row:", v, col0, r) : NULL;
            const char *s = machold_display_bytes(val);
            fputs("{\"t\":\"text\",\"s\":", out); machold_json_str(out, s ? s : ""); fputc('}', out);
        }
        fputs("]}", out);
    } else {   // a plain NSView container → column of its subviews
        machold_json_column(out, v);
    }
}

// NSView
static void machold_view_addSubview(void *self, const char *cmd, void *sub) {
    (void)cmd; char *s = (char *)self;
    void **items = *(void ***)(s + 8); long count = *(long *)(s + 16), cap = *(long *)(s + 24);
    if (count >= cap) { cap = cap ? cap * 2 : 4; items = (void **)realloc(items, (size_t)cap * sizeof(void *));
                        *(void ***)(s + 8) = items; *(long *)(s + 24) = cap; }
    items[count] = sub; *(long *)(s + 16) = count + 1;
}
static void machold_view_setFrame(void *self, const char *cmd, double x, double y, double w, double h) {
    (void)self; (void)cmd; (void)x; (void)y; (void)w; (void)h;   // host lays out; frames ignored
}
static void *machold_make_view(void) {
    machold_init_appkit();
    return machold_class_createInstance((uint8_t *)&machold_nsview_cls, 0);
}

// NSTextField
static void *machold_tf_label(void *cls, const char *cmd, void *str) {   // +labelWithString:
    (void)cls; (void)cmd;
    machold_init_appkit();
    void *o = machold_class_createInstance((uint8_t *)&machold_nstextfield_cls, 0);
    *(void **)((char *)o + 8) = str;
    return o;
}
static void machold_tf_setString(void *self, const char *cmd, void *str) { (void)cmd; *(void **)((char *)self + 8) = str; }
static void *machold_tf_stringValue(void *self, const char *cmd) { (void)cmd; return *(void **)((char *)self + 8); }
// Editable field: {isa, stringValue@8, long editable@16, target@24, action@32, delegate@40} = 48.
static void *machold_tf_field(void *cls, const char *cmd, void *str) {   // +textFieldWithString:
    (void)cls; (void)cmd; machold_init_appkit();
    void *o = machold_class_createInstance((uint8_t *)&machold_nstextfield_cls, 0);
    *(void **)((char *)o + 8) = str; *(long *)((char *)o + 16) = 1;   // editable
    return o;
}
static void machold_tf_setEditable(void *self, const char *cmd, long e) { (void)cmd; *(long *)((char *)self + 16) = e; }
static void machold_tf_setTarget(void *self, const char *cmd, void *t) { (void)cmd; *(void **)((char *)self + 24) = t; }
static void machold_tf_setAction(void *self, const char *cmd, const char *a) { (void)cmd; *(const char **)((char *)self + 32) = a; }
static void machold_tf_setDelegate(void *self, const char *cmd, void *d) { (void)cmd; *(void **)((char *)self + 40) = d; }

// NSButton {isa, title@8, target@16, action@24, long kind@32 (0=push,1=checkbox), long state@40}
static void *machold_btn_mk(void *title, void *target, const char *action, long kind) {
    machold_init_appkit();
    void *o = machold_class_createInstance((uint8_t *)&machold_nsbutton_cls, 0);
    *(void **)((char *)o + 8) = title; *(void **)((char *)o + 16) = target;
    *(const char **)((char *)o + 24) = action; *(long *)((char *)o + 32) = kind;
    return o;
}
static void *machold_btn_make(void *cls, const char *cmd, void *title, void *target, const char *action) {
    (void)cls; (void)cmd; return machold_btn_mk(title, target, action, 0);
}
static void *machold_checkbox_make(void *cls, const char *cmd, void *title, void *target, const char *action) {
    (void)cls; (void)cmd; return machold_btn_mk(title, target, action, 1);
}
static void machold_btn_setTitle(void *self, const char *cmd, void *t) { (void)cmd; *(void **)((char *)self + 8) = t; }
static void machold_btn_setTarget(void *self, const char *cmd, void *t) { (void)cmd; *(void **)((char *)self + 16) = t; }
static void machold_btn_setAction(void *self, const char *cmd, const char *a) { (void)cmd; *(const char **)((char *)self + 24) = a; }
static long machold_btn_state(void *self, const char *cmd) { (void)cmd; return *(long *)((char *)self + 40); }
static void machold_btn_setState(void *self, const char *cmd, long s) { (void)cmd; *(long *)((char *)self + 40) = s; }
static void machold_btn_setButtonType(void *self, const char *cmd, long t) {   // NSButtonTypeSwitch=3 → checkbox
    (void)cmd; if (t == 3 || t == 4) *(long *)((char *)self + 32) = 1;
}

// NSStackView (layout container: subviews@8/count@16/cap@24 like NSView + orientation@32)
static void machold_stack_setOrientation(void *self, const char *cmd, long o) { (void)cmd; *(long *)((char *)self + 32) = o; }
static void machold_stack_setSpacing(void *self, const char *cmd, double s) { (void)self; (void)cmd; (void)s; }  // host spaces

// NSSlider {isa, double value@8, min@16, max@24}
static void *machold_slider_make(void *cls, const char *cmd, double v, double mn, double mx, void *target, const char *action) {
    (void)cls; (void)cmd; (void)target; (void)action;
    machold_init_appkit();
    void *o = machold_class_createInstance((uint8_t *)&machold_nsslider_cls, 0);
    *(double *)((char *)o + 8) = v; *(double *)((char *)o + 16) = mn; *(double *)((char *)o + 24) = mx;
    return o;
}
static double machold_slider_double(void *self, const char *cmd) { (void)cmd; return *(double *)((char *)self + 8); }
static void machold_slider_setDouble(void *self, const char *cmd, double v) { (void)cmd; *(double *)((char *)self + 8) = v; }

// NSImage {isa, void* name@8 (NSString symbol/name)} — a value holder for the walk.
static void *machold_image_symbol(void *cls, const char *cmd, void *name, void *desc) {
    (void)cls; (void)cmd; (void)desc; machold_init_appkit();
    void *o = machold_class_createInstance((uint8_t *)&machold_nsimage_cls, 0);
    *(void **)((char *)o + 8) = name; return o;
}
static void *machold_image_named(void *cls, const char *cmd, void *name) {
    (void)cls; (void)cmd; machold_init_appkit();
    void *o = machold_class_createInstance((uint8_t *)&machold_nsimage_cls, 0);
    *(void **)((char *)o + 8) = name; return o;
}
// NSImageView {isa, void* image@8}
static void *machold_imageview_make(void *cls, const char *cmd, void *image) {
    (void)cls; (void)cmd; machold_init_appkit();
    void *o = machold_class_createInstance((uint8_t *)&machold_nsimageview_cls, 0);
    *(void **)((char *)o + 8) = image; return o;
}
static void machold_imageview_setImage(void *self, const char *cmd, void *image) { (void)cmd; *(void **)((char *)self + 8) = image; }
// NSProgressIndicator {isa, double value@8, min@16, max@24, long indeterminate@32}
static void machold_prog_setDouble(void *self, const char *cmd, double v) { (void)cmd; *(double *)((char *)self + 8) = v; }
static void machold_prog_setMin(void *self, const char *cmd, double v) { (void)cmd; *(double *)((char *)self + 16) = v; }
static void machold_prog_setMax(void *self, const char *cmd, double v) { (void)cmd; *(double *)((char *)self + 24) = v; }
static void machold_prog_setIndeterminate(void *self, const char *cmd, long v) { (void)cmd; *(long *)((char *)self + 32) = v; }

// NSTableView {isa, dataSource@8, void** cols@16, long ncol@24, long cap@32}
static void machold_table_setDataSource(void *self, const char *cmd, void *d) { (void)cmd; *(void **)((char *)self + 8) = d; }
static void machold_table_addColumn(void *self, const char *cmd, void *col) {
    (void)cmd; char *s = (char *)self;
    void **cols = *(void ***)(s + 16); long n = *(long *)(s + 24), cap = *(long *)(s + 32);
    if (n >= cap) { cap = cap ? cap * 2 : 4; cols = (void **)realloc(cols, (size_t)cap * sizeof(void *));
                    *(void ***)(s + 16) = cols; *(long *)(s + 32) = cap; }
    cols[n] = col; *(long *)(s + 24) = n + 1;
}
static void machold_noop0(void *self, const char *cmd) { (void)self; (void)cmd; }   // reloadData etc.
// NSTableColumn {isa, identifier@8, title@16}
static void *machold_col_init(void *self, const char *cmd, void *ident) { (void)cmd; *(void **)((char *)self + 8) = ident; return self; }
static void machold_col_setTitle(void *self, const char *cmd, void *t) { (void)cmd; *(void **)((char *)self + 16) = t; }
static void *machold_col_title(void *self, const char *cmd) { (void)cmd; return *(void **)((char *)self + 16); }

// NSPopUpButton {isa, void** titles@8, long ntitles@16, cap@24, selectedIndex@32, target@40, action@48}
static void machold_popup_append(void *self, void *title) {
    char *s = (char *)self;
    void **t = *(void ***)(s + 8); long n = *(long *)(s + 16), cap = *(long *)(s + 24);
    if (n >= cap) { cap = cap ? cap * 2 : 4; t = (void **)realloc(t, (size_t)cap * sizeof(void *));
                    *(void ***)(s + 8) = t; *(long *)(s + 24) = cap; }
    t[n] = title; *(long *)(s + 16) = n + 1;
}
static void machold_popup_addItem(void *self, const char *cmd, void *title) { (void)cmd; machold_popup_append(self, title); }
static void machold_popup_addItems(void *self, const char *cmd, void *arr) {   // addItemsWithTitles: (an NSArray)
    (void)cmd; if (!arr) return;
    void *cntImp = machold_lookup_imp_from_class(*(uint8_t **)arr, "count");
    long n = cntImp ? ((long (*)(void *, const char *))cntImp)(arr, "count") : 0;
    void *objImp = machold_lookup_imp_from_class(*(uint8_t **)arr, "objectAtIndex:");
    for (long i = 0; i < n && objImp; i++)
        machold_popup_append(self, ((void *(*)(void *, const char *, long))objImp)(arr, "objectAtIndex:", i));
}
static void machold_popup_selectIndex(void *self, const char *cmd, long i) { (void)cmd; *(long *)((char *)self + 32) = i; }
static long machold_popup_selectedIndex(void *self, const char *cmd) { (void)cmd; return *(long *)((char *)self + 32); }
static long machold_popup_numberOfItems(void *self, const char *cmd) { (void)cmd; return *(long *)((char *)self + 16); }
static void *machold_popup_titleOfSelected(void *self, const char *cmd) {
    (void)cmd; char *s = (char *)self; long sel = *(long *)(s + 32), n = *(long *)(s + 16);
    return (sel >= 0 && sel < n) ? (*(void ***)(s + 8))[sel] : NULL;
}
static void machold_popup_setTarget(void *self, const char *cmd, void *t) { (void)cmd; *(void **)((char *)self + 40) = t; }
static void machold_popup_setAction(void *self, const char *cmd, const char *a) { (void)cmd; *(const char **)((char *)self + 48) = a; }

// NSWindow
static void *machold_win_init(void *self, const char *cmd, double x, double y, double w, double h,
                              unsigned long styleMask, unsigned long backing, signed char defer) {
    (void)cmd; (void)x; (void)y; (void)w; (void)h; (void)styleMask; (void)backing; (void)defer;
    *(void **)((char *)self + 8) = machold_make_view();   // contentView
    *(void **)((char *)self + 16) = NULL;                 // title
    return self;
}
static void machold_win_setTitle(void *self, const char *cmd, void *t) { (void)cmd; *(void **)((char *)self + 16) = t; }
static void *machold_win_contentView(void *self, const char *cmd) { (void)cmd; return *(void **)((char *)self + 8); }
static void machold_win_setContentView(void *self, const char *cmd, void *v) { (void)cmd; *(void **)((char *)self + 8) = v; }
static void machold_win_makeKey(void *self, const char *cmd, void *sender) { (void)cmd; (void)sender; g_key_window = self; }

// NSApplication
static void *machold_app_shared(void *cls, const char *cmd) {
    (void)cmd; machold_init_appkit();
    if (!g_shared_app) g_shared_app = machold_class_createInstance((uint8_t *)&machold_nsapp_cls, 0);
    return g_shared_app;
}
static void machold_app_setDelegate(void *self, const char *cmd, void *d) { (void)cmd; *(void **)((char *)self + 8) = d; }
static void *machold_app_delegate(void *self, const char *cmd) { (void)cmd; return *(void **)((char *)self + 8); }
static void machold_app_noopArg(void *self, const char *cmd, void *a) { (void)self; (void)cmd; (void)a; }   // setActivationPolicy:/activateIgnoringOtherApps:
// Build the key window's RNode JSON (fresh — re-walked on each render). Caller frees.
static char *machold_build_window_json(void) {
    char *buf = NULL; size_t sz = 0;
    FILE *ms = open_memstream(&buf, &sz);
    g_btn_n = 0; g_field_n = 0;
    if (g_key_window) machold_json_view(ms, *(void **)((char *)g_key_window + 8));   // contentView (NSView or NSStackView)
    else fputs("{\"t\":\"empty\"}", ms);
    fclose(ms);
    return buf;
}
static void *machold_app_run(void *self, const char *cmd) {
    (void)cmd;
    // Fire applicationDidFinishLaunching: on the delegate (window may be built there).
    void *d = *(void **)((char *)self + 8);
    if (d) {
        void *imp = machold_lookup_imp_from_class(*(uint8_t **)d, "applicationDidFinishLaunching:");
        if (imp) ((void (*)(void *, const char *, void *))imp)(d, "applicationDidFinishLaunching:", NULL);
    }
    char *json = machold_build_window_json();
    void (*run)(const char *) = (void (*)(const char *))dlsym(RTLD_DEFAULT, "swiftui_compat_run");
    if (g_verbose) fprintf(stderr, "[machold] NSApplication run → swiftui_compat_run: %s\n", json);
    if (run) run(json);   // BLOCKS in the Flutter/GLFW loop
    free(json);
    return NULL;
}

static int machold_appkit_inited = 0;
static void machold_mk_class(machold_class_t *cls, machold_class_t *meta, machold_class_ro_t *ro,
                             machold_class_ro_t *mro, machold_mlist_t *ml, machold_mlist_t *cml,
                             uint32_t instSize, const char *name) {
    ml->entsize = sizeof(machold_method_t);
    ro->flags = 0; ro->instanceSize = instSize; ro->name = name; ro->baseMethods = ml;
    mro->flags = 0x1; mro->instanceSize = 40; mro->name = name; mro->baseMethods = cml;
    cml->entsize = sizeof(machold_method_t);
    cls->isa = meta; cls->superclass = &machold_nsobj_cls; cls->data = (uintptr_t)ro;
    meta->isa = &machold_nsobj_meta; meta->superclass = &machold_nsobj_meta; meta->data = (uintptr_t)mro;
    machold_register_class(name, cls);
}
static machold_mlist_t machold_nsapp_m, machold_nsapp_cm, machold_nswindow_m, machold_nswindow_cm,
                       machold_nsview_m, machold_nsview_cm, machold_nstf_m, machold_nstf_cm,
                       machold_nsbtn_m, machold_nsbtn_cm, machold_nsstack_m, machold_nsstack_cm,
                       machold_nsslider_m, machold_nsslider_cm, machold_nsimage_m, machold_nsimage_cm,
                       machold_nsimgview_m, machold_nsimgview_cm, machold_nsprog_m, machold_nsprog_cm,
                       machold_nstable_m, machold_nstable_cm, machold_nstablecol_m, machold_nstablecol_cm,
                       machold_nspopup_m, machold_nspopup_cm;
static machold_class_ro_t machold_nsapp_ro, machold_nsapp_mro, machold_nswindow_ro, machold_nswindow_mro,
                          machold_nsview_ro, machold_nsview_mro, machold_nstf_ro, machold_nstf_mro,
                          machold_nsbtn_ro, machold_nsbtn_mro, machold_nsstack_ro, machold_nsstack_mro,
                          machold_nsslider_ro, machold_nsslider_mro, machold_nsimage_ro, machold_nsimage_mro,
                          machold_nsimgview_ro, machold_nsimgview_mro, machold_nsprog_ro, machold_nsprog_mro,
                          machold_nstable_ro, machold_nstable_mro, machold_nstablecol_ro, machold_nstablecol_mro,
                          machold_nspopup_ro, machold_nspopup_mro;
static void machold_init_appkit(void) {
    if (machold_appkit_inited) return; machold_appkit_inited = 1;
    machold_init_nsobject();
    machold_method_t app_m[] = {
        {"setActivationPolicy:", "c24@0:8q16", (void *)machold_app_noopArg},
        {"activateIgnoringOtherApps:", "v24@0:8c16", (void *)machold_app_noopArg},
        {"setDelegate:", "v24@0:8@16", (void *)machold_app_setDelegate},
        {"delegate", "@16@0:8", (void *)machold_app_delegate},
        {"run", "v16@0:8", (void *)machold_app_run},
    };
    machold_method_t app_cm[] = { {"sharedApplication", "@16#0:8", (void *)machold_app_shared} };
    machold_method_t win_m[] = {
        {"initWithContentRect:styleMask:backing:defer:", "@56@0:8{CGRect={CGPoint=dd}{CGSize=dd}}16Q48Q56c64", (void *)machold_win_init},
        {"setTitle:", "v24@0:8@16", (void *)machold_win_setTitle},
        {"contentView", "@16@0:8", (void *)machold_win_contentView},
        {"setContentView:", "v24@0:8@16", (void *)machold_win_setContentView},
        {"makeKeyAndOrderFront:", "v24@0:8@16", (void *)machold_win_makeKey},
    };
    machold_method_t view_m[] = {
        {"addSubview:", "v24@0:8@16", (void *)machold_view_addSubview},
        {"setFrame:", "v48@0:8{CGRect={CGPoint=dd}{CGSize=dd}}16", (void *)machold_view_setFrame},
    };
    machold_method_t tf_m[] = {
        {"setStringValue:", "v24@0:8@16", (void *)machold_tf_setString},
        {"stringValue", "@16@0:8", (void *)machold_tf_stringValue},
        {"setEditable:", "v24@0:8c16", (void *)machold_tf_setEditable},
        {"setTarget:", "v24@0:8@16", (void *)machold_tf_setTarget},
        {"setAction:", "v24@0:8:16", (void *)machold_tf_setAction},
        {"setDelegate:", "v24@0:8@16", (void *)machold_tf_setDelegate},
        {"setPlaceholderString:", "v24@0:8@16", (void *)machold_app_noopArg},
        {"setBezeled:", "v24@0:8c16", (void *)machold_app_noopArg},
        {"setFrame:", "v48@0:8{CGRect=}16", (void *)machold_view_setFrame},
        {"addSubview:", "v24@0:8@16", (void *)machold_view_addSubview},
    };
    machold_method_t tf_cm[] = {
        {"labelWithString:", "@24#0:8@16", (void *)machold_tf_label},
        {"textFieldWithString:", "@24#0:8@16", (void *)machold_tf_field},
        {"wrappingLabelWithString:", "@24#0:8@16", (void *)machold_tf_label},
    };
    machold_method_t btn_m[] = {
        {"setTitle:", "v24@0:8@16", (void *)machold_btn_setTitle},
        {"setTarget:", "v24@0:8@16", (void *)machold_btn_setTarget},
        {"setAction:", "v24@0:8:16", (void *)machold_btn_setAction},
        {"state", "q16@0:8", (void *)machold_btn_state},
        {"setState:", "v24@0:8q16", (void *)machold_btn_setState},
        {"setButtonType:", "v24@0:8Q16", (void *)machold_btn_setButtonType},
        {"setFrame:", "v48@0:8{CGRect=}16", (void *)machold_view_setFrame},
        {"addSubview:", "v24@0:8@16", (void *)machold_view_addSubview},
    };
    machold_method_t btn_cm[] = {
        {"buttonWithTitle:target:action:", "@40#0:8@16@24:32", (void *)machold_btn_make},
        {"checkboxWithTitle:target:action:", "@40#0:8@16@24:32", (void *)machold_checkbox_make},
    };
    machold_method_t stack_m[] = {
        {"addArrangedSubview:", "v24@0:8@16", (void *)machold_view_addSubview},
        {"addSubview:", "v24@0:8@16", (void *)machold_view_addSubview},
        {"setOrientation:", "v24@0:8q16", (void *)machold_stack_setOrientation},
        {"setSpacing:", "v24@0:8d16", (void *)machold_stack_setSpacing},
        {"setDistribution:", "v24@0:8q16", (void *)machold_app_noopArg},   // ignored (host distributes)
        {"setAlignment:", "v24@0:8q16", (void *)machold_app_noopArg},
    };
    machold_method_t slider_m[] = {
        {"doubleValue", "d16@0:8", (void *)machold_slider_double},
        {"floatValue", "f16@0:8", (void *)machold_slider_double},
        {"setDoubleValue:", "v24@0:8d16", (void *)machold_slider_setDouble},
    };
    machold_method_t slider_cm[] = {
        {"sliderWithValue:minValue:maxValue:target:action:", "@56#0:8d16d24d32@40:48", (void *)machold_slider_make},
    };
    machold_method_t image_cm[] = {
        {"imageWithSystemSymbolName:accessibilityDescription:", "@32#0:8@16@24", (void *)machold_image_symbol},
        {"imageNamed:", "@24#0:8@16", (void *)machold_image_named},
    };
    machold_method_t imgview_cm[] = { {"imageViewWithImage:", "@24#0:8@16", (void *)machold_imageview_make} };
    machold_method_t imgview_m[] = { {"setImage:", "v24@0:8@16", (void *)machold_imageview_setImage} };
    machold_method_t prog_m[] = {
        {"setDoubleValue:", "v24@0:8d16", (void *)machold_prog_setDouble},
        {"setMinValue:", "v24@0:8d16", (void *)machold_prog_setMin},
        {"setMaxValue:", "v24@0:8d16", (void *)machold_prog_setMax},
        {"setIndeterminate:", "v24@0:8c16", (void *)machold_prog_setIndeterminate},
        {"startAnimation:", "v24@0:8@16", (void *)machold_app_noopArg},
        {"stopAnimation:", "v24@0:8@16", (void *)machold_app_noopArg},
    };
    machold_method_t table_m[] = {
        {"setDataSource:", "v24@0:8@16", (void *)machold_table_setDataSource},
        {"setDelegate:", "v24@0:8@16", (void *)machold_app_noopArg},
        {"addTableColumn:", "v24@0:8@16", (void *)machold_table_addColumn},
        {"reloadData", "v16@0:8", (void *)machold_noop0},
        {"setFrame:", "v48@0:8{CGRect=}16", (void *)machold_view_setFrame},
        {"setUsesAlternatingRowBackgroundColors:", "v24@0:8c16", (void *)machold_app_noopArg},
    };
    machold_method_t col_m[] = {
        {"initWithIdentifier:", "@24@0:8@16", (void *)machold_col_init},
        {"setTitle:", "v24@0:8@16", (void *)machold_col_setTitle},
        {"title", "@16@0:8", (void *)machold_col_title},
        {"setWidth:", "v24@0:8d16", (void *)machold_stack_setSpacing},
    };
    machold_method_t popup_m[] = {
        {"addItemWithTitle:", "v24@0:8@16", (void *)machold_popup_addItem},
        {"addItemsWithTitles:", "v24@0:8@16", (void *)machold_popup_addItems},
        {"selectItemAtIndex:", "v24@0:8q16", (void *)machold_popup_selectIndex},
        {"indexOfSelectedItem", "q16@0:8", (void *)machold_popup_selectedIndex},
        {"numberOfItems", "q16@0:8", (void *)machold_popup_numberOfItems},
        {"titleOfSelectedItem", "@16@0:8", (void *)machold_popup_titleOfSelected},
        {"setTarget:", "v24@0:8@16", (void *)machold_popup_setTarget},
        {"setAction:", "v24@0:8:16", (void *)machold_popup_setAction},
        {"setFrame:", "v48@0:8{CGRect=}16", (void *)machold_view_setFrame},
    };
    #define MCOPY(dst, src) do { (dst).count = sizeof(src)/sizeof((src)[0]); memcpy((dst).methods, src, sizeof(src)); } while (0)
    MCOPY(machold_nsapp_m, app_m);  MCOPY(machold_nsapp_cm, app_cm);
    MCOPY(machold_nswindow_m, win_m);
    MCOPY(machold_nsview_m, view_m);
    MCOPY(machold_nstf_m, tf_m);    MCOPY(machold_nstf_cm, tf_cm);
    MCOPY(machold_nsbtn_m, btn_m);  MCOPY(machold_nsbtn_cm, btn_cm);
    MCOPY(machold_nsstack_m, stack_m);
    MCOPY(machold_nsslider_m, slider_m); MCOPY(machold_nsslider_cm, slider_cm);
    MCOPY(machold_nsimage_cm, image_cm);
    MCOPY(machold_nsimgview_m, imgview_m); MCOPY(machold_nsimgview_cm, imgview_cm);
    MCOPY(machold_nsprog_m, prog_m);
    MCOPY(machold_nstable_m, table_m);
    MCOPY(machold_nstablecol_m, col_m);
    MCOPY(machold_nspopup_m, popup_m);
    #undef MCOPY
    machold_mk_class(&machold_nsapp_cls, &machold_nsapp_meta, &machold_nsapp_ro, &machold_nsapp_mro,
                     &machold_nsapp_m, &machold_nsapp_cm, 16, "NSApplication");
    machold_mk_class(&machold_nswindow_cls, &machold_nswindow_meta, &machold_nswindow_ro, &machold_nswindow_mro,
                     &machold_nswindow_m, &machold_nswindow_cm, 24, "NSWindow");
    machold_mk_class(&machold_nsview_cls, &machold_nsview_meta, &machold_nsview_ro, &machold_nsview_mro,
                     &machold_nsview_m, &machold_nsview_cm, 32, "NSView");
    machold_mk_class(&machold_nstextfield_cls, &machold_nstextfield_meta, &machold_nstf_ro, &machold_nstf_mro,
                     &machold_nstf_m, &machold_nstf_cm, 48, "NSTextField");
    machold_mk_class(&machold_nsbutton_cls, &machold_nsbutton_meta, &machold_nsbtn_ro, &machold_nsbtn_mro,
                     &machold_nsbtn_m, &machold_nsbtn_cm, 48, "NSButton");
    machold_mk_class(&machold_nsstackview_cls, &machold_nsstackview_meta, &machold_nsstack_ro, &machold_nsstack_mro,
                     &machold_nsstack_m, &machold_nsstack_cm, 40, "NSStackView");
    machold_mk_class(&machold_nsslider_cls, &machold_nsslider_meta, &machold_nsslider_ro, &machold_nsslider_mro,
                     &machold_nsslider_m, &machold_nsslider_cm, 32, "NSSlider");
    machold_mk_class(&machold_nsimage_cls, &machold_nsimage_meta, &machold_nsimage_ro, &machold_nsimage_mro,
                     &machold_nsimage_m, &machold_nsimage_cm, 16, "NSImage");
    machold_mk_class(&machold_nsimageview_cls, &machold_nsimageview_meta, &machold_nsimgview_ro, &machold_nsimgview_mro,
                     &machold_nsimgview_m, &machold_nsimgview_cm, 16, "NSImageView");
    machold_mk_class(&machold_nsprogress_cls, &machold_nsprogress_meta, &machold_nsprog_ro, &machold_nsprog_mro,
                     &machold_nsprog_m, &machold_nsprog_cm, 40, "NSProgressIndicator");
    machold_mk_class(&machold_nstableview_cls, &machold_nstableview_meta, &machold_nstable_ro, &machold_nstable_mro,
                     &machold_nstable_m, &machold_nstable_cm, 40, "NSTableView");
    machold_mk_class(&machold_nstablecol_cls, &machold_nstablecol_meta, &machold_nstablecol_ro, &machold_nstablecol_mro,
                     &machold_nstablecol_m, &machold_nstablecol_cm, 24, "NSTableColumn");
    machold_mk_class(&machold_nspopup_cls, &machold_nspopup_meta, &machold_nspopup_ro, &machold_nspopup_mro,
                     &machold_nspopup_m, &machold_nspopup_cm, 56, "NSPopUpButton");
}
// objc autorelease pool (no-op; our objects leak — fine for the compat host).
static void *machold_arp_push(void) { return NULL; }
static void machold_arp_pop(void *token) { (void)token; }

// libSystem/BSD shims for real CLI tools (e.g. /usr/bin/arch). arch prints
// NXGetLocalArchInfo()->name. Real NXArchInfo layout (mach-o/arch.h) has NAME FIRST:
// {const char* name; cpu_type_t cputype; cpu_subtype_t cpusubtype; NXByteOrder byteorder;
// const char* description}. The spawn/env helpers are only used by `arch -arch X cmd`, not the
// print path, but all imports must resolve to load — bind them to harmless stubs.
static struct { const char *name; int cputype, cpusubtype, byteorder, pad; const char *description; }
    g_nxarch = { "arm64", 0x0100000C /* CPU_TYPE_ARM64 */, 0 /* ARM64_ALL */, 1 /* NX_LittleEndian */, 0, "ARM64" };
static void *machold_nx_local(void) { return &g_nxarch; }
static void *machold_nx_fromcpu(int t, int s) { (void)t; (void)s; return &g_nxarch; }
static const char *machold_getprogname(void) { return "arch"; }
static void machold_errc(int e) { exit(e ? e : 1); }                              // err(3): print+exit
static int machold_sysctlbyname(const char *n, void *op, void *olp, void *np, unsigned long nl) {
    (void)n; (void)op; (void)olp; (void)np; (void)nl; return -1;                  // unknown key
}

// Disable all PAC keys for this thread via a RAW prctl syscall (not the glibc wrapper):
// arm64e code signs pointers with PAC, but machold binds them unsigned, so on a PAC-enabled
// CPU aut*/braa would fault. With SCTLR_EL1.En{IA,IB,DA,DB,GA}=0 the pac*/aut* instructions
// become NOPs and unsigned pointers are used verbatim. A raw svc avoids glibc's prctl wrapper
// frame (if glibc is built pac-ret, its live IA-signed return would make the kernel refuse to
// disable IA); machold itself is built without pac-ret. Returns 0 on success, -errno on error.
#define MACHOLD_PR_PAC_SET_ENABLED_KEYS 60
// Only the four ADDRESS keys are toggleable via this prctl (kernel PR_PAC_ENABLED_KEYS_MASK);
// the generic key (APGAKEY, 0x10) is rejected with EINVAL and doesn't need disabling (pacga/
// autga are self-consistent within the binary).
#define MACHOLD_PR_PAC_ALLKEYS 0x0f   /* APIAKEY|APIBKEY|APDAKEY|APDBKEY */
static long machold_raw_syscall5(long nr, long a0, long a1, long a2, long a3, long a4) {
    register long x8 __asm__("x8") = nr;
    register long x0 __asm__("x0") = a0;
    register long x1 __asm__("x1") = a1;
    register long x2 __asm__("x2") = a2;
    register long x3 __asm__("x3") = a3;
    register long x4 __asm__("x4") = a4;
    __asm__ volatile("svc #0" : "+r"(x0)
                     : "r"(x8), "r"(x1), "r"(x2), "r"(x3), "r"(x4) : "memory", "cc");
    return x0;
}
__attribute__((noinline)) static void machold_disable_pac(void) {
    long r = machold_raw_syscall5(167 /* __NR_prctl */, MACHOLD_PR_PAC_SET_ENABLED_KEYS,
                                  MACHOLD_PR_PAC_ALLKEYS, 0 /* enabled=0 → disable */, 0, 0);
    LOG("arm64e: raw prctl(PR_PAC_SET_ENABLED_KEYS, disable-all) = %ld%s\n",
        r, r ? " (FAILED — PAC keys NOT disabled)" : " (PAC disabled)");
}

// libSystem shims for real Mach-O binaries (not our probes). Darwin's typed malloc
// (malloc_type_*) carries a type-id trailing arg we ignore → plain malloc/calloc/realloc.
static void *machold_mtype_malloc(size_t s, unsigned long t) { (void)t; return malloc(s); }
static void *machold_mtype_calloc(size_t c, size_t s, unsigned long t) { (void)t; return calloc(c, s); }
static void *machold_mtype_realloc(void *p, size_t s, unsigned long t) { (void)t; return realloc(p, s); }
static void *machold_ret_null(void) { return NULL; }

// Fabricate the macOS version dictionary a real system binary reads (sw_vers uses
// __CFCopySupplementalVersionDictionary as its source; nil → its "missing or malformed"
// error). Build a real CFDictionary via the Linux CF fork, keyed by the standard
// SystemVersion.plist strings (which CFEqual-match the kCFSystemVersion*Key constants).
static void *machold_cf_version_dict(void) {
    void *(*mkstr)(void *, const char *, unsigned) =
        (void *(*)(void *, const char *, unsigned))dlsym(RTLD_DEFAULT, "CFStringCreateWithCString");
    void *(*mkdict)(void *, const void **, const void **, long, const void *, const void *) =
        (void *(*)(void *, const void **, const void **, long, const void *, const void *))dlsym(RTLD_DEFAULT, "CFDictionaryCreate");
    void *kcbK = dlsym(RTLD_DEFAULT, "kCFTypeDictionaryKeyCallBacks");
    void *kcbV = dlsym(RTLD_DEFAULT, "kCFTypeDictionaryValueCallBacks");
    // Use Linux CF's OWN constant CFStrings as keys (they're properly Swift-bridged; a
    // C-created CFString fails _CFSwiftGetHash's dynamic cast during dict lookup).
    void **pName  = (void **)dlsym(RTLD_DEFAULT, "_kCFSystemVersionProductNameKey");
    void **pVer   = (void **)dlsym(RTLD_DEFAULT, "_kCFSystemVersionProductVersionKey");
    void **pBuild = (void **)dlsym(RTLD_DEFAULT, "_kCFSystemVersionBuildVersionKey");
    (void)kcbK; (void)kcbV;
    if (!mkstr || !mkdict || !pName || !pVer || !pBuild || !*pName || !*pVer || !*pBuild) return NULL;
    const unsigned utf8 = 0x08000100;
    // Keys = Linux CF's OWN constant CFStrings (the same objects sw_vers looks up with), and
    // NULL callbacks → pointer hash/equality. So the lookup matches by pointer and never hits
    // Linux CF's Swift-bridged _CFSwiftGetHash, which dynamic-cast-crashes on these objects.
    const void *keys[3] = { *pName, *pVer, *pBuild };
    const void *vals[3] = { mkstr(NULL, "macOS", utf8), mkstr(NULL, "14.5", utf8),
                            mkstr(NULL, "23F79-machold", utf8) };
    return mkdict(NULL, keys, vals, 3, NULL, NULL);
}

// Supply macOS OS-data a real system binary reads. sw_vers loads /System/Library/Core
// Services/SystemVersion.plist via CFURLCreateDataAndPropertiesFromResource — which fails on
// Linux (no such file). Intercept it: for a SystemVersion path, hand back a fabricated plist
// as CFData (the real Linux CFPropertyListCreateWithData then parses it into the version dict);
// any other path falls through to the real Linux CF. This is OS-data emulation, not a runtime
// change — the binary runs unmodified and does its real work on the data we provide.
static unsigned char machold_cf_urlread(void *alloc, void *url, void **outData, void **outProps,
                                        void *desired, int *errCode) {
    static const char plist[] =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<plist version=\"1.0\"><dict>\n"
        "<key>ProductName</key><string>macOS</string>\n"
        "<key>ProductVersion</key><string>14.5</string>\n"
        "<key>ProductUserVisibleVersion</key><string>14.5</string>\n"
        "<key>ProductBuildVersion</key><string>23F79-machold</string>\n"
        "<key>ProductCopyright</key><string>1983-2026 Apple Inc.</string>\n"
        "</dict></plist>\n";
    int is_ver = 1;   // default true (sw_vers only reads the version plist)
    void *(*urlpath)(void *, long) = (void *(*)(void *, long))dlsym(RTLD_DEFAULT, "CFURLCopyFileSystemPath");
    unsigned char (*getcstr)(void *, char *, long, unsigned) =
        (unsigned char (*)(void *, char *, long, unsigned))dlsym(RTLD_DEFAULT, "CFStringGetCString");
    if (urlpath && getcstr && url) {
        void *ps = urlpath(url, 0 /* kCFURLPOSIXPathStyle */);
        char buf[1024] = "";
        if (ps) { getcstr(ps, buf, sizeof(buf), 0x08000100 /* UTF8 */); is_ver = (strstr(buf, "SystemVersion") != NULL); }
        if (g_verbose) fprintf(stderr, "[machold] CFURLread path=\"%s\" fabricate=%d\n", buf, is_ver);
    }
    if (is_ver) {
        void *(*mkdata)(void *, const unsigned char *, long) =
            (void *(*)(void *, const unsigned char *, long))dlsym(RTLD_DEFAULT, "CFDataCreate");
        if (outData) *outData = mkdata ? mkdata(NULL, (const unsigned char *)plist, (long)(sizeof(plist) - 1)) : NULL;
        if (outProps) *outProps = NULL;
        if (errCode) *errCode = 0;
        return 1;
    }
    unsigned char (*real)(void *, void *, void **, void **, void *, int *) =
        (unsigned char (*)(void *, void *, void **, void **, void *, int *))
        dlsym(RTLD_DEFAULT, "CFURLCreateDataAndPropertiesFromResource");
    return real ? real(alloc, url, outData, outProps, desired, errCode) : 0;
}
// Darwin stdio globals (___stdinp/___stdoutp/___stderrp) are FILE* VARIABLES; a data import
// binds the slot to the variable's address, so return &(a static holding the glibc stream).
static FILE *g_darwin_stdin, *g_darwin_stdout, *g_darwin_stderr;

// Host→app tap dispatch. The Flutter host calls swiftui_compat_dispatch(id) on a tap.
// machold OWNS this symbol (build.sh --export-dynamic → main-exe def wins the host's
// RTLD_NOW bind over libSwiftUI's). For an AppKit app (g_key_window set), route the id to
// the registered NSButton's ObjC target/action = objc_msgSend(target, action, button),
// then re-walk the window and push via swiftui_compat_update. Otherwise (tier-1 Swift)
// forward to libSwiftUI's definition via RTLD_NEXT so @State/actions still work.
void swiftui_compat_dispatch(long id) {
    if (g_key_window && id >= 0 && id < g_btn_n && (g_btn[id].target || g_btn[id].popup)) {
        void *snd = g_btn[id].sender;
        if (g_btn[id].popup)                 // NSPopUpButton option: set the selection first
            *(long *)((char *)g_btn[id].popup + 32) = g_btn[id].optidx;   // selectedIndex
        else if (snd && *(void **)snd == &machold_nsbutton_cls && *(long *)((char *)snd + 32) == 1)
            *(long *)((char *)snd + 40) ^= 1;   // AppKit flips a checkbox's state before its action
        if (g_trace_objc)
            fprintf(stderr, "[machold] AppKit tap id=%ld → %s\n", id, g_btn[id].action ? g_btn[id].action : "(select)");
        if (g_btn[id].target && g_btn[id].action) {
            void *imp = machold_lookup_imp_from_class(*(uint8_t **)g_btn[id].target, g_btn[id].action);
            if (imp) ((void (*)(void *, const char *, void *))imp)(g_btn[id].target, g_btn[id].action, snd);
        }
        char *json = machold_build_window_json();          // re-render (action may have mutated state)
        void (*upd)(const char *) = (void (*)(const char *))dlsym(RTLD_DEFAULT, "swiftui_compat_update");
        if (upd) upd(json);
        free(json);
        return;
    }
    void (*next)(long) = (void (*)(long))dlsym(RTLD_NEXT, "swiftui_compat_dispatch");   // tier-1 SwiftUI
    if (next) next(id);
}

// Host→app text-field submit. machold owns swiftui_compat_text (export-dynamic): set the
// NSTextField's stringValue to the typed text, then fire its target/action (or notify its
// delegate via controlTextDidEndEditing:), re-walk, and push. Forwards to any tier-1 def.
void swiftui_compat_text(long id, const char *text) {
    if (g_key_window && id >= 0 && id < g_field_n && g_field[id].field) {
        void *f = g_field[id].field;
        *(void **)((char *)f + 8) = machold_make_string(text ? text : "", text ? (long)strlen(text) : 0);
        void *tgt = g_field[id].target; const char *act = g_field[id].action;
        if (g_trace_objc) fprintf(stderr, "[machold] AppKit text id=%ld = %s\n", id, text ? text : "");
        if (tgt && act) {
            void *imp = machold_lookup_imp_from_class(*(uint8_t **)tgt, act);
            if (imp) ((void (*)(void *, const char *, void *))imp)(tgt, act, f);
        } else if (g_field[id].delegate) {
            void *d = g_field[id].delegate;
            void *imp = machold_lookup_imp_from_class(*(uint8_t **)d, "controlTextDidEndEditing:");
            if (imp) ((void (*)(void *, const char *, void *))imp)(d, "controlTextDidEndEditing:", NULL);
        }
        char *json = machold_build_window_json();
        void (*upd)(const char *) = (void (*)(const char *))dlsym(RTLD_DEFAULT, "swiftui_compat_update");
        if (upd) upd(json);
        free(json);
        return;
    }
    void (*next)(long, const char *) = (void (*)(long, const char *))dlsym(RTLD_NEXT, "swiftui_compat_text");
    if (next) next(id, text);
}

// ── Runtime type-lookup module rewrite (Foundation `10Foundation` → split modules) ──
// macOS declares Data/UUID/Date in module `Foundation` (`10Foundation`); the Linux toolchain
// splits them into FoundationEssentials (`20…`) / FoundationInternationalization (`30…`). The
// loader rewrites that for symbol *binding* (dlsym); this is the runtime analogue for code
// that resolves types by mangled name via `swift_getTypeByMangledName…2`. Interpose: for a
// `10Foundation` name, try the split modules first, then the original. The binary calls these
// with context=genericArgs=0 (verified by disasm), so plain C wrappers are ABI-safe.
//
// ⚠️ 2026-06-08 (cont.): this was built to test the "module identity breaks runtime type
// lookup" theory for FoundationProbe — and that theory is **DISPROVEN**. With both wrappers
// installed + MACHOLD_TYPELOG, the probe makes ZERO `10Foundation` runtime lookups (it gets
// its Foundation types via direct metadata-symbol imports, which the loader already binds).
// So this does NOT fix FoundationProbe; its crash is elsewhere (still unpinned — see worklist).
// Kept as correct, harmless infrastructure (passthrough for non-Foundation names) that a
// fuller third-party app may actually exercise.
typedef const void *(*gettype2_fn)(const char *, unsigned long, const void *, const void *const *);
static gettype2_fn g_real_gettype2 = 0;

// Length-aware replace of the textual module prefix `10Foundation` with `to`, src[len] →
// dst[cap]. Returns the new length, or 0 if `10Foundation` was absent or dst overflowed.
static unsigned long rewrite_module_name(const char *src, unsigned long len,
                                         const char *to, char *dst, unsigned long cap) {
    const char *from = "10Foundation";
    unsigned long flen = 12, tlen = strlen(to), di = 0; int did = 0;
    for (unsigned long i = 0; i < len; ) {
        if (i + flen <= len && memcmp(src + i, from, flen) == 0) {
            if (di + tlen > cap) return 0;
            memcpy(dst + di, to, tlen); di += tlen; i += flen; did = 1;
        } else {
            if (di >= cap) return 0;
            dst[di++] = src[i++];
        }
    }
    return did ? di : 0;
}

static const void *machold_getType2(const char *name, unsigned long len,
                                    const void *ctx, const void *const *args) {
    int has_fnd = (memmem(name, len, "10Foundation", 12) != NULL);
    if (g_typelog && has_fnd) {
        fprintf(stderr, "[machold] type-lookup 10Foundation (len=%lu): ", len);
        for (unsigned long i = 0; i < len && i < 140; i++) {
            char c = name[i]; fputc((c >= 32 && c < 127) ? c : '.', stderr);
        }
        fputc('\n', stderr);
    }
    if (has_fnd) {
        char buf[4096];
        unsigned long n = rewrite_module_name(name, len, "20FoundationEssentials", buf, sizeof buf);
        if (n) { const void *r = g_real_gettype2(buf, n, ctx, args); if (r) return r; }
        n = rewrite_module_name(name, len, "30FoundationInternationalization", buf, sizeof buf);
        if (n) { const void *r = g_real_gettype2(buf, n, ctx, args); if (r) return r; }
    }
    return g_real_gettype2(name, len, ctx, args);
}

// The MetadataState variant (used by …FromMangledNameAbstractV2): args
// (state x0, name x1, len x2, ctx x3, genericArgs x4); returns MetadataResponse {md, state}.
typedef struct { const void *md; unsigned long st; } machold_metaresp;
typedef machold_metaresp (*gettypeMS2_fn)(unsigned long, const char *, unsigned long,
                                          const void *, const void *const *);
static gettypeMS2_fn g_real_gettypeMS2 = 0;

static machold_metaresp machold_getTypeMS2(unsigned long state, const char *name,
                                           unsigned long len, const void *ctx,
                                           const void *const *args) {
    int has_fnd = (memmem(name, len, "10Foundation", 12) != NULL);
    if (g_typelog && has_fnd) {
        fprintf(stderr, "[machold] type-lookup(MS) 10Foundation (len=%lu): ", len);
        for (unsigned long i = 0; i < len && i < 140; i++) {
            char c = name[i]; fputc((c >= 32 && c < 127) ? c : '.', stderr);
        }
        fputc('\n', stderr);
    }
    if (has_fnd) {
        char buf[4096];
        unsigned long n = rewrite_module_name(name, len, "20FoundationEssentials", buf, sizeof buf);
        if (n) { machold_metaresp r = g_real_gettypeMS2(state, buf, n, ctx, args); if (r.md) return r; }
        n = rewrite_module_name(name, len, "30FoundationInternationalization", buf, sizeof buf);
        if (n) { machold_metaresp r = g_real_gettypeMS2(state, buf, n, ctx, args); if (r.md) return r; }
    }
    return g_real_gettypeMS2(state, name, len, ctx, args);
}

// ── Calling-convention adapter for State.projectedValue ──────────────────────
// Apple's SwiftUI binary returns the 17-byte Binding from this getter via sret
// (the AAPCS ">16 bytes → indirect" rule), so it sets x8 = result buffer and reads
// the Binding from there. But Swift 6.2.4 returns ≤4-field structs in REGISTERS, so
// our reconstructed getter leaves that buffer unwritten → the binary gets garbage.
// We can't change that in the struct (a resilient Binding fixes the return but flips
// the by-value PASS into a by-pointer pass). So interpose a trampoline: the binary
// calls us (x8=sret, x20=self, x0=State<Value> metadata); we call the real getter
// (which returns Binding in x0/x1/x2), then store those into the binary's sret buf.
// Witness-convention dispatch trampoline for ContiguousBytes.withUnsafeBytes — see the
// interpose in resolve_symbol below. x4 = witness table; slot 1 holds the witness for
// the protocol's single requirement. Everything else stays in the registers the caller
// set up (the witness shares the thunk's calling convention).
__attribute__((naked, used))
static void machold_cb_withUnsafeBytes_Tj(void) {
    __asm__ volatile(
        "ldr x9, [x4, #8]\n\t"
        "br  x9");
}

// ── ObjC-interop class realization (for ObservableObject's `class M: …`) ─────────
// Darwin builds Swift with SWIFT_OBJC_INTEROP=on, so the binary's model classes are
// ObjC-interop Swift classes: their metadata carries an ObjC class header (isa,
// superclass, cache, data) BEFORE the Swift fields, is rooted at `_SwiftObject`, and is
// realized by `swift_updateClassMetadata2`. The Linux runtime has none of this. But
// objc_msgSend==0 across all our probes — the class only needs to be REALIZABLE and
// allocatable, never messageable — so we synthesize the four missing pieces with NO ObjC
// runtime. The binary itself reads instanceSize/field-offsets at the macOS (interop)
// offsets and passes explicit args to the Linux runtime (swift_allocObject etc.), so the
// ONLY function that must interpret the macOS metadata layout is the one we implement here.
//
// macOS ObjC-interop ClassMetadata field byte-offsets:
//   isa@0 superclass@8 cacheData@16,24 data@32 flags@40 instanceAddressPoint@44
//   instanceSize@48 instanceAlignMask@52
#define MACHO_CM_SUPERCLASS        8
#define MACHO_CM_CACHE             16
#define MACHO_CM_DATA              32
#define MACHO_CM_INSTANCESIZE      48
#define MACHO_CM_INSTANCEALIGNMASK 52

static int g_trace_meta = 0;                            // MACHOLD_TRACE_META: log class realization
static uint8_t machold_objc_empty_cache[256];           // zeroed; never used (no msgSend)
static uint8_t machold_SwiftObject_meta[128];           // _SwiftObject metaclass (macOS layout)
static uint8_t machold_SwiftObject_class[128];          // _SwiftObject class (root, instanceSize 16)
static int machold_swiftobject_inited = 0;
static void machold_init_swiftobject(void) {
    if (machold_swiftobject_inited) return;
    machold_swiftobject_inited = 1;
    // metaclass: isa→self (root metaclass), superclass→NULL, cache→empty, instanceSize 40
    *(void **)(machold_SwiftObject_meta + 0)            = machold_SwiftObject_meta;
    *(void **)(machold_SwiftObject_meta + MACHO_CM_CACHE) = machold_objc_empty_cache;
    *(uint32_t *)(machold_SwiftObject_meta + MACHO_CM_INSTANCESIZE) = 40;
    *(uint16_t *)(machold_SwiftObject_meta + MACHO_CM_INSTANCEALIGNMASK) = 7;
    // class: isa→metaclass, superclass→NULL (it's the root), cache→empty, instanceSize 16
    //   (a bare Swift heap object = isa(8) + refcount(8)).
    *(void **)(machold_SwiftObject_class + 0)            = machold_SwiftObject_meta;
    *(void **)(machold_SwiftObject_class + MACHO_CM_CACHE) = machold_objc_empty_cache;
    *(uint32_t *)(machold_SwiftObject_class + MACHO_CM_INSTANCESIZE) = 16;
    *(uint16_t *)(machold_SwiftObject_class + MACHO_CM_INSTANCEALIGNMASK) = 7;
}

// MetadataDependency = { const Metadata *Value; size_t Requirement } — returned in x0:x1.
typedef struct { void *Value; uintptr_t Requirement; } MachMetadataDependency;

// swift_updateClassMetadata2(self, layoutFlags, numFields, fieldTypes, fieldOffsets):
// the field-layout pass over the macOS ObjC-interop metadata, WITHOUT ObjC registration.
// Computes each field's offset starting at the superclass instanceSize, fills fieldOffsets
// (= the metadata's field-offset vector) + the class's instanceSize/alignMask. Returns a
// null dependency (metadata is complete). TypeLayout (the VWT tail at +0x40) =
// { size_t size@0; size_t stride@8; uint32_t flags@16 (low byte = alignmentMask) }.
static MachMetadataDependency
machold_updateClassMetadata2(uint8_t *self, uintptr_t layoutFlags, uintptr_t numFields,
                             const uint8_t *const *fieldTypes, uintptr_t *fieldOffsets) {
    (void)layoutFlags;
    uint8_t *super = *(uint8_t **)(self + MACHO_CM_SUPERCLASS);
    uintptr_t size      = super ? *(uint32_t *)(super + MACHO_CM_INSTANCESIZE)      : 16;
    uintptr_t alignMask = super ? *(uint16_t *)(super + MACHO_CM_INSTANCEALIGNMASK) : 7;
    for (uintptr_t i = 0; i < numFields; i++) {
        const uint8_t *tl = fieldTypes[i];
        uintptr_t fsize  = *(uintptr_t *)(tl + 0);          // TypeLayout.size
        uintptr_t famask = *(uint32_t *)(tl + 16) & 0xFF;   // TypeLayout.flags → alignmentMask
        size = (size + famask) & ~famask;
        fieldOffsets[i] = size;
        size += fsize;
        if (famask > alignMask) alignMask = famask;
    }
    size = (size + alignMask) & ~alignMask;
    *(uint32_t *)(self + MACHO_CM_INSTANCESIZE)      = (uint32_t)size;
    *(uint16_t *)(self + MACHO_CM_INSTANCEALIGNMASK) = (uint16_t)alignMask;

    // ── Populate the ObjC ivar-offset variables = Swift's "direct field offset" (Wvd) globals.
    // On Darwin (ObjC interop) the binary reads a field's offset NOT from the metadata's
    // field-offset vector but from a per-field global (the ObjC ivar offset variable): e.g.
    // `M.init` does `ldr x23,[direct field offset for M._c]; str _c,[self,x23]`. The real
    // swift_updateClassMetadata2 fills those via metadata.data → class_ro_t → ivars →
    // ivar.offset. Replicate that walk (msgSend-free, pure struct reads). MUST run here, while
    // the Darwin `data` field (@+32) is still intact — machold_convert_class_metadata drops it
    // afterwards. Without this the globals stay 0 and the binary writes the first field over the
    // instance's isa (zeroing it → the `m.c` vtable dispatch then deref's a NULL isa).
    //   class_ro_t: ivars @+48.   ivar_list_t: {entsize@0, count@4, ivar_t[]@8}.
    //   ivar_t: {offset(ptr → the Wvd global)@0, name@8, type@16, align@24, size@28}.
    uintptr_t data = *(uintptr_t *)(self + MACHO_CM_DATA) & ~(uintptr_t)0x7;  // strip isSwift/RO tag bits
    if (data) {
        uintptr_t ivlist = *(uintptr_t *)(data + 48);          // class_ro_t.ivars
        if (ivlist) {
            uint32_t entsize = *(uint32_t *)ivlist;
            uint32_t count   = *(uint32_t *)(ivlist + 4);
            uint8_t *iv      = (uint8_t *)(ivlist + 8);
            for (uint32_t i = 0; entsize && i < count && i < numFields; i++, iv += entsize) {
                intptr_t *offptr = *(intptr_t **)iv;           // ivar_t.offset → the Wvd global
                if (offptr) {
                    *offptr = (intptr_t)fieldOffsets[i];
                    if (g_trace_meta)
                        fprintf(stderr, "[machold]   ivar-offset[%u] global %p <- %lu\n",
                                i, (void *)offptr, (unsigned long)fieldOffsets[i]);
                }
            }
        }
    }

    if (g_verbose)
        fprintf(stderr, "[machold] updateClassMetadata2: self=%p super=%p instanceSize=%lu fields=%lu off0=%lu\n",
                (void *)self, (void *)super, (unsigned long)size, (unsigned long)numFields,
                numFields ? (unsigned long)fieldOffsets[0] : 0);
    MachMetadataDependency dep = { NULL, 0 };
    return dep;
}

// Convert a Darwin ObjC-interop class metadata to Linux (no-interop) layout, IN PLACE, so
// the Linux runtime's metadata introspection (getDescription/getGenericArgs/getWitnessTable,
// instanceSize read) finds the fixed-header fields where it expects. macOS layout has a
// 24-byte {cache[2], data} gap after `superclass` that Linux omits — so flags/instanceSize/
// description/ivarDestroyer (the fixed header after the gap) sit 24 B higher on Darwin.
//
// CRUCIAL: we relocate ONLY the fixed header ([flags@40 .. ivarDestroyer@72) = 40 B) down to
// +16, filling the gap. We DELIBERATELY LEAVE the TRAILING area (field-offset vector + vtable,
// at +0x50…) exactly where Apple put it, because the BINARY hardcodes those Darwin offsets:
//   • M.init reads `_c`'s field offset from the field-offset vector at [metadata,#0x50];
//   • `m.c` dispatches virtually via [isa,#0x58] (the vtable);
//   • M's metadata-completion passes the field-offset-vector base as `add x4, x19, #0x50`.
// The descriptor's own FieldOffsetVectorOffset (=10) and the vtable's VTableOffset already
// point at those same physical positions, so the Linux runtime agrees too — neither needs
// patching. (An earlier version shifted the WHOLE positive region up 24 B and patched FVO
// 10→7; that desynced the binary's hardcoded reads from the relocated data — M.init then
// read a stale field offset of 0 and wrote `_c` over the instance's isa, zeroing it.)
//
// Must run AFTER the completion (which wrote instanceSize @0x30 + the field offset @0x50 at
// the Darwin offsets). Idempotent (each metadata converted once). Combined with the existing
// `metafix` (which rewrites the BINARY's instanceSize-read 0x30/0x34 → 0x18/0x1c), the binary
// and the runtime then agree on every field. The 24-B gap left behind at [+0x38,+0x50) is
// unused on Linux (the runtime locates the trailing area via the descriptor, not by header
// size), so it is harmless dead space.
static void *machold_converted[64];
static int machold_nconverted = 0;
static void machold_convert_class_metadata(uint8_t *md, int32_t *desc) {
    (void)desc;
    for (int i = 0; i < machold_nconverted; i++) if (machold_converted[i] == md) return;
    if (machold_nconverted < 64) machold_converted[machold_nconverted++] = md;
    memmove(md + 16, md + 40, 40);   // [flags@40 .. ivarDestroyer@72) -> [+16, +56); fill the {cache,data} gap
    if (g_trace_meta)
        fprintf(stderr, "[machold] converted class metadata %p Darwin->Linux (header-only; trailing kept @Darwin)\n",
                (void *)md);
}

// swift_getSingletonMetadata for the binary's ObjC-interop classes. The Linux runtime's
// own doInitialization crashes on the Darwin-format class metadata (it reads the metadata
// header at Linux offsets — see the SWIFT_OBJC_INTEROP layout note above). But the work it
// must do for a singleton-init class is simply: run the completion function (which calls
// our swift_updateClassMetadata2 to set field offsets + instanceSize) and cache the result.
// So we do exactly that from the descriptor, bypassing doInitialization — and DELEGATE every
// non-(ObjC-interop-class) singleton to the real runtime, so only the binary's model classes
// take this path.
//
// MetadataResponse = { const Metadata *Value; MetadataState State } (returned in x0:x1).
typedef struct { void *Value; uintptr_t State; } MachMetaResponse;
typedef MachMetaResponse (*getsingleton_fn)(uintptr_t, void *);
typedef MachMetadataDependency (*completion_fn)(void *metadata, void *ctx, void *args);
static getsingleton_fn g_real_getsingleton = NULL;

// Resolve a 32-bit relative pointer at `field` (Swift's position-independent encoding).
static void *machold_rel(const int32_t *field) {
    int32_t off = *field;
    return off ? (void *)((const char *)field + off) : NULL;
}

static MachMetaResponse machold_getSingletonMetadata(uintptr_t request, int32_t *desc) {
    uint32_t flags        = (uint32_t)desc[0];
    uint32_t kind         = flags & 0x1F;        // ContextDescriptorKind (Class = 0x10)
    uint32_t metadataInit = (flags >> 16) & 0x3; // 1 = SingletonMetadataInitialization
    uint32_t isGeneric    = flags & 0x80;        // generic flag (bit 7)
    // Only intercept non-generic ObjC-interop classes w/ singleton init; delegate the rest
    // (structs/enums/generic types) to the real runtime unchanged.
    if (kind != 0x10 || metadataInit != 1 || isGeneric) {
        if (!g_real_getsingleton)
            g_real_getsingleton = (getsingleton_fn)dlsym(RTLD_DEFAULT, "swift_getSingletonMetadata");
        return g_real_getsingleton(request, desc);
    }
    // SingletonMetadataInitialization trails the fixed class descriptor (no generic header /
    // resilient superclass for a model class) at byte offset +44:
    //   +44 InitializationCache, +48 IncompleteMetadata, +52 CompletionFunction (all rel ptrs).
    int32_t *si = (int32_t *)((char *)desc + 44);
    void **cache       = (void **)machold_rel(&si[0]);
    void *metadata     = machold_rel(&si[1]);
    completion_fn comp = (completion_fn)machold_rel(&si[2]);
    if (cache && cache[0]) { MachMetaResponse r = { cache[0], 0 }; return r; }   // already realized
    MachMetadataDependency dep = comp(metadata, NULL, NULL);  // runs the completion (→ updateClassMetadata2)
    machold_convert_class_metadata((uint8_t *)metadata, desc); // Darwin→Linux layout (post-completion)
    if (cache) cache[0] = metadata;                            // cache the realized metadata

    // Now that the metadata is fully realized + cached, clear the descriptor's "singleton
    // metadata initialization" flag (TypeContextDescriptorFlags.MetadataInitialization, bits
    // 16-17 of the context flags word desc[0]). Future runtime *state* queries —
    // swift_checkMetadataState via performOnMetadataCache, e.g. when a keypath (`\M.c`) resolves
    // M as its root type — then take the "statically-complete nominal type" fast path instead
    // of the singleton-cache state machine, which we bypassed (doInitialization SIGSEGVs on the
    // Darwin metadata) and so never set up. Without this the slow path deref's a NULL cache
    // entry (awaitSatisfyingState, this=NULL). The metadata accessor (M.Ma) is unaffected: it
    // reads the realized metadata straight from the cache, not via this flag.
    {
        long pg = sysconf(_SC_PAGESIZE);
        void *pgbase = (void *)((uintptr_t)desc & ~(uintptr_t)(pg - 1));
        if (mprotect(pgbase, pg, PROT_READ | PROT_WRITE) == 0) {
            desc[0] &= ~(int32_t)(0x3 << 16);                  // MetadataInitialization -> None
            mprotect(pgbase, pg, PROT_READ | PROT_EXEC);       // descriptor lives in __TEXT (r-x)
        }
    }
    if (g_trace_meta)
        fprintf(stderr, "[machold] getSingletonMetadata: realized class %p (desc %p, dep.Value=%p)\n",
                metadata, (void *)desc, dep.Value);
    MachMetaResponse r = { metadata, 0 /*Complete*/ };
    return r;
}

// Diagnostic: trace swift_allocObject (metadata, size) → instance + its stamped isa, for
// the first few calls — to see whether the binary's model class is allocated correctly.
// Gated by MACHOLD_TRACE_META.
typedef void *(*allocobj_fn)(void *, size_t, size_t);
static allocobj_fn g_real_allocobj = NULL;
static int g_alloc_traces = 0;
static void *machold_allocObject_trace(void *metadata, size_t size, size_t alignMask) {
    void *obj = g_real_allocobj(metadata, size, alignMask);
    if (g_alloc_traces < 24) {
        g_alloc_traces++;
        fprintf(stderr, "[machold] allocObject(meta=%p, size=%zu, align=%zu) -> %p, isa=%p\n",
                metadata, size, alignMask, obj, obj ? *(void **)obj : NULL);
    }
    return obj;
}

// Resolve a Darwin-mangled import name to a runtime address in this process.
// dyld binds by *name*, so we just dlsym after (a) dropping the Mach-O leading
// underscore and (b) rewriting the handful of module-qualified type names that
// mangle differently on Linux (CGFloat lives in CoreGraphics on Darwin but in
// Foundation on Linux; NSBundle is an ObjC __C class on Darwin, Foundation.Bundle
// on Linux). The two types are ABI-identical, so binding to the Linux symbol of
// the same function is correct — only the name string differs. Returns NULL if
// unresolved (the caller collects all misses and reports them together).
// Darwin libc's assert handler, inlined by some -O SwiftUI code (e.g. Picker's `.tag`). We never
// want to abort on these in the compat host, so no-op.
static void machold_assert_rtn(const char *fn, const char *file, int line, const char *expr) {
    (void)fn; (void)file; (void)line; (void)expr;
}
// Swift's `#available` lowering. The Linux libswiftCore exports `_stdlib_isOSVersionAtLeast` but
// NOT the `…OrVariantVersionAtLeast` variant the macOS binary inlines (e.g. from `.tag`'s
// `if #available(macOS 26…)`). Six Builtin.Word args, returns Builtin.Int1 — a plain C
// function matches the ABI.
//
// CONVENTION: under machold every Darwin-version check reports FALSE (an "OS 0.0.0"), so
// binaries take their LEGACY #available branches. One semantic check can lower through THREE
// mechanisms, and they must all agree:
//   (1) this stub (the variant stdlib entry, imported by name)                    -> 0
//   (2) Linux libswiftCore's own _stdlib_isOSVersionAtLeast (bound generically)   -> false on non-Darwin
//   (3) compiler-rt __isPlatformVersionAtLeast, statically linked into EVERY macOS binary
//       (os_version_check.c): __availability_version_check is a weak import (binds NULL here),
//       so it falls back to parsing /System/Library/CoreServices/SystemVersion.plist via
//       dlsym(RTLD_DEFAULT, kCFAllocatorNull/CF*) — the plist doesn't exist on Linux -> 0.0.0.
// `.tag`'s opaque type descriptor shows why coherence matters: its kind-9 (accessor-function)
// underlying-type references pick the TYPE metadata via (3) — modern _TagTraitWritingModifier
// vs legacy _TraitWritingModifier<TagValueTraitKey<V?>> — while the inlined body picks the VALUE
// representation via (1). Returning 1 here while (3) said "no" made value layout and resolved
// metadata diverge. FALSE everywhere = the proven-rendering combination.
static long machold_os_version_atleast(long a, long b, long c, long d, long e, long f) {
    (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; return 0;
}
// The app's own dlsym calls arrive with DARWIN pseudo-handles: RTLD_NEXT=-1, RTLD_DEFAULT=-2,
// RTLD_SELF=-3, RTLD_MAIN_ONLY=-5 (Linux RTLD_DEFAULT is 0; glibc's RTLD_NEXT=-1 exists but
// faults from a caller that isn't a real ELF link_map — and the Mach-O image isn't one).
// glibc dlsym dereferences any other handle as a link_map* — Darwin's -2 SIGSEGVed in
// _dl_lookup_symbol_x (compiler-rt's availability init, see machold_os_version_atleast (3)).
// Translate all pseudo-handles to the global scope; real dlopen handles pass through.
static int g_trace_dlsym = 0;     // MACHOLD_TRACE_DLSYM: log the app's dlsym calls
static void *machold_dlsym(void *handle, const char *name) {
    void *h = handle;
    if (handle == (void *)-1L || handle == (void *)-2L ||
        handle == (void *)-3L || handle == (void *)-5L) h = RTLD_DEFAULT;
    void *r = dlsym(h, name);
    if (g_trace_dlsym)
        fprintf(stderr, "[machold] app dlsym(%p%s, \"%s\") -> %p\n",
                handle, h != handle ? " [darwin-handle]" : "", name, r);
    return r;
}

// ── Inlined SwiftUI runtime-issue logging (os_log) ───────────────────────────
// SwiftUI @inlinable bodies embed os_log runtime-issue calls (e.g. Environment<V>.
// wrappedValue's "not installed on a View" branch). Under the compat walk that branch
// is DEAD — the injection pass rewrites .keyPath → .value before body runs — but the
// symbols must bind. os_log_type_enabled -> false short-circuits any live path before
// __os_log_impl formats anything.
static long machold_os_log_type_enabled(void *log, unsigned char type) { (void)log; (void)type; return 0; }
static void machold_os_log_noop(void) {}
static void *machold_os_log_default_log(void) { static long dummy[2]; return dummy; }
static unsigned char machold_os_log_fault(void) { return 17; }   // OS_LOG_TYPE_FAULT

// ── Minimal NSLocale / NSTimeZone / NSISO8601DateFormatter (plutil touches lightly) ──
static machold_class_t machold_locale_cls, machold_locale_meta, machold_tz_cls, machold_tz_meta, machold_iso_cls, machold_iso_meta;
static machold_mlist_t machold_locale_m, machold_locale_cm, machold_tz_m, machold_tz_cm, machold_iso_m, machold_iso_cm;
static machold_class_ro_t machold_locale_ro, machold_locale_mro, machold_tz_ro, machold_tz_mro, machold_iso_ro, machold_iso_mro;
static void machold_init_misc_classes(void);
static void *machold_misc_new(machold_class_t *c) { machold_init_misc_classes(); return machold_class_createInstance((uint8_t *)c, 0); }
static void *machold_locale_new(void *cls, const char *cmd) { (void)cls; (void)cmd; return machold_misc_new(&machold_locale_cls); }
static void *machold_locale_ident(void *s, const char *cmd) { (void)s; (void)cmd; return machold_make_string("en_US_POSIX", 11); }
static void *machold_tz_new(void *cls, const char *cmd) { (void)cls; (void)cmd; return machold_misc_new(&machold_tz_cls); }
static void *machold_tz_name(void *s, const char *cmd) { (void)s; (void)cmd; return machold_make_string("UTC", 3); }
static long machold_tz_secs(void *s, const char *cmd) { (void)s; (void)cmd; return 0; }
static void *machold_iso_new(void *cls, const char *cmd) { (void)cls; (void)cmd; return machold_misc_new(&machold_iso_cls); }
static void *machold_iso_self(void *s, const char *cmd) { (void)cmd; return s; }
static void *machold_iso_string(void *s, const char *cmd, void *date) {
    (void)s; (void)cmd;
    double ts = date ? *(double *)((char *)date + 8) : 0;
    static const char fmt[] = "yyyy-MM-dd'T'HH:mm:ss'Z'"; long n = 0;
    void *(*fn)(double, const char *, long, long *) = (void *(*)(double, const char *, long, long *))dlsym(RTLD_DEFAULT, "machold_fusion_date_format");
    void *buf = fn ? fn(ts, fmt, (long)sizeof(fmt) - 1, &n) : NULL;
    if (!buf) return machold_make_string("", 0);
    void *r = machold_make_string((const char *)buf, n); free(buf); return r;
}
static int machold_misc_inited = 0;
static void machold_init_misc_classes(void) {
    if (machold_misc_inited) return; machold_misc_inited = 1;
    machold_init_nsobject(); machold_init_nsdate();
    #define MC(d, s) do { (d).count = sizeof(s)/sizeof((s)[0]); memcpy((d).methods, s, sizeof(s)); } while (0)
    machold_method_t lm[]  = { {"localeIdentifier", "@16@0:8", (void *)machold_locale_ident} };
    machold_method_t lcm[] = { {"currentLocale", "@16#0:8", (void *)machold_locale_new}, {"systemLocale", "@16#0:8", (void *)machold_locale_new}, {"autoupdatingCurrentLocale", "@16#0:8", (void *)machold_locale_new} };
    MC(machold_locale_m, lm); MC(machold_locale_cm, lcm);
    machold_mk_class(&machold_locale_cls, &machold_locale_meta, &machold_locale_ro, &machold_locale_mro, &machold_locale_m, &machold_locale_cm, 16, "NSLocale");
    machold_method_t tm[]  = { {"name", "@16@0:8", (void *)machold_tz_name}, {"secondsFromGMT", "q16@0:8", (void *)machold_tz_secs} };
    machold_method_t tcm[] = { {"systemTimeZone", "@16#0:8", (void *)machold_tz_new}, {"localTimeZone", "@16#0:8", (void *)machold_tz_new}, {"defaultTimeZone", "@16#0:8", (void *)machold_tz_new} };
    MC(machold_tz_m, tm); MC(machold_tz_cm, tcm);
    machold_mk_class(&machold_tz_cls, &machold_tz_meta, &machold_tz_ro, &machold_tz_mro, &machold_tz_m, &machold_tz_cm, 16, "NSTimeZone");
    machold_method_t im[]  = { {"init", "@16@0:8", (void *)machold_iso_self}, {"stringFromDate:", "@24@0:8@16", (void *)machold_iso_string} };
    machold_method_t icm[] = { {"new", "@16#0:8", (void *)machold_iso_new} };
    MC(machold_iso_m, im); MC(machold_iso_cm, icm);
    machold_mk_class(&machold_iso_cls, &machold_iso_meta, &machold_iso_ro, &machold_iso_mro, &machold_iso_m, &machold_iso_cm, 16, "NSISO8601DateFormatter");
    #undef MC
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - ObjC exception mini-unwinder (X-series)
// ══════════════════════════════════════════════════════════════════════════════
// Apple arm64 emits ONLY compact unwind (__unwind_info) + the Itanium LSDA
// (__gcc_except_table) — no DWARF __eh_frame — so libgcc's _Unwind_RaiseException can't be
// driven. Instead objc_exception_throw (naked, captures the thrower's regs) → machold_eh_search
// maps PC→LSDA via a table built from __unwind_info, parses the call-site/action/ttype tables,
// matches the exception class, and machold_eh_resume (naked) restores the throwing frame's
// sp/x29/callee-saved and branches to its landing pad (x0=exc, x1=filter). Single-frame only
// (throw+catch in the same function) — enough for X1; cross-frame cleanup is deferred.
typedef struct { uintptr_t func_start, func_end; const uint8_t *lsda; } machold_eh_func_t;
machold_eh_func_t g_eh_funcs[1024];
int g_eh_nfuncs = 0;
struct machold_eh_ctx_t {
    void *exc; uintptr_t fp0, lr0, sp0, pc, filter;   // @0,8,16,24,32,40
    uintptr_t x[10];                                   // x19..x28 @48
    double d[8];                                       // d8..d15 @128
};
struct machold_eh_ctx_t g_eh_ctx;   // @192 total (single-threaded probes)

// Build PC→LSDA from Apple __unwind_info (image-relative offsets → runtime via base).
static void machold_build_eh_table(const uint8_t *ui, uint8_t *base) {
    const uint32_t *h = (const uint32_t *)ui;
    uint32_t idx_off = h[5], idx_count = h[6];              // indexSectionOffset, indexCount
    const uint32_t *idx = (const uint32_t *)(ui + idx_off); // triples {func_off, page_off, lsda_off}
    for (uint32_t i = 0; i + 1 < idx_count; i++) {
        uint32_t lsda_start = idx[i * 3 + 2], lsda_end = idx[(i + 1) * 3 + 2];
        const uint32_t *le = (const uint32_t *)(ui + lsda_start);   // pairs {func_off, lsda_off}
        uint32_t n = (lsda_end - lsda_start) / 8;
        for (uint32_t j = 0; j < n && g_eh_nfuncs < 1024; j++) {
            uintptr_t fs = (uintptr_t)base + le[j * 2];
            uintptr_t fe = (uintptr_t)base + ((j + 1 < n) ? le[(j + 1) * 2] : idx[(i + 1) * 3]);
            g_eh_funcs[g_eh_nfuncs].func_start = fs; g_eh_funcs[g_eh_nfuncs].func_end = fe;
            g_eh_funcs[g_eh_nfuncs].lsda = base + le[j * 2 + 1]; g_eh_nfuncs++;
        }
    }
}
static uint64_t machold_uleb(const uint8_t **pp) {
    uint64_t r = 0; int s = 0; uint8_t b; do { b = *(*pp)++; r |= (uint64_t)(b & 0x7f) << s; s += 7; } while (b & 0x80); return r;
}
static int64_t machold_sleb(const uint8_t **pp) {
    int64_t r = 0; int s = 0; uint8_t b; do { b = *(*pp)++; r |= (int64_t)(b & 0x7f) << s; s += 7; } while (b & 0x80);
    if (s < 64 && (b & 0x40)) r |= -((int64_t)1 << s); return r;
}
// Match the thrown exception against an objc_typeinfo (NULL/zero cls → catch-all).
static int machold_exc_matches(void *exc, const void *tinfo) {
    if (!tinfo) return 1;
    void *want = *(void **)((const char *)tinfo + 16);   // objc_typeinfo.cls @16
    if (!want) return 1;
    uint8_t *c = *(uint8_t **)exc;                        // exc->isa
    for (int i = 0; c && i < 32; i++) {
        if ((void *)c == want) return 1;
        uintptr_t data = *(uintptr_t *)(c + MACHO_CM_DATA_OFF) & ~(uintptr_t)0x7;
        if (data && (*(uint32_t *)data & MACHO_RO_ROOT)) break;
        c = *(uint8_t **)(c + MACHO_CM_SUPER_OFF);
    }
    return 0;
}
extern void machold_eh_resume(void);   // naked (below)
__attribute__((used)) void machold_objc_terminate_impl(void) {
    fprintf(stderr, "[machold] *** uncaught ObjC exception — terminating\n"); abort();
}
// Search frame 0 for a matching handler; on match set pc/filter + resume (no return).
__attribute__((used)) void machold_eh_search(void) {
    uintptr_t ip = g_eh_ctx.lr0 - 1;   // the throwing call site
    const uint8_t *lsda = NULL; uintptr_t func_start = 0;
    for (int i = 0; i < g_eh_nfuncs; i++)
        if (ip >= g_eh_funcs[i].func_start && ip < g_eh_funcs[i].func_end) { lsda = g_eh_funcs[i].lsda; func_start = g_eh_funcs[i].func_start; break; }
    if (!lsda) return;
    const uint8_t *p = lsda;
    p++;                                         // LPStart enc (0xff = omit → lpStart = func_start)
    uintptr_t lpStart = func_start;
    uint8_t ttypeEnc = *p++;
    uintptr_t ttypeBase = 0;
    if (ttypeEnc != 0xff) { uint64_t off = machold_uleb(&p); ttypeBase = (uintptr_t)p + off; }
    p++;                                         // call-site enc (uleb128)
    uint64_t csLen = machold_uleb(&p);
    const uint8_t *csEnd = p + csLen;
    const uint8_t *actionTable = csEnd;
    uintptr_t ipoff = ip - func_start;
    while (p < csEnd) {
        uint64_t cs_start = machold_uleb(&p), cs_len = machold_uleb(&p), cs_lp = machold_uleb(&p), cs_action = machold_uleb(&p);
        if (ipoff < cs_start || ipoff >= cs_start + cs_len) continue;
        if (cs_lp == 0 || cs_action == 0) return;                       // no catch in this region
        const uint8_t *ap = actionTable + (cs_action - 1);
        for (;;) {
            int64_t filter = machold_sleb(&ap);
            const uint8_t *disp_pos = ap;
            int64_t next = machold_sleb(&ap);
            if (filter > 0) {
                const int32_t *te = (const int32_t *)(ttypeBase - filter * 4);
                const void *tinfo = NULL;
                if (*te != 0) { uintptr_t slot = (uintptr_t)te + *te; tinfo = *(const void **)slot; }   // pcrel + indirect
                if (machold_exc_matches(g_eh_ctx.exc, tinfo)) {
                    g_eh_ctx.pc = lpStart + cs_lp; g_eh_ctx.filter = (uintptr_t)filter;
                    machold_eh_resume();                                // no return
                }
            }
            if (next == 0) break;
            ap = disp_pos + next;
        }
        return;
    }
}
// objc_exception_throw(id): naked — capture the thrower's regs, then search.
extern void machold_objc_exception_throw(void);
__asm__(
    ".text\n.globl machold_objc_exception_throw\n.p2align 2\nmachold_objc_exception_throw:\n"
    "    adrp x9, g_eh_ctx\n    add x9, x9, :lo12:g_eh_ctx\n"
    "    str  x0,  [x9, #0]\n"          // exc
    "    str  x29, [x9, #8]\n"          // fp0
    "    str  x30, [x9, #16]\n"         // lr0
    "    mov  x10, sp\n    str x10, [x9, #24]\n"   // sp0 (thrower call-site sp)
    "    stp  x19, x20, [x9, #48]\n    stp x21, x22, [x9, #64]\n"
    "    stp  x23, x24, [x9, #80]\n    stp x25, x26, [x9, #96]\n    stp x27, x28, [x9, #112]\n"
    "    stp  d8,  d9,  [x9, #128]\n    stp d10, d11, [x9, #144]\n"
    "    stp  d12, d13, [x9, #160]\n    stp d14, d15, [x9, #176]\n"
    "    stp  x29, x30, [sp, #-16]!\n    mov x29, sp\n"
    "    bl   machold_eh_search\n"      // resumes on match; returns only if no handler
    "    bl   machold_objc_terminate_impl\n");
// Restore the throwing frame and branch to its landing pad.
__asm__(
    ".text\n.globl machold_eh_resume\n.p2align 2\nmachold_eh_resume:\n"
    "    adrp x9, g_eh_ctx\n    add x9, x9, :lo12:g_eh_ctx\n"
    "    ldp  x19, x20, [x9, #48]\n    ldp x21, x22, [x9, #64]\n"
    "    ldp  x23, x24, [x9, #80]\n    ldp x25, x26, [x9, #96]\n    ldp x27, x28, [x9, #112]\n"
    "    ldp  d8,  d9,  [x9, #128]\n    ldp d10, d11, [x9, #144]\n"
    "    ldp  d12, d13, [x9, #160]\n    ldp d14, d15, [x9, #176]\n"
    "    ldr  x0,  [x9, #0]\n"          // exc
    "    ldr  x1,  [x9, #40]\n"         // filter
    "    ldr  x29, [x9, #8]\n"          // fp0
    "    ldr  x10, [x9, #24]\n    mov sp, x10\n"    // sp0
    "    ldr  x10, [x9, #32]\n    br  x10\n");      // landing pad

static void *resolve_symbol(const char *darwin_name) {
    const char *n = darwin_name;
    if (n[0] == '_') n++;                       // strip Mach-O leading underscore

    // os_log surface (see above): the C entry points, the Swift os.os_log(_:dso:log:
    // type:_:) function, SwiftUI's Log.runtimeIssuesLog getter, os_log_type_t.fault.
    if (strcmp(n, "_os_log_impl") == 0)       return (void *)machold_os_log_noop;
    if (strcmp(n, "os_log_type_enabled") == 0) return (void *)machold_os_log_type_enabled;
    if (strcmp(n, "$s7SwiftUI3LogO013runtimeIssuesC0So9OS_os_logCvgZ") == 0)
        return (void *)machold_os_log_default_log;
    if (strcmp(n, "$s2os0A4_log_3dso0B0__ySo0a1_B7_type_ta_SVSo03OS_a1_B0Cs12StaticStringVs7CVarArg_pdtF") == 0)
        return (void *)machold_os_log_noop;
    if (strcmp(n, "$sSo13os_log_type_ta0A0E5faultABvgZ") == 0) return (void *)machold_os_log_fault;

    // ── ObjC messaging (tier 2) — the dispatcher + malloc-object lifecycle helpers.
    // Objects created here are malloc'd, NOT swift heap objects, so objc retain/release are
    // identity/no-op (leaks OK for the compat host; avoids swift_release misreading a
    // non-swift refcount header). swift_unknownObject* still alias the native ones — those
    // only appear in Swift binaries operating on swift objects.
    if (strcmp(n, "objc_msgSend") == 0) {
        g_trace_objc = getenv("MACHOLD_TRACE_OBJC") != NULL;
        g_objc_lenient = getenv("MACHOLD_OBJC_LENIENT") != NULL;
        LOG("  interpose objc_msgSend (tier-2 dispatch)\n");
        return (void *)machold_objc_msgSend;
    }
    if (strcmp(n, "objc_msgSendSuper2") == 0)   return (void *)machold_objc_msgSendSuper2;
    if (strcmp(n, "OBJC_CLASS_$_NSObject") == 0)     { machold_init_nsobject(); return &machold_nsobj_cls; }
    if (strcmp(n, "OBJC_METACLASS_$_NSObject") == 0) { machold_init_nsobject(); return &machold_nsobj_meta; }
    if (strcmp(n, "__CFConstantStringClassReference") == 0) { machold_init_cfstring(); return &machold_cfstring_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSString") == 0)        { machold_init_nsstring(); return &machold_cfstring_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSMutableString") == 0) { machold_init_nsmutstr(); return &machold_mstr_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSMutableArray") == 0 || strcmp(n, "OBJC_CLASS_$_NSArray") == 0)
        { machold_init_nsarray(); return &machold_nsarray_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSConstantIntegerNumber") == 0 || strcmp(n, "OBJC_CLASS_$_NSNumber") == 0)
        { machold_init_nsnumber(); return &machold_nsnum_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSMutableDictionary") == 0 || strcmp(n, "OBJC_CLASS_$_NSDictionary") == 0)
        { machold_init_nsdict(); return &machold_nsdict_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSData") == 0 || strcmp(n, "OBJC_CLASS_$_NSMutableData") == 0)
        { machold_init_nsdata(); return &machold_nsdata_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSConstantArray") == 0) { machold_init_carr(); return &machold_carr_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSMutableSet") == 0 || strcmp(n, "OBJC_CLASS_$_NSSet") == 0)
        { machold_init_nsset(); return &machold_nsset_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSDate") == 0) { machold_init_nsdate(); return &machold_nsdate_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSError") == 0) { machold_init_nserror(); return &machold_nserror_cls; }
    // ObjC exceptions (mini-unwinder)
    if (strcmp(n, "OBJC_CLASS_$_NSException") == 0) { machold_init_nsexception(); return &machold_nsexc_cls; }
    if (strcmp(n, "OBJC_EHTYPE_$_NSException") == 0) { machold_init_nsexception(); return &machold_ehtype_nsexc; }
    if (strcmp(n, "objc_exception_throw") == 0) return (void *)machold_objc_exception_throw;
    if (strcmp(n, "objc_terminate") == 0)       return (void *)machold_objc_terminate_impl;
    if (strcmp(n, "_Unwind_Resume") == 0)       return (void *)machold_objc_terminate_impl;   // only hit on no-match (X1)
    // Swift+ObjC hybrid (plutil) runtime/libSystem stubs + globals + classes
    if (strcmp(n, "class_getSuperclass") == 0)  return (void *)machold_class_getSuperclass;
    if (strcmp(n, "objc_allocWithZone") == 0)   return (void *)machold_objc_allocWithZone;
    if (strcmp(n, "NSStringFromClass") == 0)    return (void *)machold_NSStringFromClass;
    if (strcmp(n, "__error") == 0)              return dlsym(RTLD_DEFAULT, "__errno_location");
    if (strcmp(n, "_os_feature_enabled_impl") == 0) return (void *)machold_os_feature_off;
    if (strcmp(n, "_NSIsNSString") == 0)        return (void *)machold_NSIsNSString;
    if (strcmp(n, "NSAllocateObjectArray") == 0) return (void *)machold_alloc_obj_array;
    if (strcmp(n, "NSFreeObjectArray") == 0)    return (void *)machold_free_obj_array;
    if (strcmp(n, "swift_dynamicCastObjCClass") == 0) return (void *)machold_swift_castObjC;
    if (strcmp(n, "swift_getObjCClassMetadata") == 0) return (void *)machold_ident1;
    if (strcmp(n, "_objc_autoreleasePoolPush") == 0) return (void *)machold_arp_push;
    if (strcmp(n, "_objc_autoreleasePoolPop") == 0)  return (void *)machold_arp_pop;
    // Foundation error-domain/exception-name globals (data → a machold NSString value)
    if (strcmp(n, "NSCocoaErrorDomain") == 0)              return machold_make_string("NSCocoaErrorDomain", 18);
    if (strcmp(n, "NSDebugDescriptionErrorKey") == 0)      return machold_make_string("NSDebugDescription", 18);
    if (strcmp(n, "NSLocalizedFailureReasonErrorKey") == 0) return machold_make_string("NSLocalizedFailureReason", 24);
    if (strcmp(n, "NSGenericException") == 0)              return machold_make_string("NSGenericException", 17);
    if (strcmp(n, "NSMallocException") == 0)               return machold_make_string("NSMallocException", 16);
    // Minimal classes + metaclasses + empty-collection singletons
    if (strcmp(n, "OBJC_CLASS_$_NSLocale") == 0)   { machold_init_misc_classes(); return &machold_locale_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSTimeZone") == 0) { machold_init_misc_classes(); return &machold_tz_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSISO8601DateFormatter") == 0) { machold_init_misc_classes(); return &machold_iso_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSMutableCharacterSet") == 0) { machold_init_charset(); return &machold_chset_cls; }
    if (strcmp(n, "OBJC_METACLASS_$_NSMutableArray") == 0)      { machold_init_nsarray(); return &machold_nsarray_meta; }
    if (strcmp(n, "OBJC_METACLASS_$_NSMutableDictionary") == 0) { machold_init_nsdict();  return &machold_nsdict_meta; }
    if (strcmp(n, "__NSArray0__struct") == 0)      return machold_arr_new();
    if (strcmp(n, "__NSDictionary0__struct") == 0) { machold_init_nsdict(); return machold_class_createInstance((uint8_t *)&machold_nsdict_cls, 0); }
    // Genuinely-absent Swift thunks (stub so plutil LOADS; may misbehave if hit at runtime)
    if (strcmp(n, "$ss018_bridgeAnyObjectToB0yypyXlSgF") == 0) return (void *)machold_ident1;
    if (strcmp(n, "$ss5ErrorP19_getEmbeddedNSErroryXlSgyFTq") == 0 ||
        strcmp(n, "$ss5ErrorPsE19_getEmbeddedNSErroryXlSgyF") == 0) return (void *)machold_ret_null;
    if (strcmp(n, "$s10Foundation11FormatStylePA2A4DateV07ISO8601bC0VRszrlE7iso8601AGvgZ") == 0) return (void *)machold_ret_null;
    if (strcmp(n, "$s10Foundation21_BridgedStoredNSErrorPAAE_8userInfox4CodeQz_SDySSypGtcfC") == 0) return (void *)machold_ret_null;
    if (strcmp(n, "$s10Foundation3URLV13DirectoryHintO13inferFromPathyA2EmFWC") == 0) return (void *)machold_ehtype_id;
    if (strcmp(n, "$sSo12NSFileHandleC10FoundationE5write10contentsOfyx_tKAC12DataProtocolRzlF") == 0 ||
        strcmp(n, "$sSo12NSFileHandleC10FoundationE9readToEndAC4DataVSgyKF") == 0) return (void *)machold_ret_null;
    if (strcmp(n, "OBJC_CLASS_$_NSProcessInfo") == 0) { machold_init_procinfo(); return &machold_procinfo_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSFileManager") == 0) { machold_init_filemgr(); return &machold_filemgr_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSNull") == 0) { machold_init_nsnull(); return &machold_nsnull_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSJSONSerialization") == 0) { machold_init_serializers(); return &machold_nsjson_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSPropertyListSerialization") == 0) { machold_init_serializers(); return &machold_nsplist_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSDateFormatter") == 0) { machold_init_dateformatter(); return &machold_df_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSFileHandle") == 0)      { machold_init_filehandle(); return &machold_fh_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSAutoreleasePool") == 0) { machold_init_nsarp(); return &machold_nsarp_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSCharacterSet") == 0)    { machold_init_charset(); return &machold_chset_cls; }
    if (strcmp(n, "NSSearchPathForDirectoriesInDomains") == 0) return (void *)machold_nssearchpath;
    // objc exception plumbing (fine as long as nothing actually throws)
    if (strcmp(n, "objc_begin_catch") == 0)  return (void *)machold_objc_identity;   // returns the caught exception
    if (strcmp(n, "objc_end_catch") == 0)    return (void *)machold_block_noop;
    if (strcmp(n, "OBJC_EHTYPE_id") == 0)    return machold_ehtype_id;
    // CFPreferences private SPI — the prefs-DATABASE path (unused by `defaults read <file>`),
    // but must resolve to load. Stub to nil/no-op.
    if (strncmp(n, "_CFPref", 7) == 0 || strncmp(n, "_CFXPreferences", 15) == 0 ||
        strncmp(n, "_CFPreferences", 14) == 0) return (void *)machold_ret_null;
    // Reverse-impedance: machold-aware CF C functions (handle our objects, else forward).
    if (strcmp(n, "CFGetTypeID") == 0)         return (void *)machold_cf_getTypeID;
    if (strcmp(n, "CFEqual") == 0)             return (void *)machold_cf_equal;
    if (strcmp(n, "CFRelease") == 0)           return (void *)machold_cf_release;
    if (strcmp(n, "CFStringGetLength") == 0)   return (void *)machold_cf_strlen;
    if (strcmp(n, "CFStringHasPrefix") == 0)   return (void *)machold_cf_hasPrefix;
    if (strcmp(n, "CFNumberIsFloatType") == 0) return (void *)machold_cf_numIsFloat;
    // CFPreferences (public) → read the domain's plist file (Linux CF's own impl crashes).
    if (strcmp(n, "CFPreferencesCopyMultiple") == 0) return (void *)machold_prefs_multiple;
    if (strcmp(n, "CFPreferencesCopyKeyList") == 0)  return (void *)machold_prefs_keylist;
    if (strcmp(n, "CFPreferencesCopyValue") == 0)    return (void *)machold_prefs_value;
    if (strcmp(n, "CFPreferencesSynchronize") == 0)  return (void *)machold_ret_true;
    if (strcmp(n, "CFPreferencesSetValue") == 0 || strcmp(n, "CFPreferencesSetMultiple") == 0)
        return (void *)machold_block_noop;
    // AppKit (tier-2 GUI render bridge)
    if (strcmp(n, "OBJC_CLASS_$_NSApplication") == 0) { machold_init_appkit(); return &machold_nsapp_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSWindow") == 0)      { machold_init_appkit(); return &machold_nswindow_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSView") == 0)        { machold_init_appkit(); return &machold_nsview_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSTextField") == 0)   { machold_init_appkit(); return &machold_nstextfield_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSButton") == 0)      { machold_init_appkit(); return &machold_nsbutton_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSStackView") == 0)   { machold_init_appkit(); return &machold_nsstackview_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSSlider") == 0)      { machold_init_appkit(); return &machold_nsslider_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSImage") == 0)       { machold_init_appkit(); return &machold_nsimage_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSImageView") == 0)   { machold_init_appkit(); return &machold_nsimageview_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSProgressIndicator") == 0) { machold_init_appkit(); return &machold_nsprogress_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSTableView") == 0)   { machold_init_appkit(); return &machold_nstableview_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSTableColumn") == 0) { machold_init_appkit(); return &machold_nstablecol_cls; }
    if (strcmp(n, "OBJC_CLASS_$_NSPopUpButton") == 0)  { machold_init_appkit(); return &machold_nspopup_cls; }
    if (strcmp(n, "objc_autoreleasePoolPush") == 0)   return (void *)machold_arp_push;
    if (strcmp(n, "objc_autoreleasePoolPop") == 0)    return (void *)machold_arp_pop;
    // libSystem/CF shims for real Mach-O binaries (data + typed-malloc + private CF).
    if (strcmp(n, "__stdinp") == 0)  { g_darwin_stdin  = stdin;  return &g_darwin_stdin; }
    if (strcmp(n, "__stdoutp") == 0) { g_darwin_stdout = stdout; return &g_darwin_stdout; }
    if (strcmp(n, "__stderrp") == 0) { g_darwin_stderr = stderr; return &g_darwin_stderr; }
    if (strcmp(n, "malloc_type_malloc") == 0)  return (void *)machold_mtype_malloc;
    if (strcmp(n, "malloc_type_calloc") == 0)  return (void *)machold_mtype_calloc;
    if (strcmp(n, "malloc_type_realloc") == 0) return (void *)machold_mtype_realloc;
    // BSD/libSystem shims for real CLI tools (/usr/bin/arch et al.)
    if (strcmp(n, "NXGetLocalArchInfo") == 0)        return (void *)machold_nx_local;
    if (strcmp(n, "NXGetArchInfoFromCpuType") == 0)  return (void *)machold_nx_fromcpu;
    if (strcmp(n, "getprogname") == 0)               return (void *)machold_getprogname;
    if (strcmp(n, "errc") == 0)                      return (void *)machold_errc;
    if (strcmp(n, "sysctlbyname") == 0)              return (void *)machold_sysctlbyname;
    if (strcmp(n, "realpath$DARWIN_EXTSN") == 0)     return dlsym(RTLD_DEFAULT, "realpath");
    if (strcmp(n, "_copyenv") == 0 || strcmp(n, "_setenvp") == 0 || strcmp(n, "_unsetenvp") == 0 ||
        strcmp(n, "posix_spawnattr_setarchpref_np") == 0 ||
        strcmp(n, "sysdir_start_search_path_enumeration") == 0 ||
        strcmp(n, "sysdir_get_next_search_path_enumeration") == 0)
        return (void *)machold_ret_null;   // spawn/env helpers — only used by `arch -arch X cmd`
    if (strcmp(n, "_CFCopySupplementalVersionDictionary") == 0) return (void *)machold_cf_version_dict;
    if (strcmp(n, "CFURLCreateDataAndPropertiesFromResource") == 0) return (void *)machold_cf_urlread;
    if (strcmp(n, "objc_enumerationMutation") == 0) return (void *)machold_enum_mutation;
    // Blocks: dummy isa classes + identity/no-op runtime (blocks invoked synchronously).
    if (strcmp(n, "_NSConcreteStackBlock") == 0 || strcmp(n, "_NSConcreteGlobalBlock") == 0 ||
        strcmp(n, "_NSConcreteMallocBlock") == 0) return machold_block_class;
    if (strcmp(n, "Block_copy") == 0 || strcmp(n, "_Block_copy") == 0) return (void *)machold_block_copy;
    if (strcmp(n, "Block_release") == 0 || strcmp(n, "_Block_release") == 0 ||
        strcmp(n, "_Block_object_assign") == 0 || strcmp(n, "_Block_object_dispose") == 0)
        return (void *)machold_block_noop;
    if (strcmp(n, "__objc_personality_v0") == 0) return (void *)machold_objc_personality;
    // Variadic printf-family: Darwin stack-varargs → glibc register-varargs shim.
    if (strcmp(n, "printf") == 0)   return (void *)machold_printf;
    if (strcmp(n, "sprintf") == 0)  return (void *)machold_sprintf;
    if (strcmp(n, "snprintf") == 0) return (void *)machold_snprintf;
    if (strcmp(n, "NSLog") == 0)    return (void *)machold_nslog;
    if (strcmp(n, "objc_getClass") == 0 || strcmp(n, "objc_lookUpClass") == 0 ||
        strcmp(n, "objc_getRequiredClass") == 0)
        return (void *)machold_objc_getClass;
    if (strcmp(n, "class_createInstance") == 0) return (void *)machold_class_createInstance;
    if (strcmp(n, "objc_alloc") == 0)           return (void *)machold_objc_alloc;
    if (strcmp(n, "objc_alloc_init") == 0)      return (void *)machold_objc_alloc_init;
    if (strcmp(n, "object_getClass") == 0)      return (void *)machold_object_getClass;
    if (strcmp(n, "objc_opt_class") == 0)       return (void *)machold_objc_opt_class;
    if (strcmp(n, "objc_opt_self") == 0)        return (void *)machold_objc_identity;
    if (strcmp(n, "objc_opt_new") == 0)         return (void *)machold_objc_opt_new;
    if (strcmp(n, "objc_opt_isKindOfClass") == 0) return (void *)machold_objc_isKind;
    if (strcmp(n, "objc_getProperty") == 0)     return (void *)machold_getProperty;
    if (strcmp(n, "objc_setProperty_atomic") == 0 || strcmp(n, "objc_setProperty_nonatomic") == 0 ||
        strcmp(n, "objc_setProperty_atomic_copy") == 0 || strcmp(n, "objc_setProperty_nonatomic_copy") == 0)
        return (void *)machold_setProperty;
    if (strcmp(n, "objc_setProperty") == 0)     return (void *)machold_setProperty_full;
    if (strcmp(n, "objc_storeStrong") == 0)     return (void *)machold_objc_storeStrong;
    if (strcmp(n, "sel_registerName") == 0 || strcmp(n, "sel_getUid") == 0)
        return (void *)machold_sel_registerName;
    if (strcmp(n, "objc_retain") == 0 || strcmp(n, "objc_autorelease") == 0 ||
        strcmp(n, "objc_retainAutorelease") == 0 || strcmp(n, "objc_retainAutoreleasedReturnValue") == 0)
        return (void *)machold_objc_identity;
    if (strcmp(n, "objc_release") == 0)          return (void *)machold_objc_noop;
    if (strcmp(n, "swift_unknownObjectRetain") == 0) return dlsym(RTLD_DEFAULT, "swift_retain");
    if (strcmp(n, "swift_unknownObjectRelease") == 0) return dlsym(RTLD_DEFAULT, "swift_release");

    // Statically-emitted objects (e.g. __StaticArrayStorage literals) have their
    // refcount WORD bound to this Darwin ABSOLUTE symbol — the symbol's "address" IS
    // the immortal InlineRefCounts bit pattern (dyld_info -exports libswiftCore:
    // 0x80000004FFFFFFFF [absolute]). RefCount.h is interop-independent, so the Linux
    // runtime's isImmortal() fast-path accepts the same pattern (retain/release no-op).
    if (strcmp(n, "_swiftImmortalRefCount") == 0) return (void *)0x80000004FFFFFFFFULL;

    if (strcmp(n, "__chkstk_darwin") == 0) return (void *)machold_chkstk_darwin;
    if (strcmp(n, "__assert_rtn") == 0) return (void *)machold_assert_rtn;
    if (strcmp(n, "dlsym") == 0) {
        g_trace_dlsym = getenv("MACHOLD_TRACE_DLSYM") != NULL;
        LOG("  interpose dlsym (Darwin pseudo-handle translation)\n");
        return (void *)machold_dlsym;
    }
    if (strcmp(n, "$ss042_stdlib_isOSVersionAtLeastOrVariantVersiondE0yBi1_Bw_BwBwBwBwBwtF") == 0)
        return (void *)machold_os_version_atleast;

    // ObjC-interop class realization (ObservableObject's model classes) — synthesize the
    // root class/metaclass + empty cache + the field-layout pass; see above. No ObjC runtime.
    if (strcmp(n, "_objc_empty_cache") == 0) return machold_objc_empty_cache;
    if (strcmp(n, "OBJC_CLASS_$__TtCs12_SwiftObject") == 0)    { machold_init_swiftobject(); return machold_SwiftObject_class; }
    if (strcmp(n, "OBJC_METACLASS_$__TtCs12_SwiftObject") == 0){ machold_init_swiftobject(); return machold_SwiftObject_meta; }
    if (strcmp(n, "swift_updateClassMetadata2") == 0)          return (void *)machold_updateClassMetadata2;
    // Realize the binary's ObjC-interop classes ourselves; delegate other singletons.
    if (strcmp(n, "swift_getSingletonMetadata") == 0) {
        g_trace_meta = getenv("MACHOLD_TRACE_META") != NULL;
        LOG("  interpose swift_getSingletonMetadata (ObjC-interop class realization)\n");
        return (void *)machold_getSingletonMetadata;
    }
    if (getenv("MACHOLD_TRACE_META") && strcmp(n, "swift_allocObject") == 0) {
        if (!g_real_allocobj) g_real_allocobj = (allocobj_fn)dlsym(RTLD_DEFAULT, "swift_allocObject");
        if (g_real_allocobj) return (void *)machold_allocObject_trace;
    }

    // Darwin libmalloc introspection. glibc's malloc_usable_size has the same contract
    // (block size backing ptr, ≥ the requested size) — it's what the Linux stdlib's own
    // _swift_stdlib_malloc_size shim calls. -O binaries inline stdlib bodies (e.g.
    // _ContiguousArrayBuffer growth) that call malloc_size directly.
    if (strcmp(n, "malloc_size") == 0)
        return dlsym(RTLD_DEFAULT, "malloc_usable_size");

    // ContiguousBytes.withUnsafeBytes protocol-requirement dispatch thunk (…FTj). The
    // Linux libs don't export dispatch thunks (built without library evolution), and no
    // Swift-source shim can take this call: the thunk uses the WITNESS-METHOD convention
    // (x0/x1 closure, x2 = R metadata, x3 = Self metadata, x4 = Self:ContiguousBytes
    // witness table, x20 = indirect self, x8 = indirect result) while Swift lowers any
    // expressible substitute with Self metadata FIRST — x2/x3 swapped, which is how the
    // old libSwiftUI shim corrupted the heap (-O Data.init(Sequence) inlines a cast to
    // ContiguousBytes and calls this thunk; see FOUNDATION-ISSUE.md). A thunk's entire
    // job is witness dispatch, so do exactly that: Linux witness tables are absolute
    // 8-byte entries, [0] = conformance descriptor, [1] = the protocol's sole
    // requirement (withUnsafeBytes). Load and tail-branch; argument registers untouched.
    if (strcmp(n, "$s10Foundation15ContiguousBytesP010withUnsafeC0yqd__qd__SWKXEKlFTj") == 0) {
        LOG("  interpose ContiguousBytes.withUnsafeBytes dispatch thunk (witness-call asm)\n");
        return (void *)machold_cb_withUnsafeBytes_Tj;
    }

    // Interpose runtime type-lookup to rewrite `10Foundation…` → the Linux split modules
    // (see machold_getType2). Always on — it's a correctness rewrite like the symbol one,
    // and it preserves behavior for non-Foundation names (passes them straight through).
    if (strcmp(n, "swift_getTypeByMangledNameInContext2") == 0) {
        if (!g_real_gettype2)
            g_real_gettype2 = (gettype2_fn)dlsym(RTLD_DEFAULT, "swift_getTypeByMangledNameInContext2");
        if (g_real_gettype2) {
            LOG("  interpose swift_getTypeByMangledNameInContext2 (Foundation type-lookup rewrite)\n");
            return (void *)machold_getType2;
        }
    }
    if (strcmp(n, "swift_getTypeByMangledNameInContextInMetadataState2") == 0) {
        if (!g_real_gettypeMS2)
            g_real_gettypeMS2 = (gettypeMS2_fn)dlsym(RTLD_DEFAULT, "swift_getTypeByMangledNameInContextInMetadataState2");
        if (g_real_gettypeMS2) {
            LOG("  interpose swift_getTypeByMangledNameInContextInMetadataState2 (type-lookup rewrite)\n");
            return (void *)machold_getTypeMS2;
        }
    }

    // Diagnostic: interpose __DataStorage.init(bytes:length:) to make the storage
    // effectively immortal (see machold_ds_init_immortal). Forward to the real Linux
    // init (FoundationEssentials) and remember it + swift_retain in globals the
    // trampoline reads. Gated by MACHOLD_IMMORTAL_DATA.
    if (g_immortal_data &&
        strcmp(n, "$s10Foundation13__DataStorageC5bytes6lengthACSVSg_Sitcfc") == 0) {
        if (!machold_real_ds_init)
            machold_real_ds_init = dlsym(RTLD_DEFAULT,
                "$s20FoundationEssentials13__DataStorageC5bytes6lengthACSVSg_Sitcfc");
        if (!machold_swift_retain)
            machold_swift_retain = dlsym(RTLD_DEFAULT, "swift_retain");
        if (machold_real_ds_init && machold_swift_retain) {
            LOG("  interpose __DataStorage.init(bytes:length:) -> immortal trampoline\n");
            return (void *)machold_ds_init_immortal;
        }
        LOG("  immortal-data requested but real init/retain unresolved; falling through\n");
    }

    // SUBSTITUTION-SHIFT CASUALTY: the textual 12CoreGraphics7CGFloatV→10Foundation7CGFloatV
    // rewrite (below) changes the symbol's WORD LIST ("Core","Graphics" → "Foundation"),
    // so any LATER word-substitution index in the same symbol shifts by one — dlsym is
    // byte-exact and misses. StrokeStyle.init is the first such symbol (Darwin: …So0pH0V…,
    // ours: …So0oH0V…). Map it exactly; future CoreGraphics-param symbols with trailing
    // substitutions need the same treatment (or a demangle-level rewriter).
    if (strcmp(n, "$s7SwiftUI11StrokeStyleV9lineWidth0E3Cap0E4Join10miterLimit4dash0K5PhaseAC12CoreGraphics7CGFloatV_So06CGLineG0VSo0pH0VALSayALGALtcfC") == 0)
        return dlsym(RTLD_DEFAULT, "$s7SwiftUI11StrokeStyleV9lineWidth0E3Cap0E4Join10miterLimit4dash0K5PhaseAC10Foundation7CGFloatV_So06CGLineG0VSo0oH0VALSayALGALtcfC");

    // Swift+ObjC hybrid (plutil): Darwin Foundation thunks whose Linux equivalent differs by
    // more than a module rename (value types moved to FoundationEssentials with 0A0E extension
    // markers + word-substitution shifts). Exact Darwin→Linux pairs verified against the Linux
    // Foundation .so symbol tables. Table-driven so more can be added by harvest.
    static const struct { const char *from, *to; } bridge_exact[] = {
        // Data value type → 20FoundationEssentials
        { "$s10Foundation4DataV10contentsOf7optionsAcA3URLVh_So20NSDataReadingOptionsVtKcfC",
          "$s20FoundationEssentials4DataV10contentsOf7optionsAcA3URLVh_AC14ReadingOptionsVtKcfC" },
        { "$s10Foundation4DataV13base64Encoded7optionsACSgSSh_So27NSDataBase64DecodingOptionsVtcfC",
          "$s20FoundationEssentials4DataV13base64Encoded7optionsACSgSSh_AC21Base64DecodingOptionsVtcfC" },
        { "$s10Foundation4DataV19base64EncodedString7optionsSSSo27NSDataBase64EncodingOptionsV_tF",
          "$s20FoundationEssentials4DataV19base64EncodedString7optionsSSAC21Base64EncodingOptionsV_tF" },
        { "$s10Foundation4DataV5write2to7optionsyAA3URLV_So20NSDataWritingOptionsVtKF",
          "$s20FoundationEssentials4DataV5write2to7optionsyAA3URLV_AC14WritingOptionsVtKF" },
        { "$s10Foundation4DataV19_bridgeToObjectiveCSo6NSDataCyF",
          "$s20FoundationEssentials4DataV0A0E19_bridgeToObjectiveCAD6NSDataCyF" },
        { "$s10Foundation4DataV36_unconditionallyBridgeFromObjectiveCyACSo6NSDataCSgFZ",
          "$s20FoundationEssentials4DataV0A0E36_unconditionallyBridgeFromObjectiveCyAcD6NSDataCSgFZ" },
        { "$s10Foundation4DataVAA0B8ProtocolAAMc",
          "$s20FoundationEssentials4DataVAA0C8ProtocolAAMc" },
        // URL / Date value types
        { "$s10Foundation3URLV8filePath13directoryHint10relativeToACSS_AC09DirectoryF0OACSgtcfC",
          "$s20FoundationEssentials3URLV8filePath13directoryHint10relativeToACSS_AC09DirectoryG0OACSgtcfC" },
        { "$s10Foundation4DateV026timeIntervalSinceReferenceB0Sdvg",
          "$s20FoundationEssentials4DateV026timeIntervalSinceReferenceC0Sdvg" },
        { "$s10Foundation4DateV9formattedy12FormatOutputQzxAA0D5StyleRzAC0D5InputRtzlF",
          "$s20FoundationEssentials4DateV9formattedy12FormatOutputQzxAA0E5StyleRzAC0E5InputRtzlF" },
        { "$s10Foundation4DateV18ISO8601FormatStyleVAA0dE0AAMc",
          "$s20FoundationEssentials4DateV18ISO8601FormatStyleVAA0eF0AAMc" },
        // CocoaError → Essentials; _convert* stay in Foundation (So0E0C→AA0E0C)
        { "$s10Foundation10CocoaErrorV03_nsC0So7NSErrorCvg",
          "$s20FoundationEssentials10CocoaErrorV0A0E03_nsD0AD7NSErrorCvg" },
        { "$s10Foundation10CocoaErrorVAA21_BridgedStoredNSErrorAAMc",
          "$s20FoundationEssentials10CocoaErrorV0A021_BridgedStoredNSErrorADMc" },
        { "$s10Foundation22_convertErrorToNSErrorySo0E0Cs0C0_pF",
          "$s10Foundation22_convertErrorToNSErroryAA0E0Cs0C0_pF" },
        { "$s10Foundation22_convertNSErrorToErrorys0E0_pSo0C0CSgF",
          "$s10Foundation22_convertNSErrorToErrorys0E0_pAA0C0CSgF" },
        // StringProtocol exts: NSStringCompareOptions became a nested Swift type on Linux
        { "$sSy10FoundationE16rangeOfCharacter4from7options0B0SnySS5IndexVGSgAA0D3SetV_So22NSStringCompareOptionsVAItF",
          "$sSy10FoundationE16rangeOfCharacter4from7options0B0SnySS5IndexVGSgAA0D3SetV_SS0A10EssentialsE14CompareOptionsVAItF" },
        { "$sSy10FoundationE20replacingOccurrences2of4with7options5rangeSSqd___qd_0_So22NSStringCompareOptionsVSnySS5IndexVGSgtSyRd__SyRd_0_r0_lF",
          "$sSy10FoundationE20replacingOccurrences2of4with7options5rangeSSqd___qd_0_SS0A10EssentialsE14CompareOptionsVSnySS5IndexVGSgtSyRd__SyRd_0_r0_lF" },
        { "$sSy10FoundationE7compare_7options5range6localeSo18NSComparisonResultVqd___So22NSStringCompareOptionsVSnySS5IndexVGSgAA6LocaleVSgtSyRd__lF",
          "$sSy10FoundationE7compare_7options5range6locale0A10Essentials16ComparisonResultOqd___SSAFE14CompareOptionsVSnySS5IndexVGSgAF6LocaleVSgtSyRd__lF" },
    };
    for (size_t r = 0; r < sizeof(bridge_exact)/sizeof(bridge_exact[0]); r++)
        if (strcmp(n, bridge_exact[r].from) == 0) {
            void *a = dlsym(RTLD_DEFAULT, bridge_exact[r].to);
            if (a) return a;
        }

    // Apply textual rewrites into a scratch buffer.
    char buf[1024];
    strncpy(buf, n, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';

    static const struct { const char *from, *to; } rewrites[] = {
        { "12CoreGraphics7CGFloatV", "10Foundation7CGFloatV" },
        { "So8NSBundleC",           "10Foundation6BundleC"  },
        { "So6CGSizeV",             "10Foundation6CGSizeV"  },  // __C.CGSize → Foundation.CGSize (e.g. GeometryProxy.size.getter)
        { "So14NSUserDefaultsC",    "10Foundation12UserDefaultsC" },  // @AppStorage init's store: param
        // Swift+ObjC hybrid: Darwin's imported __C classes are Swift-defined on Linux, mangled
        // as substitution back-ref AA (Foundation is subst #0), NOT 10Foundation. Covers
        // Array/Dict/String _bridgeToObjectiveC / _(un)conditionallyBridgeFromObjectiveC.
        { "So7NSArrayC",            "AA7NSArrayC"            },
        { "So12NSDictionaryC",      "AA12NSDictionaryC"     },
        { "So8NSStringC",           "AA8NSStringC"          },
    };
    for (size_t r = 0; r < sizeof(rewrites)/sizeof(rewrites[0]); r++)
        str_replace_all(buf, sizeof(buf), rewrites[r].from, rewrites[r].to);

    void *addr = dlsym(RTLD_DEFAULT, buf);
    if (!addr && strcmp(buf, n) != 0)           // fall back to the un-rewritten name
        addr = dlsym(RTLD_DEFAULT, n);

    // Foundation module split: macOS ships a monolithic Foundation, but the Linux
    // toolchain (swift-foundation) splits the core value types into FoundationEssentials
    // (Date/Data/URL/JSON/UUID/…) and i18n into FoundationInternationalization, while
    // DateFormatter/NumberFormatter/etc. stay in Foundation. So a binary's
    // `$s10Foundation…` import may live under a different module name on Linux. Try the
    // alternatives (the as-is attempt above already handles what's still in Foundation).
    if (!addr && strstr(buf, "10Foundation")) {
        static const char *mods[] = { "20FoundationEssentials", "30FoundationInternationalization" };
        for (size_t m = 0; m < sizeof(mods)/sizeof(mods[0]) && !addr; m++) {
            char fb[1024];
            strncpy(fb, buf, sizeof(fb) - 1); fb[sizeof(fb) - 1] = '\0';
            str_replace_all(fb, sizeof(fb), "10Foundation", mods[m]);
            addr = dlsym(RTLD_DEFAULT, fb);
            if (addr) { LOG("  bind %-60s -> %p (via %s)\n", buf, addr, mods[m]); return addr; }
        }
    }
    if (addr) LOG("  bind %-60s -> %p\n", buf, addr);
    return addr;
}

// ───────────────────────────────── main ──────────────────────────────────────

int main(int argc, char **argv) {
    if (getenv("MACHOLD_VERBOSE")) g_verbose = 1;
    if (getenv("MACHOLD_IMMORTAL_DATA")) g_immortal_data = 1;
    if (getenv("MACHOLD_TYPELOG")) g_typelog = 1;
    if (argc < 2) DIE("usage: %s <macho-binary> [args...]\n", argv[0]);
    const char *path = argv[1];

    // ── Map the file for parsing (linkedit, fixups, sections live in the file).
    int fd = open(path, O_RDONLY);
    if (fd < 0) DIE("open %s: %s\n", path, strerror(errno));
    struct stat st;
    if (fstat(fd, &st) < 0) DIE("fstat: %s\n", strerror(errno));
    uint8_t *file = mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
    if (file == MAP_FAILED) DIE("mmap file: %s\n", strerror(errno));

    mach_header_64 *mh = (mach_header_64 *)file;
    if (mh->magic != MH_MAGIC_64) DIE("not a 64-bit Mach-O (magic %#x)\n", mh->magic);
    if (mh->cputype != CPU_TYPE_ARM64) DIE("not arm64 (cputype %#x)\n", mh->cputype);
    int is_arm64e = (mh->cpusubtype & 0x00FFFFFF) == 2;   // CPU_SUBTYPE_ARM64E (capability bits masked off)
    LOG("Mach-O arm64%s, ncmds=%u\n", is_arm64e ? "e" : "", mh->ncmds);

    // ── First pass: gather segments, entry, fixups, swift sections.
    segment_command_64 *segs[16]; int nsegs = 0;
    uint64_t min_vmaddr = UINT64_MAX, max_vmaddr = 0;
    uint64_t entryoff = 0; int have_entry = 0;
    linkedit_data_command *chained = NULL;
    // swift metadata sections to register: name -> (vmaddr, size)
    struct { const char *name; uint64_t addr, size; } swiftsec[] = {
        { "__swift5_types", 0, 0 }, { "__swift5_proto", 0, 0 },
        { "__objc_classlist", 0, 0 }, { "__objc_catlist", 0, 0 },
        { "__unwind_info", 0, 0 },   // Apple compact unwind → PC→LSDA table for exceptions
    };

    load_command *lc = (load_command *)(file + sizeof(mach_header_64));
    for (uint32_t i = 0; i < mh->ncmds; i++) {
        if (lc->cmd == LC_SEGMENT_64) {
            segment_command_64 *sg = (segment_command_64 *)lc;
            if (strcmp(sg->segname, "__PAGEZERO") != 0) {
                segs[nsegs++] = sg;
                if (sg->vmaddr < min_vmaddr) min_vmaddr = sg->vmaddr;
                if (sg->vmaddr + sg->vmsize > max_vmaddr) max_vmaddr = sg->vmaddr + sg->vmsize;
            }
            // scan sections for swift metadata
            section_64 *sec = (section_64 *)(sg + 1);
            for (uint32_t s = 0; s < sg->nsects; s++) {
                for (size_t k = 0; k < sizeof(swiftsec)/sizeof(swiftsec[0]); k++)
                    if (strncmp(sec[s].sectname, swiftsec[k].name, 16) == 0) {
                        swiftsec[k].addr = sec[s].addr;
                        swiftsec[k].size = sec[s].size;
                    }
            }
        } else if (lc->cmd == LC_MAIN) {
            entryoff = ((entry_point_command *)lc)->entryoff;
            have_entry = 1;
        } else if (lc->cmd == LC_DYLD_CHAINED_FIXUPS) {
            chained = (linkedit_data_command *)lc;
        } else if (lc->cmd == LC_LOAD_DYLIB || lc->cmd == LC_LOAD_WEAK_DYLIB ||
                   lc->cmd == LC_REEXPORT_DYLIB) {
            // Record the dependency graph. Today imports are bound by name via dlsym to
            // Linux backings; becoming a real dyld (to host Apple's *real* Foundation
            // Mach-O) means recursively loading these instead — classify which need a
            // real Mach-O (the bottom layer) vs which we already back on Linux.
            dylib_command *dl = (dylib_command *)lc;
            const char *name = (const char *)lc + dl->name_offset;
            const char *base = strrchr(name, '/'); base = base ? base + 1 : name;
            int weak = (lc->cmd == LC_LOAD_WEAK_DYLIB);
            int reconstructed = strstr(name, "SwiftUI") || strstr(name, "Combine"); // our libSwiftUI.so / libCombine.so
            int linux_backed = strstr(name, "/swift/libswift") || strstr(name, "libSystem");
            const char *cls = reconstructed ? "[reconstructed]"
                            : linux_backed  ? "[Linux-backed]"
                                            : "[needs real Mach-O → bottom layer]";
            LOG("  dependency %-32s %s%s\n", base, weak ? "(weak) " : "", cls);
        }
        lc = (load_command *)((uint8_t *)lc + lc->cmdsize);
    }
    if (!have_entry) DIE("no LC_MAIN\n");
    if (!chained) DIE("no LC_DYLD_CHAINED_FIXUPS (only chained-fixup binaries supported)\n");

    // ── Reserve a contiguous span, then map each segment at its slid address.
    size_t span = round_up(max_vmaddr - min_vmaddr, 0x4000);
    uint8_t *base = mmap(NULL, span, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (base == MAP_FAILED) DIE("reserve %zu bytes: %s\n", span, strerror(errno));
    int64_t slide = (int64_t)(uintptr_t)base - (int64_t)min_vmaddr;
    LOG("image base=%p slide=%#lx span=%#zx\n", base, (long)slide, span);

    for (int i = 0; i < nsegs; i++) {
        segment_command_64 *sg = segs[i];
        uint8_t *addr = base + (sg->vmaddr - min_vmaddr);
        if (sg->filesize > 0) {
            // Map file contents writable first (fixups patch __DATA_CONST/__DATA);
            // we leave them writable — harmless for this loader.
            int prot = prot_from_initprot(sg->initprot) | PROT_WRITE;
            void *m = mmap(addr, round_up(sg->filesize, 0x1000), prot,
                           MAP_PRIVATE | MAP_FIXED, fd, sg->fileoff);
            if (m == MAP_FAILED) DIE("map %.16s: %s\n", sg->segname, strerror(errno));
        }
        LOG("mapped %-14.16s vmaddr=%#llx -> %p size=%#llx prot=%u\n",
            sg->segname, (unsigned long long)sg->vmaddr, (void *)addr,
            (unsigned long long)sg->vmsize, sg->initprot);
    }

    // ── Bring up the Swift runtime + our reconstructed SwiftUI by loading the
    // host libs into the global scope, so the binds below (dlsym RTLD_DEFAULT)
    // and the runtime's own image registration are all live.
    const char *self = argv[0];
    char dir[1024]; strncpy(dir, self, sizeof(dir)-1); dir[sizeof(dir)-1]=0;
    char *sl = strrchr(dir, '/'); if (sl) *sl = 0; else strcpy(dir, ".");
    // SwiftUI and the host reference each other's C symbols (run/update ↔ dispatch).
    // Load SwiftUI first LAZY+GLOBAL so its symbols are in scope (its references to
    // the host's run/update are deferred), then the host NOW (its dispatch ref now
    // resolves from SwiftUI). The host's deferred run/update bind on first call.
    char libpath[1100];
    // Reconstructed Combine (7Combine… ABI) — loaded before SwiftUI, which imports it
    // (StateObject/ObservedObject). GLOBAL so the binary's 7Combine imports resolve too.
    snprintf(libpath, sizeof(libpath), "%s/libCombine.so", dir);
    if (!dlopen(libpath, RTLD_LAZY | RTLD_GLOBAL)) DIE("dlopen Combine: %s\n", dlerror());
    snprintf(libpath, sizeof(libpath), "%s/libSwiftUI.so", dir);
    if (!dlopen(libpath, RTLD_LAZY | RTLD_GLOBAL)) DIE("dlopen SwiftUI: %s\n", dlerror());
    snprintf(libpath, sizeof(libpath), "%s/libcompat_host.so", dir);
    if (!dlopen(libpath, RTLD_NOW | RTLD_GLOBAL)) DIE("dlopen host: %s\n", dlerror());

    // ── Apply chained fixups.
    dyld_chained_fixups_header *fh = (dyld_chained_fixups_header *)(file + chained->dataoff);
    dyld_chained_import *imports = (dyld_chained_import *)((uint8_t *)fh + fh->imports_offset);
    const char *sympool = (const char *)((uint8_t *)fh + fh->symbols_offset);
    if (fh->imports_format != DYLD_CHAINED_IMPORT)
        DIE("unsupported imports_format %u\n", fh->imports_format);
    LOG("fixups: %u imports\n", fh->imports_count);

    // Pre-resolve every imported symbol once. Collect ALL unresolved non-weak
    // imports and report them together (much faster to grow the reconstruction
    // than dying on the first miss).
    void **import_addr = calloc(fh->imports_count, sizeof(void *));
    int n_missing = 0;
    for (uint32_t i = 0; i < fh->imports_count; i++) {
        uint32_t bits = imports[i].bits;
        int weak = (bits >> 8) & 1;
        uint32_t name_off = bits >> 9;
        const char *name = sympool + name_off;
        import_addr[i] = resolve_symbol(name);
        if (!import_addr[i] && !weak) {
            fprintf(stderr, "[machold] UNRESOLVED: %s\n", name);
            n_missing++;
        }
    }
    if (n_missing) DIE("%d unresolved import(s) — see UNRESOLVED lines above\n", n_missing);

    dyld_chained_starts_in_image *starts =
        (dyld_chained_starts_in_image *)((uint8_t *)fh + fh->starts_offset);
    int nfix = 0;
    for (uint32_t s = 0; s < starts->seg_count; s++) {
        if (starts->seg_info_offset[s] == 0) continue;
        dyld_chained_starts_in_segment *seg =
            (dyld_chained_starts_in_segment *)((uint8_t *)starts + starts->seg_info_offset[s]);
        int fmt = seg->pointer_format;
        // arm64e (formats 9/12): auth@63, bind@62, 11-bit next, stride 8, PAC ignored.
        // 64/64_OFFSET (2/6): bind@63, 12-bit next, stride 4. All are vm-offset targets here
        // (64 is technically vmaddr but our probes/relocations treat base+target uniformly).
        int arm64e = (fmt == DYLD_CHAINED_PTR_ARM64E_USERLAND24 || fmt == DYLD_CHAINED_PTR_ARM64E_USERLAND);
        if (!arm64e && fmt != DYLD_CHAINED_PTR_64_OFFSET && fmt != DYLD_CHAINED_PTR_64)
            DIE("unsupported pointer_format %u\n", fmt);
        int stride = arm64e ? 8 : 4;
        int ord_bits = (fmt == DYLD_CHAINED_PTR_ARM64E_USERLAND) ? 16 : 24;

        for (uint16_t pg = 0; pg < seg->page_count; pg++) {
            uint16_t start = seg->page_start[pg];
            if (start == DYLD_CHAINED_PTR_START_NONE) continue;
            if (start & DYLD_CHAINED_PTR_START_MULTI)
                DIE("multi-start pages unsupported\n");

            uint64_t cursor = seg->segment_offset + (uint64_t)pg * seg->page_size + start;
            for (;;) {
                uint64_t *loc = (uint64_t *)(base + cursor);
                uint64_t raw = *loc;
                int is_bind, is_auth = 0;
                uint32_t next;
                if (arm64e) {
                    is_auth = (raw >> 63) & 1;
                    is_bind = (raw >> 62) & 1;
                    next    = (raw >> 51) & 0x7FF;
                } else {
                    is_bind = (raw >> 63) & 1;
                    next    = (raw >> 51) & 0xFFF;
                }

                if (is_bind) {
                    uint32_t ordinal = raw & ((1u << ord_bits) - 1);
                    uint64_t addend = 0;
                    if (!arm64e)          addend = (raw >> 24) & 0xFF;           // 64/OFFSET: 8-bit
                    else if (!is_auth)    addend = (raw >> 32) & 0x7FFFF;        // arm64e non-auth: 19-bit
                    if (ordinal >= fh->imports_count) DIE("bind ordinal OOB\n");
                    void *t = import_addr[ordinal];                              // PAC auth ignored
                    *loc = t ? (uint64_t)((uint8_t *)t + addend) : 0;
                } else if (arm64e && is_auth) {
                    uint64_t target = raw & 0xFFFFFFFFULL;                       // 32-bit vmoffset
                    *loc = (uint64_t)(uintptr_t)base + target;                   // PAC signing dropped
                } else if (arm64e) {
                    uint64_t target = raw & ((1ULL << 43) - 1);                  // 43-bit vmoffset
                    uint64_t high8  = (raw >> 43) & 0xFF;
                    *loc = (uint64_t)(uintptr_t)base + target + (high8 << 56);
                } else {
                    uint64_t target = raw & 0xFFFFFFFFFULL;                      // 36-bit vmoffset
                    uint64_t high8  = (raw >> 36) & 0xFF;
                    *loc = (uint64_t)(uintptr_t)base + target + (high8 << 56);
                }
                nfix++;
                if (next == 0) break;
                cursor += next * stride;
            }
        }
    }
    LOG("applied %d fixups\n", nfix);

    // ── Patch Darwin-ABI class-metadata size reads (see FOUNDATION-ISSUE.md).
    // With ObjC interop, class metadata begins {isa, superclass, cache×2, data} = 40
    // bytes, putting instanceSize at +0x30 and instanceAlignMask at +0x34. Linux class
    // metadata has only the 16-byte {kind, superclass} header — the same fields live at
    // +0x18 / +0x1c. -O binaries inline resilient class allocation (metadata accessor →
    // size/align read → swift_allocObject) with the Darwin offsets baked in, so against
    // Linux-provided metadata they read garbage, under-allocate, and the class's init
    // then writes real ivars past the block — heap corruption (e.g. __DataStorage in
    // the Data probes). Rewrite the idiom's adjacent instruction pair
    //   LDR Wt,[Xn,#0x30]; LDRH Wt2,[Xn,#0x34]   →   #0x18 / #0x1c.
    if (!getenv("MACHOLD_NO_METAFIX")) {
        int npatch = 0;
        for (int i = 0; i < nsegs; i++) {
            segment_command_64 *sg = segs[i];
            if (!(sg->initprot & 4) || sg->filesize < 8) continue;   // exec segments only
            uint32_t *insn = (uint32_t *)(base + (sg->vmaddr - min_vmaddr));
            uint64_t ninsn = sg->filesize / 4;
            int seg_patched = 0;
            for (uint64_t k = 0; k + 1 < ninsn; k++) {
                uint32_t a = insn[k], b = insn[k + 1];
                if ((a & 0xFFFFFC00u) != 0xB9403000u) continue;      // ldr  Wt,[Xn,#0x30]
                if ((b & 0xFFFFFC00u) != 0x79406800u) continue;      // ldrh Wt2,[Xn,#0x34]
                if (((a >> 5) & 31) != ((b >> 5) & 31)) continue;    // same base register
                insn[k]     = 0xB9401800u | (a & 0x3FFu);            // ldr  Wt,[Xn,#0x18]
                insn[k + 1] = 0x79403800u | (b & 0x3FFu);            // ldrh Wt2,[Xn,#0x1c]
                LOG("  metafix @%p: instanceSize/alignMask read -> Linux offsets\n",
                    (void *)&insn[k]);
                seg_patched++;
            }
            if (seg_patched)   // flush only this segment's mapped file pages (gaps are PROT_NONE)
                __builtin___clear_cache((char *)insn, (char *)insn + sg->filesize);
            npatch += seg_patched;
        }
        if (npatch) LOG("patched %d Darwin class-metadata size reads\n", npatch);
    }

    // ── Register the image's Swift metadata so the runtime can find the binary's
    // own nominal types / conformances (ContentView, HelloApp, …). Our SwiftUI.so
    // registered itself as a normal ELF on dlopen; this covers the Mach-O image.
    void (*reg_types)(const void *, const void *) =
        (void (*)(const void *, const void *))dlsym(RTLD_DEFAULT, "swift_registerTypeMetadataRecords");
    void (*reg_confs)(const void *, const void *) =
        (void (*)(const void *, const void *))dlsym(RTLD_DEFAULT, "swift_registerProtocolConformances");
    for (size_t k = 0; k < sizeof(swiftsec)/sizeof(swiftsec[0]); k++) {
        if (!swiftsec[k].size) continue;
        const void *b = base + (swiftsec[k].addr - min_vmaddr);
        const void *e = (const uint8_t *)b + swiftsec[k].size;
        if (strcmp(swiftsec[k].name, "__swift5_types") == 0 && reg_types) reg_types(b, e);
        if (strcmp(swiftsec[k].name, "__swift5_proto") == 0 && reg_confs) reg_confs(b, e);
        if (strcmp(swiftsec[k].name, "__unwind_info") == 0) {   // build PC→LSDA for exceptions
            machold_build_eh_table((const uint8_t *)b, base);
            LOG("built EH table: %d funcs with LSDA\n", g_eh_nfuncs);
        }
        // ObjC class registry: register each app class by name (class_ro.name @ data+24)
        // so objc_getClass / NSClassFromString find it. Pointers already rebased by fixups.
        if (strcmp(swiftsec[k].name, "__objc_classlist") == 0) {
            for (void *const *p = (void *const *)b; (const void *)p < e; p++) {
                uint8_t *cls = (uint8_t *)*p;
                if (!cls) continue;
                uintptr_t data = *(uintptr_t *)(cls + 32) & ~(uintptr_t)0x7;
                if (data) machold_register_class(*(const char **)(data + 24), cls);
            }
        }
        // ObjC categories: merge each category's method lists into the side-table the
        // dispatcher consults. category_t {name@0, cls@8, instanceMethods@16, classMethods@24}.
        if (strcmp(swiftsec[k].name, "__objc_catlist") == 0) {
            for (void *const *p = (void *const *)b; (const void *)p < e; p++) {
                uint8_t *cat = (uint8_t *)*p;
                if (!cat) continue;
                void *tcls = *(void **)(cat + 8);                      // target class
                uint8_t *imeth = *(uint8_t **)(cat + 16), *cmeth = *(uint8_t **)(cat + 24);
                if (tcls && imeth) machold_add_category(tcls, imeth);  // instance methods → class
                if (tcls && cmeth) machold_add_category(*(void **)tcls, cmeth);  // class methods → metaclass
                LOG("  category %s on %p (+%d imethods)\n", cat ? *(const char **)cat : "?",
                    tcls, imeth ? *(int *)(imeth + 4) : 0);
            }
        }
        LOG("registered %s [%p,%p)\n", swiftsec[k].name, b, e);
    }

    // ── Jump to LC_MAIN entry: int main(argc, argv, envp, apple).
    typedef int (*entry_fn)(int, char **, char **, char **);
    entry_fn entry = (entry_fn)(base + entryoff);
    char apple0[1200]; snprintf(apple0, sizeof(apple0), "executable_path=%s", path);
    char *apple[] = { apple0, NULL };
    extern char **environ;

    // arm64e binaries sign pointers with PAC; machold binds them UNSIGNED, so on a
    // PAC-enabled CPU the code's aut*/braa auth-branches would fault. Disable all PAC keys
    // for this thread right before entry (SCTLR_EL1.En{IA,IB,DA,DB,GA}=0 → pac*/aut* become
    // NOPs → unsigned pointers are used verbatim). Only for arm64e; the plain-arm64 path
    // (probes) never uses PAC and is left untouched. machold itself is built without
    // pac-ret, so disabling keys doesn't affect its own returns.
    if (is_arm64e) machold_disable_pac();
    g_prog_argc = argc - 1; g_prog_argv = argv + 1;   // what the program sees (NSProcessInfo)
    LOG("calling entry @ %p\n", (void *)entry);

    int rc = entry(argc - 1, argv + 1, environ, apple);
    LOG("entry returned %d\n", rc);
    return rc;
}
