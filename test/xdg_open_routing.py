#!/usr/bin/env python3
# The xdg-open shim's routing, against fixture records — no apps, no desktop.
#
# The shim resolves a URL's scheme through the registry (UrlSchemes= in
# catalog records, gated on installed-ness) with ~/.config/starling/
# default-apps picking among browsers. That logic lives in shell script, so
# it gets the same treatment the Swift layers get: fixtures in, routing out.
# The fallthrough to the host's /usr/bin/xdg-open is deliberately not
# exercised — it would launch real handlers on the test machine.

import os
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SHIM = REPO / "build" / "appbin" / "xdg-open"

failures = []


def check(name: str, got: str, want: str) -> None:
    if got == want:
        print(f"  ok    {name}")
    else:
        failures.append(name)
        print(f"  FAIL  {name}: got {got!r}, want {want!r}")


def record(path: Path, app_id: str, schemes: str) -> None:
    path.write_text(f"[Starling App]\nId={app_id}\nKind=host\n"
                    f"Exec={app_id}\nUrlSchemes={schemes}\n")


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        catalog = root / "catalog"
        records = root / "records"
        config = root / "config" / "starling"
        for d in (catalog, records, config):
            d.mkdir(parents=True)

        record(catalog / "browsera.app", "browsera", "http;https")
        record(catalog / "browserb.app", "browserb", "http;https")
        record(catalog / "chat.app", "chat", "chat")
        # browsera and chat are installed; browserb is not (yet).
        (records / "browsera.app").touch()
        (records / "chat.app").touch()

        out = root / "out"
        app_run = root / "app-run"
        app_run.write_text('#!/bin/sh\necho "$@" > "$CAPTURE"\n')
        app_run.chmod(0o755)

        def run(url: str) -> str:
            out.write_text("")
            env = dict(os.environ,
                       STARLING_APP_RUN=str(app_run),
                       CAPTURE=str(out),
                       STARLING_CATALOG_DIR=str(catalog),
                       STARLING_APP_RECORDS=str(records),
                       XDG_CONFIG_HOME=str(root / "config"))
            subprocess.run([str(SHIM), url], env=env,
                           capture_output=True, timeout=10)
            return out.read_text().strip()

        check("http routes to the first installed browser",
              run("http://example.com"), "browsera http://example.com")
        check("a deep-link scheme routes to its record's app",
              run("chat://join/x"), "chat chat://join/x")

        (config / "default-apps").write_text("browser=browserb\n")
        check("a configured browser that is NOT installed yields to the fallback",
              run("https://example.com"), "browsera https://example.com")

        (records / "browserb.app").touch()
        check("the configured browser wins once installed",
              run("https://example.com"), "browserb https://example.com")

        check("an unclaimed scheme is not routed to any app",
              run("dead-scheme-nothing-claims:x"), "")

    if failures:
        print(f"FAIL — {len(failures)} routing check(s)")
        return 1
    print("all routing checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
