// O9: variadic ObjC methods + NSMutableString. stringWithFormat: and appendFormat: are
// variadic instance/class methods — their varargs arrive on the Darwin stack (like NSLog),
// so each needs a naked va-capture IMP. NSMutableString grows via appendString:/appendFormat:.
#import <objc/NSObject.h>
#import <Foundation/NSString.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    NSString *s = [NSString stringWithFormat:@"x=%d y=%@ z=%ld", 7, @"hi", 99L];
    NSString *u = [NSString stringWithUTF8String:"from-c"];

    NSMutableString *m = [NSMutableString string];
    [m appendString:@"a"];
    [m appendFormat:@"-%d-", 42];
    [m appendString:u];
    NSString *ms = [m stringByAppendingString:@"!"];

    printf("s=%s u=%s m=%s ms=%s mlen=%lu\n",
           [s UTF8String], [u UTF8String], [m UTF8String], [ms UTF8String], [m length]);
    int ok = strcmp([s UTF8String], "x=7 y=hi z=99") == 0
          && strcmp([m UTF8String], "a-42-from-c") == 0;
    return ok ? 0 : 1;
}
