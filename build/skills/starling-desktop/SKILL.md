---
name: starling-desktop
description: Launch and control desktop applications on Starling — open Chrome and drive web pages, or open first-party apps (Files, Settings, Terminal) and act on their UI. Use whenever a task needs a real application rather than a shell command: filling a web form, reading a page, checking something in a GUI, or showing the user what an app looks like.
---

# Driving the Starling desktop

You are running inside the Starling desktop, and you can launch and control real
applications. Windows you launch belong to you: they appear in the AI Space
beside this conversation where the human can watch them, and they do not touch
the human's own desktop, cursor, or keyboard focus.

Everything goes through one command:

```
agent-client.py <command> [args…]
```

It lives at `/usr/lib/starling/agent-client.py` on an installed system, or
`build/agent-client.py` in a source checkout. Run `agent-client.py help` for the
full list.

## The shape of a session

Launching prints a **window id**. Pass it to every later command — that is how
commands compose across separate invocations:

```bash
win=$(agent-client.py launch chrome https://example.com)
agent-client.py fill  "$win" '#email' 'ada@example.org'
agent-client.py click "$win" 'button[type=submit]'
agent-client.py text  "$win" '#result'
```

`agent-client.py windows` lists what you currently own, which is the way to
recover the id if you lose it.

## Web pages

| Command | What it does |
|---|---|
| `launch chrome [url]` | Open a browser window (optionally at a URL) |
| `goto <win> <url>` | Navigate, waiting for the load to finish |
| `fill <win> <selector> <text>` | Type into an element (real input events) |
| `click <win> <selector>` | Click an element |
| `text <win> [selector]` | Read text back — defaults to the whole page |

Pages are addressed by **CSS selector**, never by pixel coordinates. If a
selector matches nothing the command fails and says so, rather than clicking
empty space — so when a command fails, re-read the page with `text` and pick a
selector that exists instead of retrying the same one.

**Verify your own work by reading the page back.** After submitting anything,
`text` the result and confirm it says what you expect; do not report success
because a click command exited zero.

## First-party apps

`launch files`, `launch settings`, `launch terminal` open Starling's own apps.
These are addressed semantically rather than by selector:

```bash
win=$(agent-client.py launch files)
agent-client.py tree "$win"              # node ids, labels, available actions
agent-client.py act  "$win" 12 tap       # act on a node by id
```

Node ids are only valid until the next `tree` — re-run it after acting.

## Screenshots

`agent-client.py shot <win> out.png` writes an image of the window. Use it when
the human asks what something looks like, or when `text` is not enough to tell
whether the app is in the state you expect.

## Things worth knowing

- **The human can take over at any time.** If they click into a window you are
  driving, your input to that window is refused with `paused: human has the
  controls` until they hand it back. That is not a failure to retry around —
  stop, say the human has taken over, and wait.
- **Timing.** Commands that change the UI return once the action is sent, not
  once the app has repainted. `agent-client.py settled <win>` waits for the
  repaint; use it before a screenshot, or before reading back a result that an
  app renders asynchronously.
- **Your identity persists** between commands via a state file, which is what
  lets separate invocations share windows. `agent-client.py reset` forgets it
  and starts fresh — you rarely want this.
- **Only your own windows.** You cannot list, read, capture, or act on the
  human's windows or another agent's. A command naming a window you do not own
  fails with `no such owned window`.
