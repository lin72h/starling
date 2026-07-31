// A1: A0 + a static text label. NSTextField labelWithString: (class factory) added to
// the window's contentView. Enumerates NSView/NSTextField surface: contentView,
// addSubview:, setFrame:, labelWithString:, setStringValue:.
#import <Cocoa/Cocoa.h>

int main(void) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];

        NSWindow *win = [[NSWindow alloc]
            initWithContentRect:NSMakeRect(100, 100, 400, 300)
                      styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                        backing:NSBackingStoreBuffered
                          defer:NO];
        [win setTitle:@"A1"];

        NSTextField *label = [NSTextField labelWithString:@"Hello, AppKit"];
        [label setFrame:NSMakeRect(20, 140, 360, 24)];

        NSView *content = [win contentView];
        [content addSubview:label];

        [win makeKeyAndOrderFront:nil];
        [app activateIgnoringOtherApps:YES];
        [app run];
    }
    return 0;
}
