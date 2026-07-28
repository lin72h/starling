// O11: ObjC blocks — the block ABI (a block is {isa, flags, reserved, invoke fn@16,
// descriptor, captures…}; call it via block->invoke(block, args)). enumerateObjectsUsingBlock:
// invokes a caller-supplied block per element; a __block capture accumulates across calls.
#import <objc/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#include <stdio.h>

int main(void) {
    NSArray *words = @[@"apple", @"pie", @"is", @"great"];   // lengths 5,3,2,5
    __block long total = 0;
    __block long stoppedAt = -1;
    [words enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        total += [(NSString *)obj length];
        if (idx == 2) { stoppedAt = (long)idx; *stop = YES; }   // stop after index 2
    }];
    // total should be 5+3+2 = 10 (stopped before index 3), stoppedAt = 2
    printf("total=%ld stoppedAt=%ld\n", total, stoppedAt);
    return (total == 10 && stoppedAt == 2) ? 0 : 1;
}
