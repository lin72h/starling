#!/usr/bin/env bash
# Boot the 26.04 test VM with QEMU's STD VGA (-device VGA, PCI 1234:1111,
# guest driver bochs-drm) — the default display of Proxmox ("vga: std") and
# of plain qemu-system invocations.
#
# Why this third tier exists: bochs is a different display stack from BOTH
# tiers the release gate covers. virtio-vga (even without virgl) still gives
# the guest a virtio-gpu driver and a render node; bochs-drm exposes only the
# KMS primary node, supports only dumb buffers, and carries a small dedicated
# VRAM (16 MiB here and on Proxmox's default) that the mode list is derived
# from. Starling 0.2.1 on this adapter died before its first [EGL] log line —
# a blank screen at GDM login, reported from a Proxmox guest in issue #9 —
# while both tested tiers were fine.
#
# STARLING_VM_TABLET=1 adds a USB tablet (absolute pointer) as in the other
# launch scripts.
set -euo pipefail
. "$(dirname "$0")/vm-state.sh"
cd "$VM"
TABLET=()
[ "${STARLING_VM_TABLET:-}" = "1" ] && TABLET=(-usb -device usb-tablet)
qemu-system-x86_64 \
  -enable-kvm -cpu host -m 8192 -smp 4 \
  -drive file=disk2604.qcow2,if=virtio,format=qcow2 \
  -drive file=seed2604.iso,if=virtio,format=raw,readonly=on \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -device VGA \
  "${TABLET[@]}" \
  -display none -vnc 127.0.0.1:5 \
  -serial file:serial2604-stdvga.log \
  -qmp unix:qmp.sock,server=on,wait=off \
  -pidfile qemu2604.pid
