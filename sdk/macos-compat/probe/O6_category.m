// O6: categories + dynamic class lookup. A category on a FOREIGN class (NSObject, defined
// in libobjc) emits a real __objc_catlist entry that machold merges into its category
// side-table; objc_getClass resolves classes by name from the __objc_classlist registry.
#import <objc/NSObject.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <string.h>

// Category adds -answer to NSObject (a class we don't compile here → real __objc_catlist).
@interface NSObject (Extra)
- (int)answer;
@end
@implementation NSObject (Extra)
- (int)answer { return 42; }
@end

@interface Widget : NSObject
@end
@implementation Widget
@end

int main(void) {
    Widget *w = [[Widget alloc] init];
    int a = [w answer];                          // inherited category method on NSObject
    Class c = objc_getClass("Widget");           // dynamic lookup from the __objc_classlist registry
    Class nso = objc_getClass("NSObject");
    int ok = (a == 42) && (c == [w class]) && (nso != NULL);
    printf("answer=%d Widget=%s NSObject=%s\n", a, c ? "found" : "nil", nso ? "found" : "nil");
    return ok ? 0 : 1;
}
