// O8: broad (non-variadic) Foundation surface — a text/collection processing program.
// Run under MACHOLD_OBJC_LENIENT to harvest the missing-selector work-list, then again
// strict once the methods are implemented.
#import <objc/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSValue.h>
#include <stdio.h>

int main(void) {
    // NSString breadth
    NSString *s = @"the quick brown fox";
    unsigned long len = [s length];
    int hp = [s hasPrefix:@"the"];
    int hs = [s hasSuffix:@"fox"];
    int has = [s containsString:@"quick"];
    NSString *up = [s uppercaseString];
    NSArray *words = [s componentsSeparatedByString:@" "];
    unsigned long wc = [words count];
    NSString *first = [words objectAtIndex:0];
    NSString *joined = [words componentsJoinedByString:@"-"];

    // NSMutableArray breadth
    NSMutableArray *a = [[NSMutableArray alloc] init];
    [a addObject:@"a"]; [a addObject:@"b"]; [a addObject:@"c"];
    [a insertObject:@"z" atIndex:0];       // z a b c
    [a removeObjectAtIndex:2];             // z a c
    int contains = [a containsObject:@"a"];
    long idx = [a indexOfObject:@"c"];

    // NSNumber runtime boxing
    NSNumber *num = [NSNumber numberWithInt:7];
    int nv = [num intValue];

    printf("len=%lu hp=%d hs=%d has=%d up=%s wc=%lu first=%s joined=%s\n",
           len, hp, hs, has, [up UTF8String], wc, [first UTF8String], [joined UTF8String]);
    printf("acount=%lu contains=%d idx=%ld num=%d\n", [a count], contains, idx, nv);
    return 0;
}
