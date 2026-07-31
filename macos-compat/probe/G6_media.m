// G6: NSProgressIndicator (determinate bar) + NSImageView (SF Symbol) — render-only controls
// mapping to the host progress/image RNode nodes.
#import <Cocoa/Cocoa.h>

int main(void) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        NSWindow *win = [[NSWindow alloc]
            initWithContentRect:NSMakeRect(100, 100, 400, 300)
                      styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                        backing:NSBackingStoreBuffered defer:NO];
        [win setTitle:@"Media"];

        NSStackView *stack = [[NSStackView alloc] init];
        [stack setOrientation:NSUserInterfaceLayoutOrientationVertical];

        NSImageView *icon = [NSImageView imageViewWithImage:
            [NSImage imageWithSystemSymbolName:@"star.fill" accessibilityDescription:@"star"]];
        NSTextField *label = [NSTextField labelWithString:@"Downloading... 65%"];
        NSProgressIndicator *bar = [[NSProgressIndicator alloc] init];
        [bar setIndeterminate:NO];
        [bar setMinValue:0];
        [bar setMaxValue:100];
        [bar setDoubleValue:65];

        [stack addArrangedSubview:icon];
        [stack addArrangedSubview:label];
        [stack addArrangedSubview:bar];
        [win setContentView:stack];
        [win makeKeyAndOrderFront:nil];
        [app activateIgnoringOtherApps:YES];
        [app run];
    }
    return 0;
}
