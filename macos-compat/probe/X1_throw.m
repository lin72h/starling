#import <Foundation/Foundation.h>
#include <stdio.h>

// Minimal ObjC throw/catch probe for machold exception-unwinding scoping.
//   @try { @throw [NSException …] } @catch (NSException *e) { … }
// Exercises: objc_exception_throw, __objc_personality_v0, objc_begin_catch/
// objc_end_catch, OBJC_EHTYPE_$_NSException, and the [NSException name]/reason
// selectors. Built arm64 with chained fixups so machold can load it.

int main(int argc, const char **argv) {
    @autoreleasepool {
        // 1) typed @catch (NSException *)
        @try {
            @throw [NSException exceptionWithName:@"MyErr"
                                          reason:@"something broke"
                                        userInfo:nil];
        } @catch (NSException *e) {
            printf("caught name=%s reason=%s\n",
                   [[e name] UTF8String], [[e reason] UTF8String]);
        }

        // 2) catch-all @catch (...)
        @try {
            @throw [NSException exceptionWithName:@"Two" reason:@"r2" userInfo:nil];
        } @catch (...) {
            printf("caught via catch-all\n");
        }

        // 3) -raise path
        @try {
            NSException *ex = [NSException exceptionWithName:@"Three"
                                                     reason:@"r3" userInfo:nil];
            [ex raise];
        } @catch (NSException *e) {
            printf("caught raise name=%s\n", [[e name] UTF8String]);
        }
    }
    printf("done\n");
    return 0;
}
