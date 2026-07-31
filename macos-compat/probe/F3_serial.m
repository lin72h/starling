// F3: NSJSONSerialization + NSPropertyListSerialization via the machold⇄Swift-Foundation
// bridge. The real Swift serializers parse/emit; the results are machold-native collections
// the binary messages directly (objectForKey:/objectAtIndex:/integerValue).
#import <Foundation/Foundation.h>
#include <string.h>
#include <stdio.h>

int main(void) {
    @autoreleasepool {
        // ── JSON parse → machold-native NSDictionary
        const char *json = "{\"name\":\"machold\",\"version\":3,\"ok\":true,"
                           "\"tags\":[\"alpha\",\"beta\"],\"ratio\":1.5}";
        NSData *jd = [NSData dataWithBytes:json length:strlen(json)];
        NSDictionary *d = [NSJSONSerialization JSONObjectWithData:jd options:0 error:nil];
        NSString *name = [d objectForKey:@"name"];
        NSNumber *ver  = [d objectForKey:@"version"];
        NSArray  *tags = [d objectForKey:@"tags"];
        printf("name=%s version=%ld tags=%lu tag1=%s\n",
               [name UTF8String], (long)[ver integerValue],
               (unsigned long)[tags count], [[tags objectAtIndex:1] UTF8String]);

        // ── JSON serialize (round-trip)
        NSData *out = [NSJSONSerialization dataWithJSONObject:d options:0 error:nil];
        printf("json_len=%lu\n", (unsigned long)[out length]);

        // ── plist (XML) parse → machold-native NSDictionary
        const char *xml = "<?xml version=\"1.0\"?><plist version=\"1.0\"><dict>"
                          "<key>greeting</key><string>hi</string>"
                          "<key>n</key><integer>99</integer></dict></plist>";
        NSData *pd = [NSData dataWithBytes:xml length:strlen(xml)];
        NSDictionary *pl = [NSPropertyListSerialization propertyListWithData:pd options:0 format:NULL error:nil];
        printf("plist_greeting=%s plist_n=%ld\n",
               [[pl objectForKey:@"greeting"] UTF8String], (long)[[pl objectForKey:@"n"] integerValue]);

        return (name && [ver integerValue] == 3 && [tags count] == 2 &&
                [[pl objectForKey:@"n"] integerValue] == 99) ? 0 : 1;
    }
}
