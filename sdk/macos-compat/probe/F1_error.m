// F1: Foundation-fusion phase 1 — NSError + the generic ObjC runtime entry points every
// Foundation binary uses (objc_opt_new via [Class new], objc_opt_isKindOfClass via
// isKindOfClass:, objc_getProperty/objc_setProperty via a synthesized @property).
#import <Foundation/Foundation.h>
#include <stdio.h>

@interface Widget : NSObject
@property (strong) NSString *label;
@property (assign) int count;
@end
@implementation Widget
@end

int main(void) {
    @autoreleasepool {
        Widget *w = [Widget new];             // objc_opt_new
        w.label = @"hello";                   // objc_setProperty (strong)
        w.count = 7;
        NSError *e = [NSError errorWithDomain:@"MyDomain" code:42 userInfo:nil];
        BOOL k = [e isKindOfClass:[NSError class]];   // objc_opt_isKindOfClass
        printf("label=%s count=%d code=%ld domain=%s kind=%d\n",
               [w.label UTF8String], w.count, (long)[e code],
               [[e domain] UTF8String], (int)k);
        return (w.count == 7 && [e code] == 42 && k) ? 0 : 1;
    }
}
