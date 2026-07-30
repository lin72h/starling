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

import json
import os
import shutil
import socket
import subprocess
import sys
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
    for d in (os.environ.get("XDG_RUNTIME_DIR"), "/tmp/xdg-starling",
              f"/run/user/{os.environ.get('SUDO_UID', os.getuid())}"):
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
    return subprocess.Popen([str(APP_RUN), app_id],
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
