# Tests

```
test/run.sh                  static checks + unit tests   ~0.4s, no GPU
test/run.sh --build          + every package and the .deb  ~4min
test/run.sh --sdk            + sdk/ tests (see "Known gaps")
sudo test/run.sh --functional   + live-desktop checks       ~15s, needs a GPU
sudo test/functional.sh      the live-desktop checks on their own
test/vm.sh                   T3 release gate: .deb on a clean VM, GDM login
```

Run the default tier on every change. It needs no compositor, no GPU, no
network, and no build.

## Why these checks

Almost every expensive bug in this project has had the same shape: **two
places that must agree, silently disagreeing.** Nothing crashes and nothing
logs; the symptom surfaces much later as "that one app is broken".

- `wayland_server_on_shm_surface_commit` was declared, defined and called in C
  — and never registered in Swift, so every software client composited as
  nothing while its buffers were dutifully released.
- `wayland_server_on_app_id_changed`, same shape: every window's identity
  thrown away, so the dock guessed from window titles and no third-party app
  got an icon.
- An app id present in seven tables and missing from two, so IntelliJ launched
  fine but had no dock presence and no icon.

So the checks are all comparisons between two sources that must match, and
they are cheap enough that there is no excuse to skip them.

### `lint.py` — static, no build

- **Catalog**: every `registry/catalog.d/*.app` parses; `Id` matches its
  filename; `Kind` and `Glyph` are values something actually implements (the
  glyph vocabulary is *read out of* `DesktopShell.iconType(named:)` and the
  store's `iconKind`, so adding a glyph does not make the lint wrong);
  `Color` is RRGGBB; `Order`/`Dock` do not collide; `Bins` are absolute;
  `Install=` names a real recipe in `app-install.sh`; `Exec=` names a real one
  in `app-run.sh`; first-party `Exec` is a real package under `apps/` and has
  a `Window=`; `RenameWindows` has something that can identify its windows.
- **The reverse direction**: an `app-install` recipe with no catalog record
  and not in its `UNLISTED` list. That is how mpv/vlc/libreoffice/obs became
  installable but invisible to the whole desktop.
- **Wayland callbacks**: every `wayland_server_on_*` declared in
  `wayland_server.h` is registered somewhere in the Swift shell. Deliberate
  exceptions live in `KNOWN_UNREGISTERED` and each one needs a written reason
  — a bare name is not enough, because the entire point is that an
  unregistered callback is invisible.
- **Syntax**: every build script parses, each with the shell it declares
  (`run-desktop.sh` and `wechat-run.sh` are bash and use arrays, which
  `sh -n` rejects for syntax it does not have).

### `registry/Tests` — unit, `swift test`

The parsing and matching that app identity rests on: key-file group scoping
(a `.desktop` file's `[Desktop Action …]` groups must not override
`[Desktop Entry]`), `;`-lists, app_id matching, installed-ness, the default
dock, `Window=` parsing, and the `" (deleted)"` exe suffix. Every case here is
one that occurs on a real machine.

### `functional.py` — a live desktop, asserted through the broker

`sudo test/functional.sh` stands up a desktop with a fixture catalog, runs the
checks, and tears it down. Everything is asserted against broker JSON —
`list_apps` (what the launcher would show), `dock_rects` (the dock as laid out
right now) — and never against pixels. A screenshot suite over a compositor
rots faster than it catches anything: every theme tweak and animation
invalidates it, the baseline gets re-blessed, and it ends up testing nothing.
Screenshots stay artifacts for humans.

Nine checks: the shell agrees with `catalog.d` on disk; the dock's pinned slots
are the installed `Dock=` apps in order; **a real app installs through
`app-install` and appears in the launcher**; a third-party window is attributed
via app_id; **a window is not attributed to an app that merely shares its
binary**; a dock click launches a first-party app (which also exercises the
live dock geometry end to end); a record appearing and disappearing moves the
launcher with no relogin; `app-install` refuses to remove a running app; and
**that real app removes again and leaves the launcher**.

The install and remove of a real app are gated on `STARLING_TEST_INSTALL=1`
(they download a package) and `test/vm.sh` turns them on. They matter for a
reason beyond coverage: the app the identity checks need is *produced* by the
install check rather than set up behind the tests' back. An earlier version
ran `apt-get install gimp` and then `app-install --record gimp` — fabricating
the end state with the repair tool, exercising none of the real path, and
quietly making "can this desktop install an app?" a preconditon instead of a
question. `app-install <id>` is exactly the subprocess the store's Install
button runs; the store adds `pkexec`, and that hop is proved separately by the
`pkcheck` step in `test/vm.sh`.

That fourth check is what keeps the third honest. "GIMP's window was
attributed to gimp" would also pass if the shell credited any window to any
running app — so `test/fixtures/starlingnotgimp.app` shares GIMP's binary and
declares a window class matching nothing. While GIMP runs, the shell must
report the decoy as process=true, window=false.

The install/remove loop uses `test/fixtures/starlingselftest.app`: no vendor,
no download, nothing on the machine worth breaking. Testing that loop against a
real app means uninstalling real software to prove a button works — which is
how the author of these files uninstalled the user's GIMP.

Fixtures are overlaid onto a *copy* of the real catalog via
`STARLING_CATALOG_DIR`; the shipped catalog is never modified. They are
deliberately outside `lint.py`'s scope: they are test doubles, not apps, and
`starlingselftest` has an `Exec` that launches nothing on purpose.

### `vm.sh` — the release gate

`test/vm.sh` builds the .deb, reverts the VM to its clean `desktop-ready`
snapshot, installs the package the way the docs tell a user to, sets up a GDM
login, reboots into it, and then runs the functional tier **against that
session**. The harness itself stays at `$STARLING_VM` (default
`~/starling-vm`) by decision — it carries multi-gigabyte disk images — so this
script only orchestrates the `g1`/`g2`/`g3` scripts documented there.

It is the only tier that runs against the thing we actually ship, and the only
one that can see privilege-path bugs. Two have already cost real time: the
portal claiming its D-Bus name on the wrong bus (breaking every file dialog,
while working perfectly under sudo on the dev box), and `pkexec app-install`,
which polkit authorises only for the seat-active session. Every dev shell here
is SSH-launched and therefore not it, so the App Store's Install and Remove
buttons *cannot* work on the dev box — the gate proves they do in a real
login, using `pkcheck` against the session's own shell process.

Note it needs port 2222 free: the harness forwards a fixed port, and the
minimal dependency-testing VM uses the same one. The script refuses rather
than testing the wrong machine.

## Not built yet

- **Performance** — few robust metrics with generous thresholds and a trend
  CSV: shell time-to-first-frame, per-app launch-to-settled (`await_settled`
  gives a defensible signal), frame pacing, and RSS after N launch/close
  cycles as a leak canary. Not micro-benchmarks: in a virgl VM absolute
  numbers are meaningless and only regressions matter.

## Known gaps this suite has already surfaced

- **`wayland_server_on_toplevel_resize_request`** is declared and fired from
  `xdg_toplevel.set_max_size` *and* `set_min_size`, and registered nowhere.
  Client size constraints are therefore ignored. It cannot simply be wired up:
  both call sites pass the same callback with no discriminator, so a minimum
  would arrive indistinguishable from a maximum. The C side needs to split it
  in two first.
- **`sdk/` tests do not build on Ubuntu 26.04.** The `-include math.h`
  workaround this project needs for the ubuntu24.04-built 6.2.4 toolchain
  (docs/BUILDING.md) collides with `<cmath>` while the compiler builds
  swift-testing's own `_Testing_Foundation` module — before it reaches any of
  our code. Hence `--sdk` rather than a permanent red: a suite that always
  fails for a known reason is one people stop reading.
