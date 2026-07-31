// O5: key-value ObjC — NSMutableDictionary of NSString→NSNumber, with @42 boxing
// literals and lookups. Exercises numberWithInt:/intValue, setObject:forKey:/
// objectForKey:/count, and string-key comparison.
#import <objc/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>   // NSNumber
#include <stdio.h>

int main(void) {
    NSMutableDictionary *d = [[NSMutableDictionary alloc] init];
    [d setObject:@42 forKey:@"answer"];
    [d setObject:@7  forKey:@"lucky"];
    [d setObject:@100 forKey:@"answer"];   // overwrite

    NSNumber *a = [d objectForKey:@"answer"];
    NSNumber *l = [d objectForKey:@"lucky"];
    long n = [d count];
    printf("answer=%d lucky=%d count=%ld\n", [a intValue], [l intValue], n);
    return ([a intValue] == 100 && [l intValue] == 7 && n == 2) ? 0 : 1;
}
