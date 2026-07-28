// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

#if os(Linux)
import Glibc
#endif

/// The desktop's login user — the human this session belongs to.
///
/// Unprivileged launches (libseat session, packaged install): simply the
/// current user. Root DRM dev mode (run-shell-gpu.sh): the owner of
/// XDG_RUNTIME_DIR — the launcher chowns it to the invoking user precisely
/// so the session's identity survives the sudo.
enum LoginUser {
    /// XDG_RUNTIME_DIR with a per-uid fallback — never a hardcoded uid.
    static var runtimeDir: String {
        ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"]
            ?? "/run/user/\(getuid())"
    }

    static var uid: uid_t {
        let me = getuid()
        if me != 0 { return me }
        var st = stat()
        if stat(runtimeDir, &st) == 0, st.st_uid != 0 { return st.st_uid }
        return me
    }

    static var name: String {
        if let pw = getpwuid(uid) { return String(cString: pw.pointee.pw_name) }
        return "root"
    }

    /// Directory for shell persistence (appearance, …): $STARLING_CONFIG_DIR,
    /// else `<login user's home>/.config/starling` — the login user's home
    /// even when the shell itself runs as root.
    static var configDir: String {
        if let env = ProcessInfo.processInfo.environment["STARLING_CONFIG_DIR"] {
            return env
        }
        if let pw = getpwuid(uid) {
            return String(cString: pw.pointee.pw_dir) + "/.config/starling"
        }
        return (ProcessInfo.processInfo.environment["HOME"] ?? "/tmp")
            + "/.config/starling"
    }
}
