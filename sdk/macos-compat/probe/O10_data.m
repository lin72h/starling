// O10: array literals (@[]), fast enumeration (for-in), NSMutableSet, NSData, and
// string parsing — a small dedup/data program. Harvest with MACHOLD_OBJC_LENIENT, then
// run strict.
#import <objc/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSData.h>
#include <stdio.h>

int main(void) {
    NSArray *words = @[@"apple", @"banana", @"apple", @"cherry", @"banana"];
    NSMutableSet *seen = [NSMutableSet set];
    int dupes = 0;
    for (NSString *w in words) {                 // fast enumeration
        if ([seen containsObject:w]) dupes++;
        else [seen addObject:w];
    }

    NSData *d = [@"hello world" dataUsingEncoding:4 /*NSUTF8StringEncoding*/];
    unsigned long dlen = [d length];

    int parsed = [@"42" intValue];
    long total = 0;
    for (NSString *n in @[@"10", @"20", @"30"]) total += [n intValue];

    printf("words=%lu unique=%lu dupes=%d dlen=%lu parsed=%d total=%ld\n",
           [words count], [seen count], dupes, dlen, parsed, total);
    return (dupes == 2 && [seen count] == 3 && dlen == 11 && parsed == 42 && total == 60) ? 0 : 1;
}
