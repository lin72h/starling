#!/usr/bin/env bash
# Boot the fresh Ubuntu 26.04 (resolute) test VM with GPU-accelerated virtio-gpu:
#   virtio-vga-gl  -> guest gets a virgl 3D-capable GPU
#   egl-headless   -> QEMU renders virgl on a host GPU, no window
# QMP screendump reads back the accelerated scanout. SSH on 127.0.0.1:2222.
#
# The render node is CHOSEN, not assumed. renderD128 is simply "the first
# render node", which on a one-GPU machine is the GPU — but on a laptop with
# switchable graphics it is whichever card enumerated first, and that can be
# the one nobody drives the display with. On the 14ARP8 dev box renderD128 is
# the NVIDIA card on nouveau while the AMD iGPU (renderD129) drives the panel
# and does the real work; pointing virgl at nouveau there gave a guest whose
# shell drew but whose CLIENT apps failed to start or render, which surfaced
# as recordings of a motionless desktop and cost a long night's debugging.
# Prefer amdgpu/i915/radeon over nouveau, and let STARLING_VM_RENDERNODE win.
set -euo pipefail
. "$(dirname "$0")/vm-state.sh"
cd "$VM"

pick_rendernode() {
    if [ -n "${STARLING_VM_RENDERNODE:-}" ]; then
        echo "$STARLING_VM_RENDERNODE"; return
    fi
    local fallback=""
    for n in /dev/dri/renderD*; do
        [ -e "$n" ] || continue
        local drv
        drv=$(sed -n 's/^DRIVER=//p' \
              "/sys/class/drm/$(basename "$n")/device/uevent" 2>/dev/null)
        case "$drv" in
            amdgpu|i915|xe|radeon) echo "$n"; return ;;
            *) [ -z "$fallback" ] && fallback="$n" ;;
        esac
    done
    echo "${fallback:-/dev/dri/renderD128}"
}
RENDERNODE=$(pick_rendernode)
echo "launch-vm-2604: virgl on $RENDERNODE" >&2
qemu-system-x86_64 \
  -enable-kvm -cpu host -m 8192 -smp 4 \
  -drive file=disk2604.qcow2,if=virtio,format=qcow2 \
  -drive file=seed2604.iso,if=virtio,format=raw,readonly=on \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -device virtio-vga-gl \
  -display egl-headless,rendernode="$RENDERNODE" \
  -serial file:serial2604.log \
  -qmp unix:qmp.sock,server=on,wait=off \
  -pidfile qemu2604.pid
