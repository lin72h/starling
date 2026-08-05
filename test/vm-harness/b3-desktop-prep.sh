#!/usr/bin/env bash
# Guest step 3a: Swift toolchain + build dependencies + the desktop source.
set -euxo pipefail
cd "$HOME"

# --- Swift 6.2.4 runtime/build prerequisites (swift.org's Ubuntu list) ------
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential binutils libc6-dev libcurl4-openssl-dev libedit2 \
    libncurses-dev libpython3-dev libsqlite3-0 libxml2-dev libz3-dev \
    pkg-config tzdata unzip zlib1g-dev

# --- what the shell/apps compile and link against ---------------------------
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libwayland-dev libxkbcommon-dev libdrm-dev libgbm-dev libegl-dev \
    libgles-dev libinput-dev libudev-dev libsystemd-dev libxshmfence-dev \
    libx11-dev libxcb1-dev libpixman-1-dev

# --- Swift 6.2.4 --------------------------------------------------------------
# Package.swift hardcodes ~/.local/share/swiftly/toolchains/6.2.4/usr/include,
# so the toolchain must land at exactly that path. swift.org has no ubuntu26.04
# build of 6.2.4 — the ubuntu24.04 one is what we use.
TC="$HOME/.local/share/swiftly/toolchains/6.2.4"
if [ ! -x "$TC/usr/bin/swift" ]; then
    mkdir -p "$TC"
    curl -fL -o /tmp/swift.tar.gz \
      https://download.swift.org/swift-6.2.4-release/ubuntu2404/swift-6.2.4-RELEASE/swift-6.2.4-RELEASE-ubuntu24.04.tar.gz
    tar -xzf /tmp/swift.tar.gz -C "$TC" --strip-components=1
    rm -f /tmp/swift.tar.gz
fi
export PATH="$TC/usr/bin:$PATH"
swift --version

# --- the desktop repo -------------------------------------------------------
# (upstream: git clone https://github.com/starling-build/starling-desktop.git)
[ -d "$HOME/dev/starling-build/starling-desktop" ] || \
    git clone "$HOME/starling-desktop.bundle" "$HOME/dev/starling-build/starling-desktop"
cd "$HOME/dev/starling-build/starling-desktop"
./bootstrap.sh
ls -la engine
