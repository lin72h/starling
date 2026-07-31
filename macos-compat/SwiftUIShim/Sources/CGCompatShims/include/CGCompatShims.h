// C declarations that must mangle in the __C namespace (So…V) to match Darwin
// imports. Plain C enums import into Swift as RawRepresentable STRUCTS named after
// the typedef — exactly how Darwin's CGLineCap/CGLineJoin appear in SwiftUI symbol
// manglings (So9CGLineCapV / So10CGLineJoinV, both struct-kind V, 4 bytes).
// Used by the reconstructed StrokeStyle (Shape.stroke / .border).
#ifndef CG_COMPAT_SHIMS_H
#define CG_COMPAT_SHIMS_H

typedef enum CGLineCap : int {
    kCGLineCapButt = 0,
    kCGLineCapRound = 1,
    kCGLineCapSquare = 2,
} CGLineCap;

typedef enum CGLineJoin : int {
    kCGLineJoinMiter = 0,
    kCGLineJoinRound = 1,
    kCGLineJoinBevel = 2,
} CGLineJoin;

#endif
