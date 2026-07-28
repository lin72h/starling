// L1 host stub. The reconstructed SwiftUI module (libSwiftUI.so) crosses into the
// "host" through these two C symbols, handing over the reflected view tree as JSON.
// On macOS the host renders the tree via the Flutter engine + an NSWindow; here we
// just print it, to prove the unmodified Mach-O binary loaded, reached App.main(),
// and walked its own SwiftUI view tree. Flutter wiring is milestone L2.
//
// swiftui_compat_dispatch (the tap → SwiftUI action → @State path) lives in
// libSwiftUI.so and is driven by the host; L1 has no event source yet.

#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>

void swiftui_compat_run(const char *json) {
    printf("─── [linux host] swiftui_compat_run — Flutter would render: ───\n%s\n", json);
    fflush(stdout);

    // With MACHOLD_TAP set, simulate the user tapping button id 0 to exercise the
    // full interaction loop through the unmodified binary: GestureDetector would
    // call swiftui_compat_dispatch(id) → the app's SwiftUI action → @State mutates
    // → re-walk → swiftui_compat_update. (No real event source until L2/Flutter.)
    // MACHOLD_TAP's value is a tap COUNT (default 1) — taps accumulate, so a value of
    // 3 on a counter app shows 0→1→2→3, proving @State/@StateObject persistence.
    const char *tap = getenv("MACHOLD_TAP");
    if (tap) {
        void (*dispatch)(long) =
            (void (*)(long))dlsym(RTLD_DEFAULT, "swiftui_compat_dispatch");
        if (dispatch) {
            int n = atoi(tap); if (n < 1) n = 1;
            for (int i = 0; i < n; i++) {
                printf("─── [linux host] simulating tap %d/%d on button 0 ───\n", i + 1, n);
                fflush(stdout);
                dispatch(0);
            }
        }
    }
}

void swiftui_compat_update(const char *json) {
    printf("─── [linux host] swiftui_compat_update: ───\n%s\n", json);
    fflush(stdout);
}
