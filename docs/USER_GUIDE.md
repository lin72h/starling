# Starling User Guide

A tour of the desktop: what you see at first login, how to move around, the
keyboard shortcuts, the apps, and how to install more. If Starling is not yet
installed, start with the [Installation Guide](INSTALL.md).

Starling's interaction model is close to macOS — if you have used a Mac, most
of this will feel familiar.

---

## Choosing Starling at login

Installing Starling doesn't replace your current desktop — it adds a session
you pick at the login screen. To start it:

1. **Click your name** at the login screen.
2. **Open the session menu** — usually a gear, or a small icon in a lower
   corner of the password box.
3. Choose **Starling** from the list, then enter your password and sign in.

Starling stays selected for next time. The session menu only appears with a
Wayland-capable login manager (GDM has one); it looks a little different on
LightDM or SDDM, but the step is the same — find the session picker and choose
Starling. (See the [Installation Guide](INSTALL.md#log-in-to-starling) if you
don't see a session menu at all.)

## First login

Once you sign in, you land on the desktop:

- a **wallpaper** filling the screen,
- a thin **menu bar** across the top, with the clock and status indicators,
- a **dock** floating at the bottom, holding your apps.

That is the whole desktop. Everything else is reached from the dock, the
Launchpad, or a right-click on the wallpaper.

---

## The dock

The dock sits at the bottom of the screen. Out of the box it holds the six
first-party apps, in order: **Launchpad**, **Settings**, **Files**,
**Terminal**, **Calculator**, **App Store**.

- **Click** an icon to launch or focus that app.
- A **running app shows an indicator** under its icon.
- **Drag** an icon to reorder the dock.
- **Right-click** an icon for its menu, including **Remove from Dock**.

Installed apps that aren't pinned appear in the dock while they run, and drop
off when they close.

---

## The Launchpad

The first dock icon opens the **Launchpad** — a full-screen grid of every app
Starling knows about, over a blurred background.

- **Click** any app to launch it.
- **Type** to filter the grid by name — start typing and only matching apps
  remain.
- Click empty space or press **Esc** to dismiss it.

---

## Windows

Windows have a title bar with three **macOS-style colored circle buttons** on
the left — close, minimize, maximize.

- **Drag the title bar** to move a window.
- **Drag an edge or corner** to resize it.
- **Double-click the title bar** to toggle maximized.
- The **maximize** button does the same.

By default windows **float** — you place them freely. You can switch the whole
desktop to **tiling** (a dwm-style master-and-stack layout, where windows share
the screen automatically) with the **Tiling Windows** switch in
[Settings](#settings). Toggling it back restores your floating layout.

---

## Spaces and Mission Control

Starling has **spaces** (virtual desktops) and a **Mission Control** overview,
driven from the keyboard the way macOS does it.

| Do this | To |
|---|---|
| **Ctrl + →** / **Ctrl + ←** | Slide to the next / previous space |
| **Ctrl + Shift + →** / **←** | Carry the focused window to the next / previous space |
| **Ctrl + Tab** | Cycle through your spaces |
| **Ctrl + ↑** | Open **Mission Control** (all spaces and windows at once) |
| **Ctrl + ↓** | Open the **AI Space** (see below) |
| **Esc** | Close Mission Control |

In Mission Control, **Ctrl + ← / →** retargets the active space instantly. To
add a space, right-click the wallpaper and choose **New Desktop**.

`Ctrl` + arrows belong to the system — apps never see them — so they work no
matter which window is focused.

---

## Right-click the desktop

Right-click anywhere on the wallpaper for the desktop menu:

- **Change Wallpaper**
- **Mission Control**
- **New Desktop** — add a space
- **AI Space**
- switch **appearance** (light / dark)
- **Remove This Desktop** — when you have more than one

---

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| **Ctrl + →** / **←** | Adjacent space |
| **Ctrl + Shift + →** / **←** | Move focused window to adjacent space |
| **Ctrl + Tab** | Cycle spaces |
| **Ctrl + ↑** | Mission Control |
| **Ctrl + ↓** | AI Space |
| **Ctrl + Space** | Toggle the input method (fcitx5, for CJK and other IME input) |
| **Esc** | Close Mission Control; release a taken-over agent window |
| Double-click title bar | Maximize / restore a window |

---

## The apps

Five first-party apps ship with Starling, all written against its Swift
framework:

- **Settings** — appearance, displays, network, sound, and system information.
  See [below](#settings).
- **Files** — browse your home directory and the filesystem.
- **Terminal** — a real terminal with a PTY; runs your login shell (`$SHELL`,
  falling back to bash). TUI programs like `vim` and `htop` work.
- **Calculator** — a basic calculator.
- **App Store** — install more applications. See
  [below](#installing-more-apps).

Text Editor, Image Viewer and Video Player ship in the package too, and
appear in the Launchpad alongside the rest.

---

## Settings

The Settings app has five sections in its sidebar:

- **General** — **System Information**: the Starling version, your Ubuntu
  release, kernel, and Mesa version.
- **Network** — see and join **Wi-Fi** networks.
- **Displays** — display information. Note: **scaling is pinned to 2.0** in
  this release, and there is no display-mode selection yet.
- **Appearance** — the **Dark Mode** switch (the same light/dark choice as the
  desktop right-click menu), **Tiling Windows** to switch between floating and
  tiling window management, **Sound & Brightness**, and a **Notifications**
  toggle (present but inert — there is no notification service behind it yet).
- **About** — about the desktop.

---

## Installing more apps

Starling launches applications that are installed on your machine — it does not
bundle them. Two ways to add them:

### Through the App Store

Open the **App Store** from the dock. It lists a curated set of applications —
Chrome, VS Code, Slack, Discord, Teams, Telegram, IntelliJ IDEA, GIMP, Blender,
Spotify, Zoom, and more. Click **Install** on one and Starling installs it
using your system's own `apt` (you may be asked to authenticate — this is
`polkit` authorising the install). When it finishes, the app appears in the
Launchpad and can be pinned to the dock.

A few things to know about the store in this release:

- The catalog is **small and curated** — every entry installs and launches,
  but it is not your whole software library.
- Tiles use **generic category glyphs**, not vendor logos, on purpose — those
  logos are trademarks and Starling ships none of them. Chrome and VS Code show
  their real icons in the Launchpad and dock (read from your system at
  runtime); the rest use a neutral glyph.

### With your distribution's packaging

Anything you install the normal way — `sudo apt install <package>`, a `.deb`, a
Snap or Flatpak — is a native Linux app, and Starling will run it as a Wayland
client (or through the in-tree X server for X11 apps). The major toolkits
composite today: Chromium/Electron, Qt6, GTK3 and GTK4.

---

## The AI Space

**Ctrl + ↓** opens the **AI Space** — a workbench where an AI agent can drive
apps in a column beside a conversation. This is an early, in-development
feature: the workbench and its plumbing exist, but there is no agent wired to
it yet, so for now it is a preview of the layout rather than a working
assistant. **Ctrl + ↓** again (or the desktop menu) returns you to your
desktop.

---

## Things to know in this release

Starling is an early preview (v0.2.3). A few limits you will notice:

- **No screen lock or screensaver.** Do not rely on it to secure an unattended
  machine.
- **No notifications yet.** The Settings toggle is inert.
- **Scaling is fixed at 2.0.** Fractional scaling produced blurry text and is
  not usable yet.
- **No display-mode picker.** The session uses the connector's preferred mode.
- **Zoom runs without audio.** It starts and reports `no pactl and pacmd
  found`. That message is expected: `pactl` is deliberately left off the system
  because Zoom crashes at startup when it is present. **Do not install
  `pulseaudio-utils` to fix it** — that trades a silent Zoom for one that will
  not start. Sound in other apps (Chrome, Slack, Teams) is unaffected.
- Verified on **AMD** and **virtio-gpu** graphics; Intel and NVIDIA are not yet
  tested.

If something misbehaves, the session log is at
`/tmp/starling-session-<your-uid>.log`, and issues go to
<https://github.com/starling-build/starling/issues>.

---

*See also: the [Installation Guide](INSTALL.md), and the project
[README](../README.md) for the technical picture and what does and doesn't work
yet.*
