// F2: Foundation-fusion phase 2 — NSProcessInfo (argv/name) + NSFileManager (POSIX file
// checks/reads). The singletons CLI tools use to read their args and touch the filesystem.
#import <Foundation/Foundation.h>
#include <stdio.h>

int main(void) {
    @autoreleasepool {
        NSProcessInfo *pi = [NSProcessInfo processInfo];
        NSArray *args = [pi arguments];
        NSString *pname = [pi processName];

        NSFileManager *fm = [NSFileManager defaultManager];
        BOOL tmp = [fm fileExistsAtPath:@"/tmp"];
        BOOL nox = [fm fileExistsAtPath:@"/no_such_path_zzz"];

        printf("argc=%lu name=%s tmp=%d nox=%d\n",
               (unsigned long)[args count], [pname UTF8String], (int)tmp, (int)nox);
        return (tmp && !nox && [args count] >= 1) ? 0 : 1;
    }
}
