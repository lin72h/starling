#!/usr/bin/env python3
"""Static checks for the Starling desktop — no build, no GPU, under a second.

    test/lint.py [-v]

This tier exists because of a specific failure mode: a fact about an app, or a
callback between C and Swift, that is declared in one place and silently not
honoured in another. Nothing crashes, nothing logs, and the symptom shows up
much later as "that one app is broken". Three instances of it have cost real
time so far (the wl_shm commit callback, the app_id callback, and a dock that
matched window titles because it never saw app_id).

So the checks here are all of one shape: two places that must agree, compared.
Nothing here needs a compositor, a GPU, or a build — run it on every change.
"""

import os
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CATALOG = REPO / "registry" / "catalog.d"

VERBOSE = "-v" in sys.argv

failures: list[tuple[str, str]] = []
notes: list[tuple[str, str]] = []


def fail(check: str, msg: str) -> None:
    failures.append((check, msg))


def note(check: str, msg: str) -> None:
    notes.append((check, msg))


def ok(msg: str) -> None:
    if VERBOSE:
        print(f"    ok  {msg}")


# ── key files ────────────────────────────────────────────────────────────────

def parse_keyfile(path: Path, group: str | None = None) -> dict[str, str]:
    """First-group-wins key file parse, matching KeyFile.swift."""
    out: dict[str, str] = {}
    current = None
    first = None
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
            continue
        if "=" not in line:
            continue
        if group is not None:
            if current != group:
                continue
        elif first is not None and current != first:
            continue
        if first is None:
            first = current
        key, value = line.split("=", 1)
        out.setdefault(key.strip(), value.strip())
    return out


def semicolon_list(value: str) -> list[str]:
    return [p.strip() for p in value.split(";") if p.strip()]


# ── shell-script recipe tables ───────────────────────────────────────────────

def case_blocks(path: Path, selector: str) -> dict[str, str]:
    """label -> body, for every `case <selector> in` block in a shell script.

    Bodies matter as well as labels: app-install.sh has branches that exist to
    *refuse* (firefox and chromium, which Starling deliberately does not
    offer), and those must not be mistaken for install recipes.
    """
    blocks: dict[str, str] = {}
    in_block = False
    current: list[str] = []
    labels: list[str] = []

    def flush() -> None:
        body = "\n".join(current)
        for label in labels:
            blocks[label] = blocks.get(label, "") + body

    for line in path.read_text().splitlines():
        stripped = line.strip()
        if re.match(rf'case\s+{re.escape(selector)}\s+in\b', stripped):
            in_block = True
            continue
        if not in_block:
            continue
        if stripped.startswith("esac"):
            flush()
            labels, current = [], []
            in_block = False
            continue
        m = re.match(r'^([A-Za-z0-9_|*.-]+)\)', stripped)
        if m:
            flush()
            labels = [a for a in m.group(1).split("|") if a and a != "*"]
            # A one-liner puts the whole recipe after the label on the same
            # line: `blender)   inst blender ;;`
            current = [stripped[m.end():]]
            continue
        current.append(line)
    flush()
    return blocks


def install_recipe_names(path: Path) -> set[str]:
    """Labels of app-install.sh that actually install something."""
    installs = ("inst ", "vendor_deb ", "vendor_repo ", "apt-get install",
                "tar -x", "fetch ")
    return {label for label, body in case_blocks(path, '"$NAME"').items()
            if any(token in body for token in installs)}


# ── check: the app catalog ───────────────────────────────────────────────────

def swift_case_strings(path: Path, func_signature: str) -> set[str]:
    """String literals of `case "x":` inside one Swift function — used to read
    a vocabulary out of the code that owns it, instead of restating it here."""
    text = path.read_text()
    start = text.find(func_signature)
    if start < 0:
        return set()
    # Crude but adequate: stop at the function's closing brace column.
    body = text[start:]
    end = body.find("\n    }")
    if end > 0:
        body = body[:end]
    return set(re.findall(r'case\s+"([^"]+)"', body))


def check_catalog() -> None:
    check = "catalog"
    records = sorted(CATALOG.glob("*.app"))
    if not records:
        fail(check, f"no catalog records found in {CATALOG}")
        return

    # Vocabularies read from the code that defines them, so adding a glyph in
    # the shell does not make this lint wrong.
    glyphs = swift_case_strings(
        REPO / "shell/Sources/DesktopShellApp/Shell/DesktopShell.swift",
        "static func iconType(named name: String) -> IconType {")
    glyphs |= swift_case_strings(
        REPO / "apps/AppStoreApp/Sources/AppStoreApp/AppStoreApp.swift",
        "private func iconKind(_ glyph: String) -> StoreIconKind {")
    # The painter's fallback: every record that wants no special shape.
    glyphs.add("externalApp")
    if not glyphs:
        fail(check, "could not read the glyph vocabulary out of the Swift sources")

    kinds = {"first-party", "host", "android", "x11"}
    install_recipes = install_recipe_names(REPO / "build/app-install.sh")
    run_recipes = set(case_blocks(REPO / "build/app-run.sh", '"$NAME"'))

    seen_order: dict[int, str] = {}
    seen_dock: dict[int, str] = {}
    catalog_installs: set[str] = set()

    for path in records:
        rid = path.stem
        kf = parse_keyfile(path, group="Starling App")
        if not kf:
            fail(check, f"{path.name}: no [Starling App] group / unparseable")
            continue

        if kf.get("Id", rid) != rid:
            fail(check, f"{path.name}: Id={kf.get('Id')!r} does not match filename")
        if not kf.get("Name"):
            fail(check, f"{path.name}: missing Name")

        kind = kf.get("Kind", "host")
        if kind not in kinds:
            fail(check, f"{path.name}: Kind={kind!r} not one of {sorted(kinds)}")

        glyph = kf.get("Glyph", "externalApp")
        if glyph not in glyphs:
            fail(check, f"{path.name}: Glyph={glyph!r} is drawn by nothing "
                        f"(known: {', '.join(sorted(glyphs))})")

        colour = kf.get("Color", "")
        if colour and not re.fullmatch(r"[0-9A-Fa-f]{6}", colour):
            fail(check, f"{path.name}: Color={colour!r} is not RRGGBB")

        for key, table in (("Order", seen_order), ("Dock", seen_dock)):
            if key not in kf:
                continue
            try:
                value = int(kf[key])
            except ValueError:
                fail(check, f"{path.name}: {key}={kf[key]!r} is not an integer")
                continue
            if value in table:
                fail(check, f"{path.name}: {key}={value} collides with {table[value]}")
            table[value] = path.name

        for binary in semicolon_list(kf.get("Bins", "")):
            if not binary.startswith("/"):
                fail(check, f"{path.name}: Bins entry {binary!r} is not absolute")

        # An app the store can install must be installable and detectable.
        recipe = kf.get("Install")
        if recipe:
            catalog_installs.add(recipe)
            if recipe not in install_recipes:
                fail(check, f"{path.name}: Install={recipe!r} has no recipe in "
                            "build/app-install.sh")
            if kind == "host" and not kf.get("Bins"):
                fail(check, f"{path.name}: installable host app declares no Bins, "
                            "so nothing can tell whether it is installed")

        exec_name = kf.get("Exec", rid)
        if kind == "host" and exec_name not in run_recipes:
            fail(check, f"{path.name}: Exec={exec_name!r} has no recipe in "
                        "build/app-run.sh — the launcher would do nothing")
        if kind == "first-party":
            if not (REPO / "apps" / exec_name).is_dir():
                fail(check, f"{path.name}: Exec={exec_name!r} is not a package "
                            "under apps/")
            window = kf.get("Window", "")
            if len(semicolon_list(window.replace(",", ";"))) != 4:
                fail(check, f"{path.name}: first-party app needs Window=x,y,w,h "
                            f"(got {window!r})")

        # RenameWindows can only fire through one of these.
        if kf.get("RenameWindows") == "1" and not (kf.get("TitleMatch")
                                                   or kf.get("WmClass")):
            fail(check, f"{path.name}: RenameWindows=1 but nothing identifies "
                        "its windows (needs TitleMatch or WmClass)")
        ok(f"{path.name}")

    # The reverse direction: a recipe nothing in the desktop offers. This is
    # how mpv/vlc/libreoffice/obs became installable-but-invisible.
    unlisted = set()
    m = re.search(r'^UNLISTED="([^"]*)"',
                  (REPO / "build/app-install.sh").read_text(), re.M)
    if m:
        unlisted = set(m.group(1).split())
    orphans = install_recipes - catalog_installs - unlisted
    if orphans:
        fail(check, "app-install recipes with no catalog record and not listed "
                    f"in UNLISTED: {', '.join(sorted(orphans))}")
    stale = unlisted & catalog_installs
    if stale:
        fail(check, "apps in app-install's UNLISTED that do have a catalog "
                    f"record: {', '.join(sorted(stale))}")

    print(f"  catalog: {len(records)} records checked")


# ── check: C callbacks the Swift side must register ──────────────────────────

# Declared and fired, but deliberately not registered. Each entry needs a
# reason; a bare name is not enough, because the whole point of this check is
# that an unregistered callback is invisible.
KNOWN_UNREGISTERED = {
    "wayland_server_on_toplevel_resize_request":
        "xdg_toplevel set_max_size and set_min_size both fire this ONE callback "
        "with no way to tell which, so registering it as-is would apply a "
        "minimum as a maximum. Client size constraints are ignored until the C "
        "side splits it in two.",
}


def check_wayland_callbacks() -> None:
    """Every `wayland_server_on_*` the compositor declares must be registered
    by the Swift side.

    This is the check that would have caught the wl_shm bug (every software
    client composited as nothing) and the app_id bug (no dock icon for any
    third-party app). In both cases the C was complete — declared, defined,
    called — and the Swift setter was simply never written. There is no
    warning, no crash, and no log line for that.
    """
    check = "wayland-callbacks"
    header = REPO / "shell/Sources/WaylandServer/include/wayland_server.h"
    declared = set(re.findall(r"\bwayland_server_on_(\w+)\s*\(", header.read_text()))
    if not declared:
        fail(check, f"no wayland_server_on_* declarations found in {header}")
        return

    swift = " ".join(p.read_text() for p in
                     (REPO / "shell/Sources/DesktopShellApp").rglob("*.swift"))
    for name in sorted(declared):
        full = f"wayland_server_on_{name}"
        if full in swift:
            ok(full)
        elif full in KNOWN_UNREGISTERED:
            note(check, f"{full} is declared and fired but not registered — "
                        f"{KNOWN_UNREGISTERED[full]}")
        else:
            fail(check, f"{full} is declared in wayland_server.h but never "
                        "registered in Swift: the compositor will fire it into "
                        "a NULL pointer and drop whatever it carries, silently")
    gaps = KNOWN_UNREGISTERED.keys() & {f"wayland_server_on_{n}" for n in declared}
    print(f"  wayland callbacks: {len(declared)} declared, {len(gaps)} known gap(s)")


# ── check: the scripts parse ─────────────────────────────────────────────────

def check_script_syntax() -> None:
    check = "syntax"
    count = 0
    for script in sorted((REPO / "build").glob("*.sh")):
        # Check each script with the shell it actually declares: run-desktop.sh
        # and wechat-run.sh are bash and use arrays, which `sh -n` (dash)
        # rejects for syntax it simply does not have.
        shebang = script.read_text().split("\n", 1)[0]
        shell = "bash" if "bash" in shebang else "sh"
        result = subprocess.run([shell, "-n", str(script)],
                                capture_output=True, text=True)
        if result.returncode != 0:
            fail(check, f"{script.name}: {result.stderr.strip()}")
        else:
            ok(script.name)
        count += 1
    for script in sorted((REPO / "build").glob("*.py")) + \
                  sorted((REPO / "test").glob("*.py")):
        result = subprocess.run([sys.executable, "-m", "py_compile", str(script)],
                                capture_output=True, text=True)
        if result.returncode != 0:
            fail(check, f"{script.name}: {result.stderr.strip()}")
        else:
            ok(script.name)
        count += 1
    print(f"  syntax: {count} scripts")


# ── main ─────────────────────────────────────────────────────────────────────

def main() -> int:
    print("starling lint")
    check_catalog()
    check_wayland_callbacks()
    check_script_syntax()

    for check, msg in notes:
        print(f"\n  note [{check}] {msg}")
    if failures:
        print(f"\n{len(failures)} failure(s):")
        for check, msg in failures:
            print(f"  FAIL [{check}] {msg}")
        return 1
    print("\nall checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
