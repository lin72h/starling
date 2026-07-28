// O2: an NSObject-rooted subclass — the real tier-2 shape. Needs a messageable
// NSObject (alloc/init) provided by machold, super dispatch ([super init] →
// objc_msgSendSuper2), an ivar, and an instance method with an int arg. Also exercises
// the variadic-printf shim (Darwin passes varargs on the stack; glibc reads registers).
#import <objc/NSObject.h>
#import <objc/runtime.h>
#include <stdio.h>

@interface Counter : NSObject {
    int _n;
}
- (int)bumpBy:(int)d;
@end

@implementation Counter
- (instancetype)init {
    self = [super init];
    if (self) _n = 10;
    return self;
}
- (int)bumpBy:(int)d { _n += d; return _n; }
@end

int main(void) {
    Counter *c = [[Counter alloc] init];
    int r = [c bumpBy:4];        // 10 + 4
    printf("objc NSObject: bumpBy=%d (want 14)\n", r);
    return r == 14 ? 0 : 1;
}
