#!/usr/bin/env bash
# Boot the fresh Ubuntu 26.04 (resolute) test VM with GPU-accelerated virtio-gpu:
#   virtio-vga-gl  -> guest gets a virgl 3D-capable GPU
#   egl-headless   -> QEMU renders virgl on the host GPU (renderD128), no window
# QMP screendump reads back the accelerated scanout. SSH on 127.0.0.1:2222.
set -euo pipefail
. "$(dirname "$0")/vm-state.sh"
cd "$VM"
qemu-system-x86_64 \
  -enable-kvm -cpu host -m 8192 -smp 4 \
  -drive file=disk2604.qcow2,if=virtio,format=qcow2 \
  -drive file=seed2604.iso,if=virtio,format=raw,readonly=on \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -device virtio-vga-gl \
  -display egl-headless,rendernode=/dev/dri/renderD128 \
  -serial file:serial2604.log \
  -qmp unix:qmp.sock,server=on,wait=off \
  -pidfile qemu2604.pid
