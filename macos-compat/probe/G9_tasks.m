// G9: composite AppKit app — the "RealApp" of the ObjC tier. Exercises the APP-DELEGATE
// launch path (window built in applicationDidFinishLaunching:, not main()), a text field
// whose action mutates a model, and an NSTableView whose dataSource IS the delegate. One
// injected submission ("Read book") flows: text→action→model.addObject→reloadData→the walk
// re-pulls the dataSource→the new row renders.
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

@interface AppDelegate : NSObject {
    NSWindow *_win;
    NSMutableArray *_tasks;
    NSTableView *_table;
}
- (void)applicationDidFinishLaunching:(NSNotification *)note;
- (void)addTask:(id)sender;
- (NSInteger)numberOfRowsInTableView:(NSTableView *)t;
- (id)tableView:(NSTableView *)t objectValueForTableColumn:(NSTableColumn *)c row:(NSInteger)r;
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    (void)note;
    _tasks = [[NSMutableArray alloc] init];
    [_tasks addObject:@"Buy milk"];
    [_tasks addObject:@"Walk dog"];

    _win = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(100, 100, 400, 300)
                  styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                    backing:NSBackingStoreBuffered defer:NO];
    [_win setTitle:@"Tasks"];

    NSStackView *stack = [[NSStackView alloc] init];
    [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [stack addArrangedSubview:[NSTextField labelWithString:@"My Tasks"]];

    NSTextField *field = [NSTextField textFieldWithString:@""];
    [field setTarget:self];
    [field setAction:@selector(addTask:)];
    [stack addArrangedSubview:field];

    _table = [[NSTableView alloc] init];
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"task"];
    [_table addTableColumn:col];
    [_table setDataSource:self];
    [stack addArrangedSubview:_table];

    [_win setContentView:stack];
    [_win makeKeyAndOrderFront:nil];
}
- (void)addTask:(id)sender {
    NSString *s = [sender stringValue];
    if ([s length] > 0) { [_tasks addObject:s]; [_table reloadData]; }
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)t { (void)t; return [_tasks count]; }
- (id)tableView:(NSTableView *)t objectValueForTableColumn:(NSTableColumn *)c row:(NSInteger)r {
    (void)t; (void)c; return [_tasks objectAtIndex:r];
}
@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        AppDelegate *del = [[AppDelegate alloc] init];
        [app setDelegate:del];
        [app run];
    }
    return 0;
}
