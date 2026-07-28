// F4: NSDateFormatter through the bridge — format + parse round-trip. Proves the machold⇄
// Swift-Foundation bridge generalizes past serializers to a hard-to-hand-roll API (dates).
// (The bridge formats in UTC/POSIX for deterministic output.)
#import <Foundation/Foundation.h>
#include <string.h>
#include <stdio.h>

int main(void) {
    @autoreleasepool {
        NSDate *epoch = [NSDate dateWithTimeIntervalSince1970:0];
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSString *s = [df stringFromDate:epoch];
        printf("s=%s\n", [s UTF8String]);                 // 1970-01-01 00:00:00

        NSDate *parsed = [df dateFromString:@"2020-06-15 12:30:00"];
        NSDateFormatter *yf = [[NSDateFormatter alloc] init];
        [yf setDateFormat:@"yyyy"];
        NSString *y = [yf stringFromDate:parsed];
        printf("y=%s\n", [y UTF8String]);                 // 2020

        return (strcmp([s UTF8String], "1970-01-01 00:00:00") == 0 &&
                strcmp([y UTF8String], "2020") == 0) ? 0 : 1;
    }
}
