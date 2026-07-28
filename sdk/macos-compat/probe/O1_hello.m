// O1: pure ObjC, no Foundation — instance lifecycle. Exercises +alloc (via
// class_createInstance), -init, an ivar, and an instance method taking an arg. Reports
// via puts (avoids the Darwin/Linux variadic-printf ABI gap). Custom root class.
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdio.h>

// A root class must reserve the isa slot as its first ivar (what NSObject does) — else
// the compiler puts _n at offset 0 and -init clobbers the isa. With `Class isa;` first,
// _n lands at offset 8 and the runtime isa is intact.
__attribute__((objc_root_class))
@interface Counter {
    Class isa;
    int _n;
}
+ (id)alloc;
- (id)init;
- (int)bumpBy:(int)d;
@end

@implementation Counter
+ (id)alloc { return class_createInstance(self, 0); }
- (id)init { _n = 10; return self; }
- (int)bumpBy:(int)d { _n += d; return _n; }
@end

int main(void) {
    Counter *c = [[Counter alloc] init];
    int r = [c bumpBy:4];        // 10 + 4
    puts(r == 14 ? "objc instance PASS: bumpBy==14" : "objc instance FAIL");
    return r == 14 ? 0 : 1;
}
