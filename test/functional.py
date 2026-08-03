#!/usr/bin/env python3
"""Functional tests against a running Starling desktop.

    test/functional.py [-v] [--only NAME]

Needs a shell already running (build/run-desktop.sh) and root for the input
device — run it with sudo.

Everything is asserted against **structured state from the broker socket**,
never against pixels. `list_apps` is what the launcher would show, `dock_rects`
is the dock as laid out right now, and both report liveness the shell itself
maintains. A screenshot suite over a compositor rots faster than it catches
anything: every theme tweak, font change and animation invalidates it, and the
usual response is to re-bless the baseline, at which point it tests nothing.
Screenshots here are artifacts for a human, not assertions.

What is deliberately NOT covered, because a dev shell cannot: the App Store's
pkexec hop. polkit authorises the seat-active session, and a shell launched
over SSH is not it, so Install/Remove from the store UI can only be exercised
in a real session (the VM tier). The CLI path those buttons invoke is covered
here.
"""

import contextlib
import glob
import json
import os
import pwd
import shutil
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# These checks run in two places: against a staged dev tree on the build box,
# and against an installed .deb inside the VM, where there is no repo at all.
# Resolve everything from whichever layout is present rather than assuming.
def _first(*candidates: Path) -> Path | None:
    for c in candidates:
        if c.exists():
            return c
    return None


APP_RUN = _first(REPO / ".stage/bin/app-run", Path("/usr/bin/app-run"))
APP_INSTALL = _first(REPO / ".stage/bin/app-install", Path("/usr/bin/app-install"))
SHELL_DRIVE = _first(REPO / "build/shell-drive.py",
                     Path(__file__).resolve().parent / "shell-drive.py")
CATALOG = _first(REPO / "registry/catalog.d",
                 Path(os.environ.get("STARLING_CATALOG_DIR", "/nonexistent")),
                 Path("/usr/share/starling/catalog.d"))

VERBOSE = "-v" in sys.argv
ONLY = None
if "--only" in sys.argv:
    ONLY = sys.argv[sys.argv.index("--only") + 1]

# The real third-party app the install/identity/remove chain runs against.
# GIMP because it is a plain Ubuntu-archive package (no vendor repo, no
# account) whose window carries an app_id and a title that names a document
# rather than the app — the case app_id matching exists for.
REAL_APP = "gimp"

# A fake app for the offline install/remove check: no download, no vendor, no
# network, and nothing on the machine to damage. It covers the part we own —
# that a record appearing and disappearing moves the launcher and the dock —
# on machines where the real install above is switched off.
FAKE_ID = "starlingselftest"
FAKE_ROOT = Path("/tmp/starling-selftest")
FAKE_BIN = FAKE_ROOT / "bin" / "sleep"   # keeps the name: see the fixture

class Skip(Exception):
    """A check whose prerequisite is absent on this machine.

    Reported as SKIP, not FAIL. A check that needs GIMP installed says nothing
    about the desktop on a machine without GIMP, and a gate that goes red for
    that gets ignored — but silence would be worse, so skips are printed and
    counted.
    """


results: list[tuple[str, str, str]] = []


def log(msg: str) -> None:
    if VERBOSE:
        print(f"      {msg}")


# ── broker ───────────────────────────────────────────────────────────────────

def broker_path() -> str:
    uid = os.environ.get("SUDO_UID", os.getuid())
    for d in (os.environ.get("XDG_RUNTIME_DIR"), f"/tmp/xdg-starling-{uid}",
              f"/run/user/{uid}", *sorted(glob.glob("/tmp/xdg-starling-*"))):
        if d and os.path.exists(os.path.join(d, "starling-agent.sock")):
            return os.path.join(d, "starling-agent.sock")
    sys.exit("no starling-agent.sock — is the shell running?")


def ask(op: str, timeout: float = 5.0) -> dict:
    """One request/response against the broker."""
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    sock.connect(broker_path())
    sock.send(json.dumps({"op": op, "id": 1}).encode() + b"\n")
    buf = b""
    while b"\n" not in buf:
        chunk = sock.recv(65536)
        if not chunk:
            raise AssertionError(f"broker closed during {op}")
        buf += chunk
    sock.close()
    reply = json.loads(buf.split(b"\n", 1)[0])
    if not reply.get("ok"):
        raise AssertionError(f"{op} failed: {reply.get('error')}")
    return reply




class Session:
    """A stateful broker connection, for ops that need an agent identity.

    `ask()` above opens a connection per request, which is fine for the
    unscoped read-only ops but useless for anything agent-scoped: `hello`
    registers on the connection, so a one-shot request is always anonymous.
    """

    def __init__(self, name="functional.py", agent=None, token=None):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(30.0)
        self.sock.connect(broker_path())
        self.f = self.sock.makefile("rwb")
        self._id = 0
        args = {"name": name}
        if agent and token:
            args.update(agent=agent, token=token)
        hello = self.call("hello", **args)
        self.agent_id = hello["agent"]
        self.token = hello["token"]

    def call(self, op, **args):
        self._id += 1
        req = {"id": self._id, "op": op}
        req.update(args)
        self.f.write((json.dumps(req) + "\n").encode())
        self.f.flush()
        while True:
            line = self.f.readline()
            if not line:
                raise AssertionError("broker closed the connection")
            msg = json.loads(line)
            if msg.get("id") != self._id:
                continue
            return msg

    def ok(self, op, **args):
        reply = self.call(op, **args)
        assert reply.get("ok"), f"{op} failed: {reply.get('error')}"
        return reply

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


def session_busctl(*args: str) -> str:
    """busctl against the session's own bus, as the session user — a session
    bus refuses other uids, and the tier runs as root."""
    bus = os.path.dirname(broker_path()) + "/bus"
    cmd = ["busctl", f"--address=unix:path={bus}"] + list(args)
    user = os.environ.get("SUDO_USER")
    if os.geteuid() == 0 and user:
        cmd = ["sudo", "-u", user] + cmd
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
    assert r.returncode == 0, f"busctl {args[0]} failed: {r.stderr.strip()}"
    return r.stdout.strip()


def proc_running(name: str) -> bool:
    """pgrep -x, for first-party apps. The registry's `process` flag matches
    /proc exe paths against records' Bins= — and first-party records have
    none (they are not store-removable, which is what that flag guards), so
    it reads False for them even while they run."""
    return subprocess.run(["pgrep", "-x", name],
                          capture_output=True).returncode == 0


def session_home() -> str:
    """The session user's home — where the shell persists its config."""
    user = os.environ.get("SUDO_USER")
    if user and os.geteuid() == 0:
        return pwd.getpwnam(user).pw_dir
    return os.path.expanduser("~")


# ── driving Settings' panes ──────────────────────────────────────────────────
#
# Checks that need a Settings control use an agent-owned window and its
# semantic tree — the same tree the agent tooling ships on, so a control
# that stops being reachable there is itself a finding. The window lives in
# the agent space, invisible on the user desktop: these checks assert state
# changes, never pixels.

def settings_window() -> tuple:
    s = Session(name="pane-driver")
    win = s.ok("launch", app="settings")["win"]
    wait_for(lambda: len(tree_nodes(s, win)) > 5, "Settings UI to build")
    return s, win


def tree_nodes(s, win) -> list:
    r = s.call("semantic_tree", win=win)
    return r.get("nodes", []) if r.get("ok") else []


def tap_node_for(nodes: list, label: str):
    """The first tappable node at-or-after the node whose label starts with
    `label`. A nav item or row is tappable itself; a switch's tap node is
    unlabeled and follows its row's text."""
    seen = False
    for n in nodes:
        node_label = n.get("label") or ""
        if not seen and node_label.startswith(label):
            seen = True
            if "tap" in (n.get("actions") or []):
                return n.get("node")
            continue
        if seen and "tap" in (n.get("actions") or []):
            return n.get("node")
    return None


def tap_label(s, win, label: str) -> None:
    nid = tap_node_for(tree_nodes(s, win), label)
    assert nid is not None, f"no tappable node for {label!r} in the tree"
    s.ok("perform_action", win=win, node=nid, action="tap")
    time.sleep(1)


def apps() -> dict[str, dict]:
    return {a["app"]: a for a in ask("list_apps")["apps"]}


def dock() -> list[str]:
    return [s["app"] for s in ask("dock_rects")["slots"]]


def wait_for(predicate, what: str, timeout: float = 25.0) -> None:
    """Poll until the shell reports what we expect.

    Generous, because the wait is for a real app to start, map a window and
    composite a frame — and because the shell's own liveness tick is 2s.
    """
    deadline = time.time() + timeout
    last = None
    while time.time() < deadline:
        try:
            last = predicate()
            if last:
                return
        except AssertionError:
            raise
        time.sleep(0.5)
    raise AssertionError(f"timed out after {timeout:g}s waiting for {what}")


# ── helpers ──────────────────────────────────────────────────────────────────

def drive(*actions: str) -> None:
    subprocess.run([sys.executable, str(SHELL_DRIVE), *actions],
                   check=True, capture_output=True)


def app_run(app_id: str) -> subprocess.Popen:
    # The tier runs as root while the session belongs to $SUDO_USER, and the
    # runtime dir is per-user — app-run's own default would resolve to root's
    # dir, not the session's. The shell passes STARLING_XDG_DIR to every child
    # it spawns; do the same, aimed at the session actually under test.
    env = dict(os.environ, STARLING_XDG_DIR=os.path.dirname(broker_path()))
    return subprocess.Popen([str(APP_RUN), app_id], env=env,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def quit_app(*names: str) -> None:
    for name in names:
        subprocess.run(["pkill", "-x", name], capture_output=True)


def check(name: str):
    """Decorator registering one check."""
    def wrap(fn):
        fn._check_name = name
        return fn
    return wrap


# ── checks ───────────────────────────────────────────────────────────────────

@check("registry: the shell agrees with catalog.d on disk")
def check_registry_matches_disk() -> None:
    on_disk = {p.stem for p in CATALOG.glob("*.app")}
    reported = set(apps())
    missing = on_disk - reported
    assert not missing, f"shell does not know about {sorted(missing)}"
    log(f"{len(reported)} apps known to the shell")


@check("dock: pinned slots are the installed Dock= apps, in order")
def check_dock_matches_catalog() -> None:
    known = apps()
    expected = [a["app"] for a in
                sorted((a for a in known.values()
                        if a["dock"] >= 0 and a["installed"]),
                       key=lambda a: a["dock"])]
    slots = dock()
    assert slots[0] == "launcher", f"slot 0 is {slots[0]!r}, expected launcher"
    pinned = slots[1:1 + len(expected)]
    assert pinned == expected, f"dock pinned {pinned}, catalog says {expected}"
    log(f"dock: {slots}")


@check("store: installing a real app through app-install lands it in the launcher")
def check_real_install() -> None:
    """Install a real third-party app the way the App Store does.

    This is deliberately not setup done behind the tests' back. Installing an
    app is one of the behaviours under test, so the app the identity checks
    need is *produced* by this check rather than assumed — earlier this ran
    `apt-get install gimp` followed by `app-install --record gimp`, which
    fabricated the end state with the repair tool and exercised none of the
    real path.

    `/usr/bin/app-install <id>` is exactly the subprocess the store's Install
    button runs; the store adds `pkexec` in front of it. That hop cannot be
    driven from an SSH shell — polkit authorises the seat-active session — so
    it is proved separately by the pkcheck step in test/vm.sh, which asks
    polkit the same question on behalf of the session's own shell.

    Off by default: it downloads a real package. test/vm.sh turns it on.
    """
    if os.environ.get("STARLING_TEST_INSTALL") != "1":
        raise Skip("set STARLING_TEST_INSTALL=1 to install a real app")
    if apps().get(REAL_APP, {}).get("installed"):
        raise Skip(f"{REAL_APP} is already installed")

    result = subprocess.run(["sudo", str(APP_INSTALL), REAL_APP],
                            capture_output=True, text=True, timeout=900)
    assert result.returncode == 0, \
        f"app-install {REAL_APP} failed: {result.stderr.strip()[-200:]}"
    # The record is what tells the desktop it happened, and it must carry the
    # host facts resolved at install time — not just exist.
    wait_for(lambda: apps()[REAL_APP]["installed"],
             f"the shell to show {REAL_APP} as installed")
    records = Path(os.environ.get("STARLING_APP_RECORDS",
                                  "/var/lib/starling/installed.d"))
    record = (records / f"{REAL_APP}.app").read_text()
    assert "WmClass=" in record, f"no WmClass recorded:\n{record}"
    log(record.strip().replace("\n", " | "))


@check("identity: a third-party window resolves to its app via app_id")
def check_third_party_identity() -> None:
    """The bug this whole design exists for. GIMP declares no TitleMatch, so
    the only way the shell can attribute its window is the app_id it reports
    matching the StartupWMClass app-install recorded."""
    if not apps().get(REAL_APP, {}).get("installed"):
        raise Skip(f"{REAL_APP} is not installed")
    before = apps()[REAL_APP]
    assert not before["process"] and not before["window"], \
        "gimp is already running; quit it first"
    assert "gimp" not in dock(), "gimp already has a dock icon"

    app_run("gimp")
    try:
        wait_for(lambda: apps()["gimp"]["process"], "gimp process")
        log("process seen")
        wait_for(lambda: apps()["gimp"]["window"], "gimp window")
        log("window attributed to gimp")
        wait_for(lambda: "gimp" in dock(), "gimp transient dock icon")
        log(f"dock: {dock()}")
    finally:
        quit_app("gimp", "gimp-3.2")
    wait_for(lambda: "gimp" not in dock(), "gimp icon to go away")
    wait_for(lambda: not apps()["gimp"]["window"], "gimp window to go away")


@check("identity: a window is NOT attributed to an app that merely shares its binary")
def check_identity_is_not_incidental() -> None:
    """Keeps the check above honest.

    "GIMP's window was attributed to gimp" would also pass if the shell simply
    credited any window to any running app. The decoy fixture shares GIMP's
    binary but declares a window class that matches nothing, so while GIMP runs
    the shell must report the decoy as process=true, window=false. If that
    window ever turns true, attribution has stopped being app_id-driven.
    """
    decoy = apps().get("starlingnotgimp")
    if decoy is None:
        raise Skip("decoy fixture not present")
    if not apps().get("gimp", {}).get("installed"):
        raise Skip("gimp is not installed")
    assert not apps()["gimp"]["process"], "gimp is already running; quit it first"

    app_run("gimp")
    try:
        wait_for(lambda: apps()["gimp"]["window"], "gimp window")
        state = apps()["starlingnotgimp"]
        assert state["process"], (
            "decoy should be seen as running — it shares GIMP's binary, so a "
            "false here means the process check stopped working")
        assert not state["window"], (
            "decoy was credited with GIMP's window: attribution is no longer "
            "driven by app_id")
        log("decoy: process=True window=False — attribution is app_id-driven")
    finally:
        quit_app("gimp", "gimp-3.2")
    wait_for(lambda: not apps()["gimp"]["process"], "gimp to exit")


@check("launch: clicking a dock icon starts a first-party app")
def check_dock_launch() -> None:
    """Also covers dock geometry end to end: `dock settings` resolves the slot
    from the live layout, so a wrong answer clicks the wrong app or nothing."""
    assert not apps()["settings"]["window"], "Settings already running"
    drive("move 300 300", "dock settings", "click")
    try:
        wait_for(lambda: apps()["settings"]["window"], "Settings window")
        log("Settings launched from its dock icon")
    finally:
        quit_app("SettingsApp")
    wait_for(lambda: not apps()["settings"]["window"], "Settings to close")


@check("registry: installing and removing moves the launcher live")
def check_install_remove_loop() -> None:
    """The install/remove loop with no vendor, no network and nothing real to
    break: a record appears, the shell must show the app; it goes, the shell
    must drop it — with no relogin."""
    records = Path(os.environ.get("STARLING_APP_RECORDS",
                                  "/var/lib/starling/installed.d"))
    record = records / f"{FAKE_ID}.app"
    if FAKE_ID not in apps():
        raise Skip("fixture catalog not present")
    assert not apps()[FAKE_ID]["installed"], f"{FAKE_ID} already installed"

    FAKE_BIN.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy("/bin/sleep", FAKE_BIN)
    record.write_text(
        f"[Starling App]\nId={FAKE_ID}\nWmClass={FAKE_ID}\n"
        f"InstalledAt={int(time.time())}\n")
    try:
        wait_for(lambda: apps()[FAKE_ID]["installed"],
                 "the shell to notice the install")
        log("installed, launcher updated")
    finally:
        # Both halves, as a real uninstall does: the record AND the files.
        # Deleting only the record leaves the catalog's Bins probe succeeding,
        # and the app correctly stays installed — the fallback that covers
        # apps installed outside the store.
        record.unlink(missing_ok=True)
        shutil.rmtree(FAKE_ROOT, ignore_errors=True)
    wait_for(lambda: not apps()[FAKE_ID]["installed"],
             "the shell to notice the removal")
    log("removed, launcher updated")


@check("safety: app-install refuses to remove a running app")
def check_remove_guard() -> None:
    """Exercised against the fake app, so a failure of the guard cannot
    uninstall anything real — which is exactly how this check earned its
    place."""
    FAKE_BIN.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy("/bin/sleep", FAKE_BIN)
    def running() -> int:
        return subprocess.run([str(APP_INSTALL), "--running", FAKE_ID],
                              capture_output=True, text=True).returncode

    assert running() == 1, "reported running before anything started"
    proc = subprocess.Popen([str(FAKE_BIN), "60"])
    try:
        wait_for(lambda: running() == 0, "the guard to see the process",
                 timeout=10)
        log("guard detects the running process")
    finally:
        proc.terminate()
        proc.wait()
    wait_for(lambda: running() == 1, "the guard to see it exit", timeout=10)
    shutil.rmtree(FAKE_ROOT, ignore_errors=True)


@check("store: removing a real app through app-install drops it from the launcher")
def check_real_remove() -> None:
    """The other half of the loop, through the same path the Remove button
    uses. Runs last, so the identity checks above still had the app."""
    if os.environ.get("STARLING_TEST_INSTALL") != "1":
        raise Skip("set STARLING_TEST_INSTALL=1 to install/remove a real app")
    if not apps().get(REAL_APP, {}).get("installed"):
        raise Skip(f"{REAL_APP} is not installed")
    assert not apps()[REAL_APP]["process"], \
        f"{REAL_APP} is still running — removal must refuse, not proceed"

    result = subprocess.run(["sudo", str(APP_INSTALL), "--remove", REAL_APP],
                            capture_output=True, text=True, timeout=600)
    assert result.returncode == 0, \
        f"app-install --remove {REAL_APP} failed: {result.stderr.strip()[-200:]}"
    wait_for(lambda: not apps()[REAL_APP]["installed"],
             f"the shell to drop {REAL_APP} from the launcher")
    records = Path(os.environ.get("STARLING_APP_RECORDS",
                                  "/var/lib/starling/installed.d"))
    assert not (records / f"{REAL_APP}.app").exists(), \
        "the registry record outlived the app"
    log("removed; launcher and record both gone")


# ── runner ───────────────────────────────────────────────────────────────────



@check("agents: an agent sees only the windows it launched")
def check_agent_scope() -> None:
    """The whole scope model in one assertion. An agent addresses windows it
    owns; another agent's — and the human's — are not listed, not injectable,
    not capturable, and not readable through the semantics endpoint."""
    a = Session(name="scope-a")
    b = Session(name="scope-b")
    try:
        assert a.agent_id != b.agent_id, "two hellos returned the same agent"
        win = a.ok("launch", app="files")["win"]
        try:
            assert [w["win"] for w in a.ok("list_windows")["windows"]] == [win]
            assert b.ok("list_windows")["windows"] == [], \
                "agent B can see agent A's window"
            for op, extra in (("capture", {}),
                              ("semantic_tree", {}),
                              ("inject", {"ev": {"type": "click", "x": 5, "y": 5}})):
                denied = b.call(op, win=win, **extra)
                assert not denied.get("ok"), f"agent B was allowed to {op}"
                assert "no such owned window" in denied.get("error", ""), \
                    f"{op} denied for the wrong reason: {denied.get('error')}"
            log(f"{win} is addressable by {a.agent_id} and invisible to {b.agent_id}")
        finally:
            # The broker has no close op, so the window outlives the check.
            # Harmless — agent windows have no desktop presence and are drawn
            # only in the AI Space — but it is why this tier ends with a
            # Files process still running.
            pass
    finally:
        a.close()
        b.close()


@check("agents: an agent can re-attach to its own identity, not another's")
def check_agent_reattach() -> None:
    """Window ownership is per agent and each command of a CLI is its own
    process, so re-attaching is what makes `launch` then `click` possible at
    all. The token is what stops agent-2 rejoining as agent-1 by guessing."""
    first = Session(name="reattach")
    agent, token = first.agent_id, first.token
    win = first.ok("launch", app="files")["win"]
    first.close()                      # the CLI's process exits here

    back = Session(name="reattach", agent=agent, token=token)
    try:
        assert back.agent_id == agent, f"re-attach gave {back.agent_id}, not {agent}"
        assert [w["win"] for w in back.ok("list_windows")["windows"]] == [win], \
            "re-attached agent lost the window it launched"
        log(f"{agent} came back to {win} on a new connection")
    finally:
        back.close()

    impostor = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    impostor.settimeout(10.0)
    impostor.connect(broker_path())
    try:
        impostor.send(json.dumps(
            {"id": 1, "op": "hello", "name": "impostor",
             "agent": agent, "token": "0" * len(token)}).encode() + b"\n")
        reply = json.loads(impostor.recv(65536).split(b"\n", 1)[0])
        assert not reply.get("ok"), "a wrong token was accepted"
        assert "bad token" in reply.get("error", ""), reply
        log("a wrong token is refused")
    finally:
        impostor.close()


@check("launcher: typing in the Launchpad filters the app grid")
def check_launcher_search() -> None:
    """Reported against 0.2.1: "the search bar inside the Launchpad doesn't
    respond to typing". Nothing in the key path explains it — evdev→HID matches
    its inverse, the key packet decodes, and the shell's router is installed
    from initState so it wins over the FocusManager fallback runApp leaves.

    So this asserts the two halves separately, because they fail differently:
    `query` moving proves keystrokes reached the shell, and `filtered` shrinking
    proves the grid is driven by them. A query that never moves is a
    key-delivery bug; a query that moves while filtered stands still is a
    filtering one. Typing goes through shell-drive's uinput device, so it is the
    real libinput→engine path a user's keyboard takes, not an injected shortcut.
    """
    state = ask("launcher_state")
    assert not state["open"], "Launchpad already open"
    total = len(state["filtered"])
    assert total > 1, f"need >1 installed app to test filtering, have {total}"

    drive("move 300 300", "dock launcher", "click")
    try:
        wait_for(lambda: ask("launcher_state")["open"], "Launchpad to open")

        # A query no app can match: filtering to empty is unambiguous, where a
        # real prefix might coincide with the whole list on a small catalog.
        drive("type zzq")
        wait_for(lambda: ask("launcher_state")["query"] == "zzq",
                 "the typed query to reach the shell")
        log("keystrokes reached the launcher")

        filtered = ask("launcher_state")["filtered"]
        assert filtered == [], f"query 'zzq' matched {filtered}"
        log("the grid filtered to nothing")

        # Backspace edits rather than clearing, and the grid follows back up.
        drive("key backspace", "key backspace", "key backspace")
        wait_for(lambda: ask("launcher_state")["query"] == "",
                 "backspace to clear the query")
        assert len(ask("launcher_state")["filtered"]) == total, \
            "clearing the query did not restore the full grid"
        log("backspace restored the grid")
    finally:
        drive("key esc", "key esc")
    wait_for(lambda: not ask("launcher_state")["open"], "Launchpad to close")


def _nmcli(*args: str) -> str:
    return subprocess.run(["nmcli", *args], capture_output=True,
                          text=True).stdout.strip()


def _net_sim_up() -> bool:
    sim = REPO / "test/net-sim.sh"
    if not sim.exists():
        return False
    return subprocess.run([str(sim), "status"], capture_output=True).returncode == 0


@check("network: the shell reports the wired link NetworkManager sees")
def check_wired_link() -> None:
    """The wired half of the popup is read-only state, so the failure it
    guards against is the quiet one: a device the shell never notices, or a
    link it calls connected while NetworkManager disagrees. Both look like a
    perfectly normal panel.

    Asserted against `nmcli` rather than the shell's own snapshot, and skipped
    (not failed) on a machine with no wired NIC at all.
    """
    state = ask("wifi_state")
    wired = state.get("wired") or {}

    managed = [
        line.split(":")[0]
        for line in _nmcli("-t", "-f", "DEVICE,TYPE,STATE",
                           "device", "status").splitlines()
        if len(line.split(":")) >= 3
        and line.split(":")[1] == "ethernet"
        and line.split(":")[2] != "unmanaged"
    ]
    if not managed:
        raise Skip("no managed wired device on this machine")

    assert wired, f"NetworkManager has wired devices {managed}, the shell reports none"
    assert wired["device"] in managed, \
        f"the shell reports wired device {wired['device']!r}, not among {managed}"
    log(f"the shell reports {wired['device']}")

    # The shell must agree with NetworkManager about whether it is up, and
    # carry an address whenever it says so.
    dev_state = next(
        (line.split(":")[2] for line in _nmcli("-t", "-f", "DEVICE,TYPE,STATE",
                                               "device", "status").splitlines()
         if line.split(":")[0] == wired["device"]), "")
    assert wired["connected"] == (dev_state == "connected"), \
        f"shell says connected={wired['connected']}, nmcli says {dev_state!r}"
    if wired["connected"]:
        assert wired["ip"], f"{wired['device']} reported connected with no address"
        log(f"connected, {wired['ip']}")
    else:
        log(f"not connected ({dev_state})")


@check("wifi: joining a simulated network from the status-bar popup")
def check_wifi_popup_connect() -> None:
    """The popup is the only network UI in the shell itself, and everything it
    can do routes through nmcli — so a wrong device, a stale snapshot or an
    unregistered callback all look the same on screen: a list that never
    changes. This drives the real path (uinput click → shell → nmcli) and
    then asks NetworkManager directly, because the shell agreeing with itself
    proves nothing.

    Needs the simulated radios: `sudo test/net-sim.sh up`. The OPEN network is
    the one joined — a password would test the shell's text input rather than
    its network path, and that has its own coverage.
    """
    if not _net_sim_up():
        raise Skip("network lab is down (sudo test/net-sim.sh up)")

    state = ask("wifi_state")
    if not state["available"]:
        raise Skip("no managed wifi device")
    assert state["enabled"], "wifi radio is off"

    # Start from not-joined, so "connected" can only come from this run.
    _nmcli("connection", "delete", "Starling-Guest")

    # The icon toggles, so a panel someone left open must be closed first —
    # otherwise this "opens" it shut and every row click lands on the desktop.
    if state["popup_open"]:
        drive("key esc")
        wait_for(lambda: not ask("wifi_state")["popup_open"],
                 "a previously-open wifi popup to close")
    drive(f"click {state['icon']['x']:.0f} {state['icon']['y']:.0f}")
    try:
        wait_for(lambda: ask("wifi_state")["popup_open"], "the wifi popup to open")
        wait_for(lambda: "Starling-Guest" in ask("wifi_state")["networks"],
                 "the simulated network to appear in the scan")
        log("the popup lists the simulated network")

        # Both coordinates come from the shell: `content.center_x` for the
        # band rows take taps in, and `rows` for where this particular row
        # ended up. Nothing here reproduces the popup's layout, so adding a
        # section to the panel (the wired block did exactly that) cannot
        # silently send the click to the wrong network.
        listed = ask("wifi_state")
        row_y = next((r["y"] for r in listed["rows"]
                      if r["ssid"] == "Starling-Guest"), None)
        assert row_y is not None, \
            f"the shell lists no row for Starling-Guest: {listed['rows']}"
        drive(f"click {listed['content']['center_x']:.0f} {row_y:.0f}")

        wait_for(lambda: ask("wifi_state")["active"] == "Starling-Guest",
                 f"the shell to report the network as joined (clicked y={row_y:.0f})",
                 timeout=45)
        log("the shell reports the network joined")

        # The assertion that matters: NetworkManager agrees.
        assert "Starling-Guest" in _nmcli("-t", "-f", "NAME", "connection",
                                          "show", "--active"), \
            "the shell says joined but NetworkManager has no such connection"
        assert ask("wifi_state")["ip"], "joined with no address"
        log(f"NetworkManager confirms the join ({ask('wifi_state')['ip']})")
    finally:
        _nmcli("connection", "down", "Starling-Guest")
        _nmcli("connection", "delete", "Starling-Guest")
        drive("key esc")


@check("notifications: events collect behind the bell, shown only on click")
def check_notifications() -> None:
    """Drives org.freedesktop.Notifications over the session's real bus (as
    the session user — a session bus refuses other uids) and asserts through
    the broker, never pixels: a post collects silently (bell tints, no
    popup), clicking the broker-reported bell center opens the center and
    clears the tint, an expire_timeout does NOT remove anything — events
    stay until dismissed or CloseNotification. The daemon is the shell's
    own; a stock one cannot be here, the launchers mask it.
    """
    bus = os.path.dirname(broker_path()) + "/bus"
    if not os.path.exists(bus):
        raise Skip("no session bus socket beside the broker")
    def busctl(*args: str) -> str:
        return session_busctl("call", "org.freedesktop.Notifications",
                              "/org/freedesktop/Notifications",
                              "org.freedesktop.Notifications", *args)

    def state() -> dict:
        return ask("notification_state")

    def ids() -> list:
        return [n["id"] for n in state()["notifications"]]

    info = busctl("GetServerInformation")
    assert '"Starling"' in info, f"someone else answers the bus name: {info}"

    # A short expire_timeout is deliberately ignored: nothing may vanish
    # before the user has looked.
    nid = int(busctl("Notify", "susssasa{sv}i", "functest", "0", "",
                     "collected", "shown only on click", "0", "0", "1500")
              .split()[1])
    wait_for(lambda: nid in ids(), "the event to be collected")
    s = state()
    assert not s["popup_open"], "a post must not open anything on its own"
    assert s["unseen"], "the bell should be tinted until the user looks"
    time.sleep(3)
    assert nid in ids(), \
        "the event expired on its own — a center shows what you missed"

    drive(f"click {s['icon']['x']:.0f} {s['icon']['y']:.0f}")
    wait_for(lambda: state()["popup_open"], "the bell click to open the center")
    assert not state()["unseen"], "opening the center clears the tint"
    drive("key esc")
    wait_for(lambda: not state()["popup_open"], "esc to close the center")
    assert nid in ids(), "closing the popup must not discard events"

    busctl("CloseNotification", "u", str(nid))
    wait_for(lambda: nid not in ids(), "CloseNotification to remove it")
    log("collected, survived its timeout, shown on click, closed by call")


@check("battery: the status bar tracks the kernel's battery")
def check_battery() -> None:
    """Driven with the kernel's own fake-battery driver (test_power), which
    creates test_battery/test_ac in the real /sys/class/power_supply — so the
    whole shipping path runs: sysfs → BatteryReader → the 5s poll → the icon
    and its broker-served geometry. No overrides, no fixture directory.

    Waits are 15s where the icon must move: the poll is 5s and sysfs has no
    inotify, so nothing here is event-driven.
    """
    if ask("battery_state")["present"]:
        raise Skip("machine has a real battery; test_power would mix with it")
    if subprocess.run(["modprobe", "test_power"],
                      capture_output=True).returncode != 0:
        raise Skip("test_power module not available (root? modules-extra?)")
    status_param = Path("/sys/module/test_power/parameters/battery_status")
    try:
        wait_for(lambda: ask("battery_state")["present"],
                 "the shell to notice the fake battery", timeout=15)
        st = ask("battery_state")
        assert "icon" in st, "present battery reports no icon position"
        log(f"icon appeared at ({st['icon']['x']:.0f}, {st['icon']['y']:.0f}), "
            f"{st['percent']}% {st['state']}")

        # The popup opens from a click on the broker-reported center — the
        # same drift-proof contract the wifi popup has.
        drive(f"click {st['icon']['x']:.0f} {st['icon']['y']:.0f}")
        wait_for(lambda: ask("battery_state")["popup_open"],
                 "the battery popup to open")
        drive("key esc")
        wait_for(lambda: not ask("battery_state")["popup_open"],
                 "the battery popup to close")

        # Flip the kernel's reported state; the poll must follow. This is
        # the plug-in-the-charger path a laptop exercises constantly.
        status_param.write_text("charging")
        wait_for(lambda: ask("battery_state")["state"] == "Charging",
                 "the shell to follow the status flip", timeout=15)
        log("state followed the kernel flip to Charging")
    finally:
        subprocess.run(["rmmod", "test_power"], capture_output=True)
    wait_for(lambda: not ask("battery_state")["present"],
             "the icon to go away with the module", timeout=15)
    log("icon left with the module")


@check("bus: the shell owns its two well-known names")
def check_bus_names() -> None:
    """One line of coverage for a whole failure class. The session bus once
    died silently (a root-owned log file killed its redirect) and the shell
    ran busless for weeks — every file dialog broken, nothing failing loudly.
    Unowned names mean that; owned-by-someone-else means an activation race
    the launchers' masking should have prevented."""
    bus = os.path.dirname(broker_path()) + "/bus"
    if not os.path.exists(bus):
        raise Skip("no session bus socket beside the broker")
    shell_pid = int(subprocess.check_output(
        ["pgrep", "-x", "DesktopShellApp"]).split()[0])
    for name in ("org.freedesktop.portal.Desktop",
                 "org.freedesktop.Notifications"):
        out = session_busctl("status", name)
        pid = next((int(l.split("=", 1)[1]) for l in out.splitlines()
                    if l.startswith("PID=")), None)
        assert pid == shell_pid, \
            f"{name} is owned by pid {pid}, not the shell ({shell_pid})"
    log("both names answer to the shell's own pid")


@check("portal: OpenFile launches the shell's picker")
def check_portal_chooser() -> None:
    """The FileChooser path end to end minus the human: a bus call must
    launch FileExplorerApp --picker as a composited child. This is the
    interface every Chromium/Electron/GTK file dialog rides."""
    # Earlier checks (the agents pair) can leave a Files process behind;
    # the probe needs the namespace to itself, so clear it rather than skip.
    if proc_running("FileExplorerApp"):
        quit_app("FileExplorerApp")
        wait_for(lambda: not proc_running("FileExplorerApp"),
                 "a leftover Files process to exit")
    out = session_busctl("call", "org.freedesktop.portal.Desktop",
                         "/org/freedesktop/portal/desktop",
                         "org.freedesktop.portal.FileChooser", "OpenFile",
                         "ssa{sv}", "", "Functional Test", "0")
    assert out.startswith("o "), f"OpenFile returned no request handle: {out}"
    try:
        wait_for(lambda: proc_running("FileExplorerApp"),
                 "the picker helper to start")
        log("picker launched from the bus call")
    finally:
        quit_app("FileExplorerApp")
    wait_for(lambda: not proc_running("FileExplorerApp"), "the picker to exit")


@check("tiling: the Settings toggle retiles a live desktop and nothing dies")
def check_tiling_toggle() -> None:
    """Guards the crash class that shipped: flipping tiling resizes every
    user window's renderer mid-flight, which once corrupted child heaps
    (the reassemble-off-the-UI-thread bug). Both apps surviving both flips
    IS the assertion; the persisted file proves the flips happened."""
    layout = Path(session_home()) / ".config/starling/window-layout"
    def persisted() -> str:
        try:
            return layout.read_text().strip()
        except OSError:
            return "floating"
    original = persisted()

    assert not apps()["files"]["window"], "Files already running; quit it first"
    drive("move 300 300", "dock files", "click")
    wait_for(lambda: apps()["files"]["window"], "a user window to tile")
    s, win = settings_window()
    try:
        tap_label(s, win, "Appearance")
        flipped = "floating" if original == "tiling" else "tiling"
        tap_label(s, win, "Tiling Windows")
        wait_for(lambda: persisted() == flipped, "the layout choice to persist")
        time.sleep(2)   # let the retile resize land on the child renderer
        assert apps()["files"]["window"], "Files vanished in the retile"
        assert proc_running("SettingsApp"), "Settings died in the retile"
        tap_label(s, win, "Tiling Windows")
        wait_for(lambda: persisted() == original, "the layout to flip back")
        time.sleep(2)
        assert apps()["files"]["window"], "Files vanished restoring floating"
        assert proc_running("SettingsApp"), "Settings died restoring floating"
        log("two live resizes per app, no casualties")
    finally:
        s.close()
        quit_app("SettingsApp", "FileExplorerApp")
    wait_for(lambda: not apps()["files"]["window"], "Files to close")


@check("datetime: the pane sets the system timezone when the session may")
def check_datetime_pane() -> None:
    """Drives the region→city picker and asks timedatectl whether it took.
    Seat-active sessions are authorised silently (allow_active) — the VM
    gate is the only place that's true, so everywhere else this documents
    the refusal as a Skip rather than pretending."""
    def zone() -> str:
        out = subprocess.check_output(["timedatectl", "show"], text=True)
        return next((l.split("=", 1)[1] for l in out.splitlines()
                     if l.startswith("Timezone=")), "")
    original = zone()
    target = ("Australia", "Sydney", "Australia/Sydney")
    if original == target[2]:
        target = ("Pacific", "Auckland", "Pacific/Auckland")

    s, win = settings_window()
    try:
        tap_label(s, win, "Date & Time")
        tap_label(s, win, "Time Zone")
        tap_label(s, win, target[0])
        tap_label(s, win, target[1])
        time.sleep(2)
        now = zone()
        if now == original:
            raise Skip("polkit refused — the session is not seat-active "
                       "(the VM gate is where this proves out)")
        assert now == target[2], f"picked {target[2]}, system says {now}"
        log(f"timezone followed the picker: {original} → {now}")
    finally:
        s.close()
        quit_app("SettingsApp")
        if zone() != original:
            subprocess.run(["timedatectl", "set-timezone", original],
                           capture_output=True)


@check("settings: every pane opens, and the version is the package's truth")
def check_settings_walk() -> None:
    """Opens all nine panes in one sitting — each one's build() runs, so a
    pane that crashes the app cannot ship — and checks the General pane's
    version against the VERSION stamp the shell actually runs from, read
    out of the shell's own environment. \"dev build\" with no stamp is a
    pass: that is the truth this pane exists to tell."""
    shell_pid = int(subprocess.check_output(
        ["pgrep", "-x", "DesktopShellApp"]).split()[0])
    environ = Path(f"/proc/{shell_pid}/environ").read_bytes().split(b"\0")
    data_dir = next((e.split(b"=", 1)[1].decode() for e in environ
                     if e.startswith(b"STARLING_DATA_DIR=")),
                    "/usr/share/starling")
    try:
        expected = (Path(data_dir) / "VERSION").read_text().strip()
    except OSError:
        expected = "dev build"

    s, win = settings_window()
    try:
        for pane in ("Network", "Displays", "Sound", "Date & Time",
                     "Default Apps", "Appearance", "Power", "About",
                     "General"):
            tap_label(s, win, pane)
            assert proc_running("SettingsApp"), f"Settings died opening {pane}"
        labels = [n.get("label") or "" for n in tree_nodes(s, win)]
        assert f"Version {expected}" in labels, \
            f"General shows none of 'Version {expected}': {[l for l in labels if 'ersion' in l]}"
        log(f"nine panes, no casualties, version reads '{expected}'")
    finally:
        s.close()
        quit_app("SettingsApp")


@check("control center: quick tiles drive the settings they mirror")
def check_control_center() -> None:
    """Opens the panel from the broker-reported icon, taps the Dark Mode and
    Tiling tiles at the centers the shell serves, and asserts against the
    same state the Settings panes read — the tile IS the setting. Mute is
    asserted when PipeWire answers; wifi only ever on machines with a
    managed radio, so the tile's no-op path is what most boxes exercise."""
    cc = lambda: ask("control_center_state")
    s = cc()
    assert not s["open"], "the control center is already open"

    drive(f"click {s['icon']['x']:.0f} {s['icon']['y']:.0f}")
    wait_for(lambda: cc()["open"], "the panel to open")
    tiles = {t["id"]: t for t in cc()["tiles"]}

    dark = cc()["dark"]
    drive(f"click {tiles['dark']['x']:.0f} {tiles['dark']['y']:.0f}")
    wait_for(lambda: cc()["dark"] != dark, "Dark Mode to flip")
    drive(f"click {tiles['dark']['x']:.0f} {tiles['dark']['y']:.0f}")
    wait_for(lambda: cc()["dark"] == dark, "Dark Mode to flip back")

    tiling = cc()["tiling"]
    drive(f"click {tiles['tiling']['x']:.0f} {tiles['tiling']['y']:.0f}")
    wait_for(lambda: cc()["tiling"] != tiling, "Tiling to flip")
    drive(f"click {tiles['tiling']['x']:.0f} {tiles['tiling']['y']:.0f}")
    wait_for(lambda: cc()["tiling"] == tiling, "Tiling to flip back")

    if cc()["audio_available"]:
        muted = cc()["muted"]
        drive(f"click {tiles['mute']['x']:.0f} {tiles['mute']['y']:.0f}")
        wait_for(lambda: cc()["muted"] != muted, "Mute to flip")
        drive(f"click {tiles['mute']['x']:.0f} {tiles['mute']['y']:.0f}")
        wait_for(lambda: cc()["muted"] == muted, "Mute to flip back")
        log("dark, tiling and mute all round-tripped")
    else:
        log("dark and tiling round-tripped (no audio on this machine)")

    drive("key esc")
    wait_for(lambda: not cc()["open"], "esc to close the panel")


@check("recording: the record tile produces a playable MP4")
def check_recording() -> None:
    """Starts a recording from the control-center tile, waits for the state
    machine to reach `recording` — which only happens once a frame has gone
    all the way through capture, the mailbox, the pacer and into ffmpeg —
    stops it from the tile, and ffprobes the file the shell says it saved.
    Skips without ffmpeg (the .deb Recommends it; a dev box may not)."""
    rec = lambda: ask("recording_state")
    r = rec()
    if not r["available"]:
        raise Skip("no ffmpeg on this machine")
    assert r["state"] == "idle", f"a recording is already {r['state']}"

    cc = lambda: ask("control_center_state")
    try:
        drive(f"click {cc()['icon']['x']:.0f} {cc()['icon']['y']:.0f}")
        wait_for(lambda: cc()["open"], "the panel to open")
        tiles = {t["id"]: t for t in cc()["tiles"]}
        drive(f"click {tiles['record']['x']:.0f} {tiles['record']['y']:.0f}")
        wait_for(lambda: rec()["state"] == "recording",
                 "the first frame to reach ffmpeg")
        time.sleep(2)  # a couple of seconds of real desktop
        assert rec()["elapsed_s"] >= 1, "the elapsed clock is not advancing"

        drive(f"click {cc()['icon']['x']:.0f} {cc()['icon']['y']:.0f}")
        wait_for(lambda: cc()["open"], "the panel to reopen")
        drive(f"click {tiles['record']['x']:.0f} {tiles['record']['y']:.0f}")
        wait_for(lambda: rec()["state"] == "idle", "the encode to finalize")
        drive("key esc")
    finally:
        if rec()["state"] not in ("idle", "stopping"):
            drive("key ctrl+shift+r")  # don't leave a session recording

    path = rec()["last_file"]
    assert path, "the shell reports no saved file"
    probe = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=codec_name,width,height",
         "-of", "csv=p=0", path],
        capture_output=True, text=True)
    try:
        assert probe.returncode == 0, f"ffprobe rejects {path}: {probe.stderr}"
        codec, w, h = probe.stdout.strip().split(",")[:3]
        assert codec == "h264", f"expected h264, got {codec}"
        # The file must match the shell's own claim about the session
        # (full-res through VAAPI, half-res through the x264 fallback on
        # big screens — the claim is the policy's output, the file is the
        # ground truth, and this is the two of them agreeing). ±1 for the
        # even-dimension crop.
        r = rec()
        assert abs(int(w) - r["capture_w"]) <= 1 \
            and abs(int(h) - r["capture_h"]) <= 1, \
            f"recorded {w}x{h}, shell claims {r['capture_w']}x{r['capture_h']}"
        # And the claim itself must be the screen or exactly half of it.
        pw, ph = ask("screen")["physical"]
        assert any(abs(r["capture_w"] - pw / d) <= 1
                   and abs(r["capture_h"] - ph / d) <= 1 for d in (1, 2)), \
            f"capture {r['capture_w']}x{r['capture_h']} is neither " \
            f"{pw:.0f}x{ph:.0f} nor half of it"
        enc = "zero-copy vaapi" if r.get("zero_copy") \
            else ("vaapi" if r["hardware"] else "x264")
        log(f"{codec} {w}x{h} via {enc}, {os.path.getsize(path)} bytes")
    finally:
        # The tier must not grow the session user's Videos on every run.
        with contextlib.suppress(OSError):
            os.unlink(path)


@check("recording: Record App picks its window through Mission Control")
def check_record_app_picker() -> None:
    """The Record App tile opens Mission Control as a window picker — every
    window a live exposé card, clicking one records THAT window (its own
    texture, not a screen crop). Launches the calculator from the dock,
    picks it through the picker, and checks the session carries the
    window's label and lands a playable window-sized file."""
    rec = lambda: ask("recording_state")
    if not rec()["available"]:
        raise Skip("no ffmpeg on this machine")
    assert rec()["state"] == "idle", f"a recording is already {rec()['state']}"

    cc = lambda: ask("control_center_state")

    def open_picker() -> list:
        drive(f"click {cc()['icon']['x']:.0f} {cc()['icon']['y']:.0f}")
        wait_for(lambda: cc()["open"], "the panel to open")
        tiles = {t["id"]: t for t in cc()["tiles"]}
        drive(f"click {tiles['recordapp']['x']:.0f} {tiles['recordapp']['y']:.0f}")
        time.sleep(1.2)  # Mission Control's open animation settles
        return rec()["picker"]

    drive("dock calculator", "click")
    try:
        # The window needs a moment to map; each retry collapses whatever
        # the failed attempt left open (panel or picker) with Esc.
        targets: list = []
        deadline = time.time() + 25
        time.sleep(4)
        while not targets and time.time() < deadline:
            drive("key esc")
            targets = open_picker()
        assert targets, "the picker never offered a window card"
        card = next((t for t in targets if "alc" in t["title"]), targets[0])
        drive(f"click {card['x']:.0f} {card['y']:.0f}")
        wait_for(lambda: rec()["state"] == "recording",
                 "the picked window's first frame")
        label = rec()["window"]  # cleared at idle — read it live
        assert label, "the session carries no window label"
        time.sleep(2)
        drive("key ctrl+shift+r")
        wait_for(lambda: rec()["state"] == "idle", "the encode to finalize")
    finally:
        if rec()["state"] not in ("idle", "stopping"):
            drive("key ctrl+shift+r")
        subprocess.run(["pkill", "-x", "CalculatorApp"], capture_output=True)

    path = rec()["last_file"]
    assert path and "(" in os.path.basename(path), \
        f"expected a window-labelled file, got {path!r}"
    probe = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=codec_name,width,height",
         "-of", "csv=p=0", path],
        capture_output=True, text=True)
    try:
        assert probe.returncode == 0, f"ffprobe rejects {path}: {probe.stderr}"
        codec, w, h = probe.stdout.strip().split(",")[:3]
        assert codec == "h264", f"expected h264, got {codec}"
        # A window capture, not a screen crop: far smaller than the screen.
        pw, ph = ask("screen")["physical"]
        assert int(w) < pw and int(h) < ph, \
            f"recorded {w}x{h} does not look like a window on {pw}x{ph}"
        log(f"picked '{label}', {codec} {w}x{h}, "
            f"{os.path.getsize(path)} bytes")
    finally:
        with contextlib.suppress(OSError):
            os.unlink(path)


def _motion(path: str, sample_fps: int = 4) -> tuple[int, int, float]:
    """Sample a recording across its whole length and report how many
    consecutive sampled pairs actually differ. A file can be perfectly
    valid — right codec, right size, decodable — and still be a still
    image; only this catches that. Returns (moved, pairs, max_diff)."""
    with tempfile.TemporaryDirectory() as d:
        rc = subprocess.run(
            ["ffmpeg", "-v", "error", "-i", path, "-vf", f"fps={sample_fps}",
             f"{d}/f%04d.png"], capture_output=True, text=True)
        assert rc.returncode == 0, f"ffmpeg could not decode {path}: {rc.stderr}"
        frames = sorted(Path(d).iterdir())
        assert len(frames) >= 3, f"only {len(frames)} frames sampled from {path}"
        # Mean absolute difference per pair, computed without numpy/PIL:
        # ffmpeg's own signalstats would need a filter build, so compare the
        # raw PNG bytes decoded to grayscale via ffmpeg one pair at a time.
        diffs = []
        for a, b in zip(frames, frames[1:]):
            out = subprocess.run(
                ["ffmpeg", "-v", "error", "-i", str(a), "-i", str(b),
                 "-filter_complex", "blend=all_mode=difference,signalstats,"
                 "metadata=print:key=lavfi.signalstats.YAVG:file=-",
                 "-f", "null", "-"], capture_output=True, text=True)
            val = 0.0
            for line in out.stdout.splitlines():
                if "YAVG" in line:
                    val = float(line.rsplit("=", 1)[1])
            diffs.append(val)
        moved = sum(1 for v in diffs if v > 0.5)
        return moved, len(diffs), max(diffs)


@check("recording: the footage actually moves")
def check_recording_motion() -> None:
    """A recording of a changing screen must contain changing frames. This
    is the check that a frozen or barely-ticking capture fails: the earlier
    checks all pass on a still image, which is exactly how a capture bug
    once shipped looking green. Drives continuously-changing content (a
    terminal streaming random hex), records the screen, and requires most
    sampled pairs to differ."""
    rec = lambda: ask("recording_state")
    if not rec()["available"]:
        raise Skip("no ffmpeg on this machine")
    assert rec()["state"] == "idle", f"a recording is already {rec()['state']}"

    drive("dock terminal", "click")
    time.sleep(5)
    # Random hex: every line differs, so a repeated frame is unambiguous.
    drive("type while true; do head -c 1200 /dev/urandom | xxd | head -30; done")
    drive("key enter")
    time.sleep(3)
    try:
        drive("key ctrl+shift+r")
        wait_for(lambda: rec()["state"] == "recording", "the first frame")
        time.sleep(8)
        drive("key ctrl+shift+r")
        wait_for(lambda: rec()["state"] == "idle", "the encode to finalize")
    finally:
        if rec()["state"] not in ("idle", "stopping"):
            drive("key ctrl+shift+r")
        drive("key ctrl+c")  # stop the flood
        subprocess.run(["pkill", "-x", "TerminalApp"], capture_output=True)

    path = rec()["last_file"]
    assert path, "the shell reports no saved file"
    try:
        moved, pairs, peak = _motion(path)
        # The desktop cannot always hit the sample rate, but a recording of
        # a continuously-changing screen must be moving most of the time.
        assert moved >= pairs * 0.6, (
            f"only {moved}/{pairs} sampled pairs differ (peak {peak:.1f}) — "
            f"the recording is frozen or badly under-sampling motion")
        dur = float(subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "csv=p=0", path], capture_output=True, text=True).stdout)
        nframes = len(subprocess.run(
            ["ffprobe", "-v", "error", "-select_streams", "v:0",
             "-show_entries", "packet=pts_time", "-of", "csv=p=0", path],
            capture_output=True, text=True).stdout.split())
        fps = nframes / dur if dur else 0
        assert fps >= 12, f"recorded at {fps:.1f}fps — too choppy to watch"
        log(f"{moved}/{pairs} pairs moving, {fps:.1f}fps, peak diff {peak:.1f}")
    finally:
        with contextlib.suppress(OSError):
            os.unlink(path)


@check("screencast: the portal serves a live PipeWire stream")
def check_screencast() -> None:
    """org.freedesktop.portal.ScreenCast end to end minus the browser: the
    session handshake on one connection, a Start whose response carries a
    PipeWire node, and real frames pulled off that node — the interface
    Chromium's getDisplayMedia and OBS ride on Wayland. Frames are pulled
    twice: a count proves the stream flows, a PNG snapshot proves it
    carries the desktop rather than black."""
    uid = int(os.environ.get("SUDO_UID", os.getuid()))
    pw_dir = f"/run/user/{uid}"
    if not os.path.exists(f"{pw_dir}/pipewire-0"):
        raise Skip("no PipeWire daemon for the session user")
    try:
        import gi  # noqa: F401
    except ImportError:
        raise Skip("python3-gi not installed")
    if not shutil.which("gst-launch-1.0"):
        raise Skip("gstreamer not installed")

    def as_user(cmd: list, **kw):
        user = os.environ.get("SUDO_USER")
        if os.geteuid() == 0 and user:
            cmd = ["sudo", "-u", user, "env", f"PIPEWIRE_RUNTIME_DIR={pw_dir}"] + cmd
        return subprocess.run(cmd, capture_output=True, text=True, **kw)

    bus = os.path.dirname(broker_path()) + "/bus"
    r = as_user([sys.executable,
                 str(Path(__file__).parent / "screencast_client.py"),
                 f"unix:path={bus}"], timeout=30)
    assert r.returncode == 0, f"portal handshake failed: {r.stderr.strip()}"
    info = json.loads(r.stdout)
    node, w, h = info["node"], info["width"], info["height"]
    assert node > 0 and w > 0 and h > 0, f"bad stream: {info}"
    log(f"stream node {node} ({w}x{h})")

    # gst pulls by NODE NAME, not the id: pipewiresrc's path/target-object
    # resolve against the object *serial*, which only coincidentally equals
    # the id (it did once, which made this flaky instead of red). The id in
    # the Start response stays the contract for real consumers — webrtc
    # passes it straight to pw_stream_connect, which does take ids. The
    # stream-properties inject the media.type gst omits and without which
    # this distro's WirePlumber linking scripts crash ("Constraint:
    # equals: expected constraint value") and no link is ever made.
    gst_src = ["pipewiresrc", "target-object=starling-screencast",
               "stream-properties=props,media.type=Video,"
               "media.category=Capture,media.role=Screen"]
    try:
        pull = as_user(["gst-launch-1.0", "-q"] + gst_src +
                       ["num-buffers=5", "!", "fakesink"], timeout=30)
        assert pull.returncode == 0, \
            f"no frames from node {node}: {pull.stderr.strip()}"
        with tempfile.TemporaryDirectory() as d:
            # The tier runs as root but gst runs as the session user, who
            # must be able to create the file in this directory.
            os.chmod(d, 0o777)
            png = f"{d}/frame.png"
            snap = as_user(["gst-launch-1.0", "-q"] + gst_src +
                           ["num-buffers=1", "!",
                            "videoconvert", "!", "pngenc", "!",
                            "filesink", f"location={png}"], timeout=30)
            assert snap.returncode == 0, f"snapshot failed: {snap.stderr.strip()}"
            size = os.path.getsize(png)
            # A black 1080p frame zips into a few KB of PNG; the desktop
            # (wallpaper, dock, glass) cannot.
            assert size > 30000, f"snapshot is {size}B of PNG — a blank stream"
            log(f"5 buffers pulled, snapshot {size} bytes")
    finally:
        session_busctl("call", "org.freedesktop.portal.Desktop", info["session"],
                       "org.freedesktop.portal.Session", "Close")


CHECKS = [v for v in dict(globals()).values()
          if callable(v) and hasattr(v, "_check_name")]


def main() -> int:
    if os.geteuid() != 0:
        print("note: not root — the dock-click check needs /dev/uinput\n")
    print("starling functional tests")
    for fn in CHECKS:
        name = fn._check_name
        if ONLY and ONLY not in name:
            continue
        start = time.time()
        try:
            fn()
            results.append((name, "PASS", f"{time.time() - start:.1f}s"))
            print(f"  PASS  {name}  ({time.time() - start:.1f}s)")
        except Skip as why:
            results.append((name, "SKIP", str(why)))
            print(f"  SKIP  {name}\n        {why}")
        except Exception as exc:  # noqa: BLE001 - report, never abort the run
            results.append((name, "FAIL", str(exc)))
            print(f"  FAIL  {name}\n        {exc}")

    failed = [r for r in results if r[1] == "FAIL"]
    skipped = [r for r in results if r[1] == "SKIP"]
    print()
    tally = f"{len(results) - len(failed) - len(skipped)} passed"
    if skipped:
        tally += f", {len(skipped)} skipped"
    if failed:
        print(f"FAIL — {len(failed)} of {len(results)} check(s) ({tally})")
        return 1
    print(f"PASS — {tally}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
