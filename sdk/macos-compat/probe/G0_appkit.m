// A0: absolute-minimal PROGRAMMATIC AppKit app (no nib/storyboard).
// sharedApplication + activationPolicy + empty NSWindow + makeKeyAndOrderFront + [NSApp run].
// Goal: enumerate the irreducible NSApplication/NSWindow ObjC surface + the NSRect ABI.
#import <Cocoa/Cocoa.h>

int main(void) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];

        NSRect frame = NSMakeRect(100, 100, 400, 300);
        NSWindow *win = [[NSWindow alloc]
            initWithContentRect:frame
                      styleMask:(NSWindowStyleMaskTitled |
                                 NSWindowStyleMaskClosable |
                                 NSWindowStyleMaskResizable)
                        backing:NSBackingStoreBuffered
                          defer:NO];
        [win setTitle:@"A0"];
        [win makeKeyAndOrderFront:nil];
        [app activateIgnoringOtherApps:YES];
        [app run];
    }
    return 0;
}
