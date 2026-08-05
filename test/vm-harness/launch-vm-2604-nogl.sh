#!/usr/bin/env bash
# Boot the 26.04 test VM with NO 3D acceleration — plain virtio-vga (2D only),
# which is what GNOME Boxes / VirtualBox / VMware give a guest by default.
#
# Why this tier exists: without VIRTIO_GPU_F_VIRGL the guest kernel exposes NO
# render node (/dev/dri/renderD*), only the KMS primary node. The shell can
# still run (it gets card0 from libseat and renders through kms_swrast), but
# anything that assumes a render node cannot. The GPU-accelerated
# launch-vm-2604.sh cannot see that class of bug.
#
# STARLING_VM_TABLET=1 adds a USB tablet, i.e. an ABSOLUTE pointing device.
# Only then can QEMU's `input-send-event` click a given pixel: the default
# PS/2 mouse is relative, so injected deltas go through libinput's pointer
# acceleration and land somewhere else entirely. Needed to drive a GNOME
# session, which has no XTEST and no scriptable synthetic input of its own.
# Off by default so the release gate keeps the device set it was proved on.
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
  -device virtio-vga \
  "${TABLET[@]}" \
  -display none \
  -serial file:serial2604-nogl.log \
  -qmp unix:qmp.sock,server=on,wait=off \
  -pidfile qemu2604.pid
