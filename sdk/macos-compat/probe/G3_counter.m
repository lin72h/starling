// G3: the interactive AppKit milestone — a counter. A button's target/action increments
// a count and updates the label's stringValue; the tap re-walks the window and the new
// value renders. The tier-2 analog of the SwiftUI RealApp button loop.
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

@interface Ctl : NSObject {
    NSTextField *_label;
    int _count;
}
- (void)setLabel:(NSTextField *)l;
- (void)tapped:(id)sender;
@end

@implementation Ctl
- (void)setLabel:(NSTextField *)l { _label = l; }
- (void)tapped:(id)sender {
    (void)sender;
    _count++;
    [_label setStringValue:[NSString stringWithFormat:@"Count: %d", _count]];
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
        [win setTitle:@"Counter"];
        NSView *content = [win contentView];

        NSTextField *label = [NSTextField labelWithString:@"Count: 0"];
        [label setFrame:NSMakeRect(20, 200, 360, 24)];
        [content addSubview:label];

        Ctl *ctl = [[Ctl alloc] init];
        [ctl setLabel:label];
        NSButton *btn = [NSButton buttonWithTitle:@"Increment" target:ctl action:@selector(tapped:)];
        [btn setFrame:NSMakeRect(20, 120, 140, 32)];
        [content addSubview:btn];

        [win makeKeyAndOrderFront:nil];
        [app activateIgnoringOtherApps:YES];
        [app run];
    }
    return 0;
}
