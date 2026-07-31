// G8: editable NSTextField with a target/action — the last interactive AppKit mechanism
// (host→app TEXT routing). On submit the host calls swiftui_compat_text(id, text); machold
// sets the field's stringValue and fires its action, which echoes the text into a label.
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

@interface Ctl : NSObject { NSTextField *_echo; }
- (void)setEcho:(NSTextField *)e;
- (void)submit:(id)sender;
@end
@implementation Ctl
- (void)setEcho:(NSTextField *)e { _echo = e; }
- (void)submit:(id)sender {
    [_echo setStringValue:[NSString stringWithFormat:@"You typed: %@", [sender stringValue]]];
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
        [win setTitle:@"Echo"];

        Ctl *ctl = [[Ctl alloc] init];
        NSStackView *stack = [[NSStackView alloc] init];
        [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];

        NSTextField *field = [NSTextField textFieldWithString:@""];
        [field setEditable:YES];
        [field setTarget:ctl];
        [field setAction:@selector(submit:)];
        NSTextField *echo = [NSTextField labelWithString:@"You typed: (nothing)"];
        [ctl setEcho:echo];

        [stack addArrangedSubview:[NSTextField labelWithString:@"Enter your name:"]];
        [stack addArrangedSubview:field];
        [stack addArrangedSubview:echo];
        [win setContentView:stack];
        [win makeKeyAndOrderFront:nil];
        [app activateIgnoringOtherApps:YES];
        [app run];
    }
    return 0;
}
