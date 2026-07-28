// O12: block-based collection APIs + NSDate. sortUsingComparator: (comparator block),
// dictionary block-enumeration, mutableCopy, and NSDate timing.
#import <objc/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSDate.h>
#include <stdio.h>

int main(void) {
    NSMutableArray *a = [@[@3, @1, @4, @1, @5, @2] mutableCopy];
    [a sortUsingComparator:^NSComparisonResult(id x, id y) {
        int xv = [x intValue], yv = [y intValue];
        return (xv < yv) ? -1 : (xv > yv ? 1 : 0);
    }];
    // a → 1,1,2,3,4,5 ; first=1 last=5
    int first = [[a objectAtIndex:0] intValue];
    int last  = [[a objectAtIndex:[a count] - 1] intValue];

    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"a"] = @10; d[@"b"] = @20; d[@"c"] = @30;
    __block long sum = 0;
    [d enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *stop) { (void)k; sum += [v intValue]; }];

    NSDate *t0 = [NSDate date];
    double ts = [t0 timeIntervalSince1970];   // real Linux epoch via gettimeofday

    printf("first=%d last=%d count=%lu sum=%ld epoch_ok=%d\n",
           first, last, [a count], sum, ts > 1000000000.0);
    return (first == 1 && last == 5 && [a count] == 6 && sum == 60 && ts > 1000000000.0) ? 0 : 1;
}
