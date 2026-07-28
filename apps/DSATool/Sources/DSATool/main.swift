// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/// DSATool — Debug helper for DesktopShellApp.
///
/// Usage:
///   DSATool click <contentX> <contentY>          Left-click at content-relative position
///   DSATool rightclick <contentX> <contentY>      Right-click at content-relative position
///   DSATool screenshot [path]                      Capture screenshot (default: /tmp/dsa_screenshot.png)
///   DSATool info                                   Print window position/size info
///
/// Content coordinates are relative to the Flutter content area (origin top-left).
/// The tool auto-detects the DesktopShellApp window position via CGWindowList.

import AppKit
import CoreGraphics
import Foundation

// MARK: - Window Discovery

struct WindowInfo {
    let pid: pid_t
    let windowID: CGWindowID
    let frame: CGRect       // Screen coords (origin top-left of screen)
    let titleBarHeight: CGFloat
}

func findDesktopShellAppWindow() -> WindowInfo? {
    // Find the running app
    let apps = NSWorkspace.shared.runningApplications.filter {
        $0.localizedName == "DesktopShellApp"
    }
    guard let app = apps.first else {
        fputs("ERROR: DesktopShellApp not running\n", stderr)
        return nil
    }

    // Get window list for this PID
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        fputs("ERROR: Could not get window list\n", stderr)
        return nil
    }

    for window in windowList {
        guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
              ownerPID == app.processIdentifier,
              let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat],
              let windowID = window[kCGWindowNumber as String] as? CGWindowID
        else { continue }

        let frame = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )

        // Skip tiny windows (menu bar items, etc.)
        if frame.width < 100 || frame.height < 100 { continue }

        // Estimate title bar height: window height - content height.
        // NSWindow with titlebar is typically 28-32pt taller than content.
        // Our content is 900pt, window is ~932pt → titlebar ~32pt.
        let titleBarHeight: CGFloat = frame.height - 900.0
        let clamped = max(titleBarHeight, 0)

        return WindowInfo(
            pid: app.processIdentifier,
            windowID: windowID,
            frame: frame,
            titleBarHeight: clamped
        )
    }

    fputs("ERROR: No DesktopShellApp window found on screen\n", stderr)
    return nil
}

// MARK: - Actions

func activateApp(_ pid: pid_t) {
    let apps = NSWorkspace.shared.runningApplications.filter {
        $0.processIdentifier == pid
    }
    apps.first?.activate()
    Thread.sleep(forTimeInterval: 0.3)
}

func contentToScreen(_ contentPos: CGPoint, window: WindowInfo) -> CGPoint {
    return CGPoint(
        x: window.frame.origin.x + contentPos.x,
        y: window.frame.origin.y + window.titleBarHeight + contentPos.y
    )
}

func sendClick(at screenPos: CGPoint, button: CGMouseButton = .left) {
    let downType: CGEventType = button == .left ? .leftMouseDown : .rightMouseDown
    let upType: CGEventType = button == .left ? .leftMouseUp : .rightMouseUp

    // Move mouse
    let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                       mouseCursorPosition: screenPos, mouseButton: button)!
    move.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.1)

    // Mouse down
    let down = CGEvent(mouseEventSource: nil, mouseType: downType,
                       mouseCursorPosition: screenPos, mouseButton: button)!
    down.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.05)

    // Mouse up
    let up = CGEvent(mouseEventSource: nil, mouseType: upType,
                     mouseCursorPosition: screenPos, mouseButton: button)!
    up.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.5)
}

func captureScreenshot(windowID: CGWindowID, path: String) {
    // Use screencapture CLI for reliability
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    task.arguments = ["-x", "-l", "\(windowID)", path]
    try? task.run()
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        print("Screenshot saved to \(path)")
    } else {
        fputs("ERROR: screencapture failed (exit \(task.terminationStatus))\n", stderr)
    }
}

// MARK: - Main

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("""
    Usage:
      DSATool click <contentX> <contentY>
      DSATool rightclick <contentX> <contentY>
      DSATool screenshot [path]
      DSATool info
    """)
    exit(1)
}

let command = args[1]

switch command {
case "click", "rightclick":
    guard args.count >= 4,
          let cx = Double(args[2]),
          let cy = Double(args[3])
    else {
        fputs("Usage: DSATool \(command) <contentX> <contentY>\n", stderr)
        exit(1)
    }
    guard let window = findDesktopShellAppWindow() else { exit(1) }
    activateApp(window.pid)
    let screenPos = contentToScreen(CGPoint(x: cx, y: cy), window: window)
    let button: CGMouseButton = command == "rightclick" ? .right : .left
    print("\(command) content=(\(cx), \(cy)) → screen=(\(screenPos.x), \(screenPos.y))")
    sendClick(at: screenPos, button: button)
    print("Done")

case "screenshot":
    let path = args.count >= 3 ? args[2] : "/tmp/dsa_screenshot.png"
    guard let window = findDesktopShellAppWindow() else { exit(1) }
    captureScreenshot(windowID: window.windowID, path: path)

case "info":
    guard let window = findDesktopShellAppWindow() else { exit(1) }
    print("PID:            \(window.pid)")
    print("Window ID:      \(window.windowID)")
    print("Frame:          \(window.frame)")
    print("Title bar:      \(window.titleBarHeight)pt")
    print("Content origin: (\(window.frame.origin.x), \(window.frame.origin.y + window.titleBarHeight))")
    print("Content size:   \(window.frame.width) x \(window.frame.height - window.titleBarHeight)")

default:
    fputs("Unknown command: \(command)\n", stderr)
    exit(1)
}
