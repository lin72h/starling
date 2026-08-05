#!/usr/bin/env bash
# Boot the MINIMAL Ubuntu 26.04 test VM — a fresh overlay on the base cloud
# image, i.e. no GDM, no GNOME, no portal stack. This is the VM to use when
# testing whether the .deb's Depends are actually complete: the desktop-ready
# snapshot in disk2604.qcow2 already has the GNOME stack, which masks missing
# dependencies (that is how bubblewrap/xdg-desktop-portal appeared "present").
#
# Same GPU setup as launch-vm-2604.sh (virgl on the host GPU, egl-headless) and
# the same SSH port, so ssh-vm.sh / scp-vm.sh work unchanged — but only ONE of
# the two VMs may run at a time (both take 127.0.0.1:2222).
#
# Recreate a pristine disk any time with:
#   qemu-img create -f qcow2 -F qcow2 -b ubuntu-2604-server-cloudimg-amd64.img \
#                   diskmin2604.qcow2 20G
#
# XRES/YRES override the guest's preferred mode, e.g. for capturing 16:9
# screenshots on a VM that otherwise comes up ultrawide:
#   XRES=3840 YRES=2160 bash launch-minvm-2604.sh
set -euo pipefail
. "$(dirname "$0")/vm-state.sh"
cd "$VM"
VGA_OPTS=""
if [ -n "${XRES:-}" ] && [ -n "${YRES:-}" ]; then
    VGA_OPTS=",xres=$XRES,yres=$YRES"
fi
qemu-system-x86_64 \
  -enable-kvm -cpu host -m 8192 -smp 4 \
  -drive file=diskmin2604.qcow2,if=virtio,format=qcow2 \
  -drive file=seed2604.iso,if=virtio,format=raw,readonly=on \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -device "virtio-vga-gl$VGA_OPTS" \
  -display egl-headless,rendernode=/dev/dri/renderD128 \
  -serial file:serialmin2604.log \
  -qmp unix:qmpmin.sock,server=on,wait=off \
  -pidfile qemumin2604.pid
