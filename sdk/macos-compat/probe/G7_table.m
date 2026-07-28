// G7: NSTableView (cell-based) with an NSTableViewDataSource. The tree walk must message
// BACK INTO the app — numberOfRowsInTableView: then tableView:objectValueForTableColumn:row:
// per row — to pull the data (the reverse direction of button dispatch).
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

@interface DS : NSObject
- (NSInteger)numberOfRowsInTableView:(NSTableView *)t;
- (id)tableView:(NSTableView *)t objectValueForTableColumn:(NSTableColumn *)c row:(NSInteger)r;
@end
@implementation DS
- (NSInteger)numberOfRowsInTableView:(NSTableView *)t { (void)t; return 3; }
- (id)tableView:(NSTableView *)t objectValueForTableColumn:(NSTableColumn *)c row:(NSInteger)r {
    (void)t; (void)c;
    NSArray *names = @[@"Alice", @"Bob", @"Carol"];
    return [names objectAtIndex:r];
}
@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        NSWindow *win = [[NSWindow alloc]
            initWithContentRect:NSMakeRect(100, 100, 400, 300)
                      styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                        backing:NSBackingStoreBuffered defer:NO];
        [win setTitle:@"People"];

        NSStackView *stack = [[NSStackView alloc] init];
        [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
        [stack addArrangedSubview:[NSTextField labelWithString:@"People"]];

        NSTableView *table = [[NSTableView alloc] init];
        NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"name"];
        [table addTableColumn:col];
        DS *ds = [[DS alloc] init];
        [table setDataSource:ds];
        [table reloadData];
        [stack addArrangedSubview:table];

        [win setContentView:stack];
        [win makeKeyAndOrderFront:nil];
        [app activateIgnoringOtherApps:YES];
        [app run];
    }
    return 0;
}
