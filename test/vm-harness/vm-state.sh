#!/usr/bin/env bash
# Sourced by every HOST-side script in this directory. It answers one question,
# in one place: where does the VM *state* live?
#
# The scripts here are repo content. The state is not, and cannot be: the disk
# images are multiple gigabytes (72 GB across the four VMs), the SSH key is a
# secret, and the serial logs, pidfiles and QMP sockets are per-run. All of it
# stays at $STARLING_VM (default ~/starling-vm), which is also the CWD every
# host-side script runs in — QEMU's relative `-drive`, `-serial`, `-pidfile`
# and `-qmp` paths then land there, which is how these scripts were written and
# why they still read the way they did before the split.
#
# Guest-side scripts (g1-g3, b1-b4, gshot.py) do NOT source this: they are
# copied into the VM and run there, where none of it exists.
VM="${STARLING_VM:-$HOME/starling-vm}"
[ -d "$VM" ] || {
    echo "no VM state directory at $VM" >&2
    echo "  the disk images live outside the repo — set STARLING_VM, or see" >&2
    echo "  test/vm-harness/README.md for how to build one from scratch." >&2
    exit 1
}
