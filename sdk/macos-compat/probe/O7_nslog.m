// O7: NSLog — the standard ObjC logging/output path. Variadic, format is an NSString*
// with %@ (objects), %d/%ld/%s/%f etc. Exercises the format walker + %@ object handling
// (NSString → its UTF8) over Darwin stack-varargs.
#import <objc/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSObjCRuntime.h>   // NSLog
#include <stdio.h>

int main(void) {
    NSString *who = @"objc";
    NSString *tail = [who stringByAppendingString:@"-world"];
    int n = 42;
    long big = 1000;
    NSLog(@"hello %@ n=%d big=%ld str=%s", tail, n, big, "raw");
    return 0;
}
