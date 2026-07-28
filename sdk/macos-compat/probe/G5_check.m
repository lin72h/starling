// G5: NSButton checkbox (toggle). checkboxWithTitle:target:action: + -state/-setState:.
// The tap flips state then fires the action; renders as a button node with a check glyph
// so it reuses the working button dispatch (host .toggle has no dispatch-back).
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

@interface Ctl : NSObject { NSTextField *_s; }
- (void)setS:(NSTextField *)s;
- (void)toggled:(id)sender;
@end
@implementation Ctl
- (void)setS:(NSTextField *)s { _s = s; }
- (void)toggled:(id)sender {
    BOOL on = ([sender state] == NSControlStateValueOn);
    [_s setStringValue:(on ? @"Notifications: ON" : @"Notifications: OFF")];
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
        [win setTitle:@"Settings"];

        Ctl *ctl = [[Ctl alloc] init];
        NSStackView *stack = [[NSStackView alloc] init];
        [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];

        NSTextField *status = [NSTextField labelWithString:@"Notifications: OFF"];
        NSButton *cb = [NSButton checkboxWithTitle:@"Enable notifications" target:ctl action:@selector(toggled:)];
        [ctl setS:status];

        [stack addArrangedSubview:status];
        [stack addArrangedSubview:cb];
        [win setContentView:stack];
        [win makeKeyAndOrderFront:nil];
        [app activateIgnoringOtherApps:YES];
        [app run];
    }
    return 0;
}
