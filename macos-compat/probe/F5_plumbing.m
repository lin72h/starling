// F5: CLI-tool plumbing — NSString rangeOfString: (NSRange struct return) / path methods,
// NSFileHandle writeData: (stdout via fd 1), NSCharacterSet, NSAutoreleasePool.
#import <Foundation/Foundation.h>
#include <string.h>
#include <stdio.h>

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSString *last = [@"/a/b/c.plist" lastPathComponent];
    NSString *exp  = [@"~/x" stringByExpandingTildeInPath];
    NSRange r = [@"hello world" rangeOfString:@"world"];
    NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet];
    BOOL sp = [ws characterIsMember:' '];

    NSString *out = [NSString stringWithFormat:@"last=%@ exp_has_x=%d loc=%lu sp=%d\n",
                     last, (int)([exp length] > 2), (unsigned long)r.location, (int)sp];
    NSFileHandle *fh = [NSFileHandle fileHandleWithStandardOutput];
    [fh writeData:[out dataUsingEncoding:4 /*NSUTF8StringEncoding*/]];

    int ok = (r.location == 6 && [last isEqualToString:@"c.plist"] && sp);
    [pool drain];
    return ok ? 0 : 1;
}
