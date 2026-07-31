// A2: A1 + an NSButton with a target/action. A controller object (Ctl) owns the action
// method; NSButton buttonWithTitle:target:action: wires it. This is the tier-2 render
// milestone work-list: window + label + button + target/action dispatch.
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#include <stdio.h>

@interface Ctl : NSObject
@property (assign) int count;
- (void)tapped:(id)sender;
@end

@implementation Ctl
- (void)tapped:(id)sender {
    self.count++;
    printf("tapped %d (sender=%p)\n", self.count, (void *)sender);
}
@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];

        NSWindow *win = [[NSWindow alloc]
            initWithContentRect:NSMakeRect(100, 100, 400, 300)
                      styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                        backing:NSBackingStoreBuffered
                          defer:NO];
        [win setTitle:@"A2"];

        NSView *content = [win contentView];

        NSTextField *label = [NSTextField labelWithString:@"Count: 0"];
        [label setFrame:NSMakeRect(20, 200, 360, 24)];
        [content addSubview:label];

        Ctl *ctl = [[Ctl alloc] init];
        NSButton *btn = [NSButton buttonWithTitle:@"Tap me"
                                           target:ctl
                                           action:@selector(tapped:)];
        [btn setFrame:NSMakeRect(20, 120, 120, 32)];
        [content addSubview:btn];

        [win makeKeyAndOrderFront:nil];
        [app activateIgnoringOtherApps:YES];
        [app run];
    }
    return 0;
}
