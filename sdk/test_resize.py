#!/usr/bin/env python3
"""Test SettingsApp maximize resize in DRM mode.

1. Right-click desktop to open context menu
2. Click "Display Settings" menu item
3. Wait for Settings to launch
4. Click maximize button on Settings window
5. Take screenshot
"""
import struct, time, os, fcntl, array, signal

EVENT_FMT = 'llHHi'
EV_SYN, EV_KEY, EV_ABS = 0, 1, 3
SYN_REPORT, ABS_X, ABS_Y = 0, 0, 1
BTN_LEFT, BTN_RIGHT = 0x110, 0x111
DEVICE = '/dev/input/event2'

def make_event(etype, code, value):
    t = time.time()
    return struct.pack(EVENT_FMT, int(t), int((t % 1) * 1e6), etype, code, value)

def syn():
    return make_event(EV_SYN, SYN_REPORT, 0)

fd = os.open(DEVICE, os.O_WRONLY)

# Query axis ranges
buf = array.array('i', [0]*6)
fcntl.ioctl(fd, 0x80184540 + 0, buf); max_x = buf[2]
fcntl.ioctl(fd, 0x80184540 + 1, buf); max_y = buf[2]
W, H = 1280, 800

def move_to(px_x, px_y):
    ax = int(px_x * max_x / W)
    ay = int(px_y * max_y / H)
    os.write(fd, make_event(EV_ABS, ABS_X, ax))
    os.write(fd, make_event(EV_ABS, ABS_Y, ay))
    os.write(fd, syn())
    time.sleep(0.05)

def click(px_x, px_y, button=BTN_LEFT):
    move_to(px_x, px_y)
    time.sleep(0.05)
    os.write(fd, make_event(EV_KEY, button, 1))
    os.write(fd, syn())
    time.sleep(0.05)
    os.write(fd, make_event(EV_KEY, button, 0))
    os.write(fd, syn())

def screenshot():
    """Send SIGUSR1 to DesktopShellApp to take screenshot."""
    import subprocess
    result = subprocess.run(['pgrep', '-f', 'DesktopShellApp --drm'],
                          capture_output=True, text=True)
    pids = result.stdout.strip().split('\n')
    # Get the actual app PID (not sudo/bash wrappers)
    for pid in pids:
        pid = pid.strip()
        if pid:
            try:
                cmdline = open(f'/proc/{pid}/cmdline').read()
                if '.build/debug/DesktopShellApp' in cmdline and 'sudo' not in cmdline and 'bash' not in cmdline:
                    os.kill(int(pid), signal.SIGUSR1)
                    print(f"Sent SIGUSR1 to PID {pid}")
                    time.sleep(1)
                    return
            except:
                pass
    print("Could not find DesktopShellApp process")

# Step 1: Right-click on desktop center to open context menu
print("Step 1: Right-click desktop...")
click(640, 400, BTN_RIGHT)
time.sleep(1)

# Step 2: Click "Display Settings" (2nd real item in context menu)
# Context menu appears at (640, 400). Items are roughly:
#   "Change Wallpaper" at ~y=400+20
#   separator
#   "Display Settings" at ~y=400+60
#   "Open Text Viewer" at ~y=400+90
print("Step 2: Click Display Settings...")
click(740, 460)
time.sleep(4)  # Wait for settings app to launch and connect

# Take screenshot to see initial state
print("Taking pre-maximize screenshot...")
screenshot()
time.sleep(1)

# Step 3: Maximize the Settings window
# Settings window opens at Rect.fromLTWH(100, 60, 800, 592)
# Title bar height is 30px (DesktopTheme.kTitleBarHeight)
# Maximize button is the 2nd from right in the title bar
# Buttons are 46px wide each, right-aligned in the title bar
# Window right edge = 100 + 800 = 900
# Close button: x ≈ 900 - 23 = 877 (center of rightmost 46px button)
# Maximize button: x ≈ 900 - 46 - 23 = 831
# Title bar y center: 60 + 15 = 75
print("Step 3: Click maximize button...")
click(831, 75)
time.sleep(3)  # Wait for resize to complete

# Take screenshot to verify
print("Taking post-maximize screenshot...")
screenshot()

os.close(fd)
print("Done!")
