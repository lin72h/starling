#!/usr/bin/env bash
# Guest step 1: dependencies + depot_tools + engine source + gclient sync.
# Run inside the fresh 26.04 VM as `tester`.
set -euxo pipefail
cd "$HOME"

# --- 1. Host packages the engine checkout needs (upstream's documented set) ---
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git curl unzip python3 pkg-config

# --- 2. depot_tools (gclient, ninja, vpython3) ------------------------------
[ -d "$HOME/depot_tools" ] || \
    git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git "$HOME/depot_tools"
export PATH="$HOME/depot_tools:$PATH"
export DEPOT_TOOLS_UPDATE=1

# --- 3. The engine repo -----------------------------------------------------
# (upstream: git clone https://github.com/starling-build/starling-engine.git;
#  here it comes from a bundle because the repo is private)
[ -d "$HOME/dev/starling-build/starling-engine" ] || {
    mkdir -p "$HOME/dev/starling-build"
    git clone "$HOME/starling-engine.bundle" "$HOME/dev/starling-build/starling-engine"
}
cd "$HOME/dev/starling-build/starling-engine"

# --- 4. .gclient — upstream's standard.gclient, pointed at this repo --------
sed 's#https://github.com/flutter/flutter.git#https://github.com/starling-build/starling-engine.git#' \
    engine/scripts/standard.gclient > .gclient
cat .gclient

# --- 5. Hydrate DEPS --------------------------------------------------------
time gclient sync -D
du -sh engine/src
