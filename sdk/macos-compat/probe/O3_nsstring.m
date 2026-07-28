// O3: constant NSString literals (@"…"). Each literal is a static struct whose isa is
// ___CFConstantStringClassReference; messaging it (-length/-UTF8String) requires machold
// to provide that class with those methods. Also -stringByAppendingString: (builds a new
// string object). No real Foundation/CoreFoundation needed.
#import <Foundation/NSString.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    NSString *s = @"hello";
    NSString *t = [s stringByAppendingString:@" objc"];
    unsigned long n = [t length];
    const char *c = [t UTF8String];
    printf("str=%s len=%lu\n", c, n);
    return (n == 10 && strcmp(c, "hello objc") == 0) ? 0 : 1;
}
