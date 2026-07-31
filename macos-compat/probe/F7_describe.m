// F7: -description (OpenStep-plist rendering of a machold-native tree) + string trim, over a
// dict produced by the bridged JSON parser. Verifies the formatting/string pieces defaults uses.
#import <Foundation/Foundation.h>
#include <string.h>
#include <stdio.h>

int main(void) {
    @autoreleasepool {
        const char *json = "{\"a\":1,\"b\":\"hi\",\"c\":[10,20]}";
        NSData *d = [NSData dataWithBytes:json length:strlen(json)];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        NSString *desc = [dict description];
        printf("desc:\n%s\n", [desc UTF8String]);

        NSString *t = [@"  hi  " stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        printf("trim=[%s]\n", [t UTF8String]);

        return ([desc length] > 0 && strcmp([t UTF8String], "hi") == 0) ? 0 : 1;
    }
}
