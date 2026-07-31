// G10: NSPopUpButton (dropdown) → the host picker node with per-option dispatch. Selecting
// an option sets selectedIndex + fires the action, which echoes the chosen title into a label.
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

@interface Ctl : NSObject { NSTextField *_echo; }
- (void)setEcho:(NSTextField *)e;
- (void)chose:(id)sender;
@end
@implementation Ctl
- (void)setEcho:(NSTextField *)e { _echo = e; }
- (void)chose:(id)sender {
    [_echo setStringValue:[NSString stringWithFormat:@"Color: %@", [sender titleOfSelectedItem]]];
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
        [win setTitle:@"Picker"];

        Ctl *ctl = [[Ctl alloc] init];
        NSStackView *stack = [[NSStackView alloc] init];
        [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
        [stack addArrangedSubview:[NSTextField labelWithString:@"Pick a color:"]];

        NSPopUpButton *popup = [[NSPopUpButton alloc] init];
        [popup addItemsWithTitles:@[@"Red", @"Green", @"Blue"]];
        [popup selectItemAtIndex:0];
        [popup setTarget:ctl];
        [popup setAction:@selector(chose:)];
        [stack addArrangedSubview:popup];

        NSTextField *echo = [NSTextField labelWithString:@"Color: Red"];
        [ctl setEcho:echo];
        [stack addArrangedSubview:echo];

        [win setContentView:stack];
        [win makeKeyAndOrderFront:nil];
        [app activateIgnoringOtherApps:YES];
        [app run];
    }
    return 0;
}
