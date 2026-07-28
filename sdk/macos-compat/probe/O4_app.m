// O4: a small pure-ObjC "app" — the tier-2 analog of the Swift RealApp milestone.
// An NSObject subclass (Task) holding an NSString* ivar + a BOOL, an NSMutableArray of
// them, iteration, and constant-string messaging. Exercises object-typed ivars, BOOL
// args, super-init, and the collection API — the substance of real ObjC.
#import <objc/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <objc/runtime.h>
#include <stdio.h>

@interface Task : NSObject {
    NSString *_title;
    int _done;
}
- (instancetype)initWithTitle:(NSString *)t done:(int)d;
- (NSString *)title;
- (int)done;
@end

@implementation Task
- (instancetype)initWithTitle:(NSString *)t done:(int)d {
    self = [super init];
    if (self) { _title = t; _done = d; }
    return self;
}
- (NSString *)title { return _title; }
- (int)done { return _done; }
@end

int main(void) {
    NSMutableArray *tasks = [[NSMutableArray alloc] init];
    [tasks addObject:[[Task alloc] initWithTitle:@"Buy milk" done:0]];
    [tasks addObject:[[Task alloc] initWithTitle:@"Ship objc" done:1]];
    [tasks addObject:[[Task alloc] initWithTitle:@"Write report" done:0]];

    long n = [tasks count];
    long done = 0;
    for (long i = 0; i < n; i++) {
        Task *t = [tasks objectAtIndex:i];
        if ([t done]) done++;
        printf("[%s] %s\n", [t done] ? "x" : " ", [[t title] UTF8String]);
    }
    printf("%ld/%ld done\n", done, n);
    return (n == 3 && done == 1) ? 0 : 1;
}
