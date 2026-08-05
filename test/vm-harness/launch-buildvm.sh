#!/usr/bin/env bash
# Boot the "build from scratch" VM: fresh Ubuntu 26.04 (resolute), 200G disk,
# 12 vCPU / 16G RAM — sized for a full Flutter-engine checkout (~30G) + build.
# Separate disk/ports from the .deb test VM (launch-vm-2604.sh) so both can run.
#   SSH: 127.0.0.1:2223   QMP: qmpbuild.sock   serial: serialbuild.log
set -euo pipefail
. "$(dirname "$0")/vm-state.sh"
cd "$VM"
qemu-system-x86_64 \
  -enable-kvm -cpu host -m 16384 -smp 12 \
  -drive file=diskbuild2604.qcow2,if=virtio,format=qcow2 \
  -drive file=seed2604.iso,if=virtio,format=raw,readonly=on \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2223-:22 \
  -device virtio-net-pci,netdev=net0 \
  -device virtio-vga-gl \
  -display egl-headless,rendernode=/dev/dri/renderD128 \
  -serial file:serialbuild.log \
  -qmp unix:qmpbuild.sock,server=on,wait=off \
  -pidfile qemubuild.pid
