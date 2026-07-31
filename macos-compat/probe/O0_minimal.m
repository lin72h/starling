// O0: irreducible ObjC — the tier-1→tier-2 crossing. A pure class-method message,
// no ARC, no alloc, no Foundation. Imports only _objc_msgSend + __objc_empty_cache.
// Uses puts (NOT variadic printf) to report, sidestepping the separate Darwin-vs-Linux
// variadic-ABI divergence and isolating the objc_msgSend result.
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdio.h>

__attribute__((objc_root_class))
@interface MyRoot
+ (int)answer;
@end

@implementation MyRoot
+ (int)answer { return 42; }
@end

int main(void) {
    int a = [MyRoot answer];
    puts(a == 42 ? "objc msgSend PASS: answer==42" : "objc msgSend FAIL");
    return a == 42 ? 0 : 1;
}
