// G4: NSStackView (modern layout) + more controls — a small form. Harvest with
// MACHOLD_OBJC_LENIENT, then implement. NSStackView.addArrangedSubview: maps to a
// column/row; NSSlider/editable NSTextField/checkbox exercise more RNode node types.
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

@interface Ctl : NSObject { NSTextField *_status; int _n; }
- (void)setStatus:(NSTextField *)s;
- (void)inc:(id)sender;
@end
@implementation Ctl
- (void)setStatus:(NSTextField *)s { _status = s; }
- (void)inc:(id)sender { (void)sender; _n++; [_status setStringValue:[NSString stringWithFormat:@"n = %d", _n]]; }
@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        NSWindow *win = [[NSWindow alloc]
            initWithContentRect:NSMakeRect(100, 100, 400, 300)
                      styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                        backing:NSBackingStoreBuffered defer:NO];
        [win setTitle:@"Form"];

        Ctl *ctl = [[Ctl alloc] init];
        NSStackView *stack = [[NSStackView alloc] init];
        [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
        [stack setSpacing:12];

        NSTextField *title  = [NSTextField labelWithString:@"AppKit Form"];
        NSTextField *status = [NSTextField labelWithString:@"n = 0"];
        NSButton *btn = [NSButton buttonWithTitle:@"Increment" target:ctl action:@selector(inc:)];
        NSSlider *slider = [NSSlider sliderWithValue:50 minValue:0 maxValue:100 target:nil action:NULL];

        [stack addArrangedSubview:title];
        [stack addArrangedSubview:status];
        [stack addArrangedSubview:btn];
        [stack addArrangedSubview:slider];
        [ctl setStatus:status];

        [win setContentView:stack];
        [win makeKeyAndOrderFront:nil];
        [app activateIgnoringOtherApps:YES];
        [app run];
    }
    return 0;
}
