// F6: reverse-impedance — machold-native objects passed INTO Linux CF's C API. The wrappers
// detect a machold object and handle it natively (instead of CF dynamic-cast-crashing on it).
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <stdio.h>

int main(void) {
    @autoreleasepool {
        NSString *a = [NSString stringWithUTF8String:"hello"];
        NSString *b = [NSString stringWithUTF8String:"hello"];
        NSString *c = [NSString stringWithUTF8String:"world"];
        NSArray  *arr = [NSArray arrayWithObject:a];

        Boolean eq = CFEqual((CFTypeRef)a, (CFTypeRef)b);   // content-equal → true
        Boolean ne = CFEqual((CFTypeRef)a, (CFTypeRef)c);   // → false
        CFTypeID st = CFGetTypeID((CFTypeRef)a);
        CFTypeID at = CFGetTypeID((CFTypeRef)arr);
        long len = CFStringGetLength((CFStringRef)a);

        printf("eq=%d ne=%d isString=%d isArray=%d len=%ld\n",
               (int)eq, (int)!ne, (int)(st == CFStringGetTypeID()),
               (int)(at == CFArrayGetTypeID()), len);
        return (eq && !ne && st == CFStringGetTypeID() && at == CFArrayGetTypeID() && len == 5) ? 0 : 1;
    }
}
