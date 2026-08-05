# build VM — compiling both repos from scratch

Second VM driven from this directory, separate from the `.deb` test VM
(`disk2604.qcow2`, `launch-vm-2604.sh`). This one exists to build
**starling-engine + starling-desktop from source** on a machine with no
toolchain, which is how `starling-desktop/docs/BUILDING.md` was written and
verified (2026-07-25). Nothing gates on it — it is a documentation check.

Sized for it: 200 GB disk, 12 vCPU, 16 GB RAM. A full run needs ~41 GB
(29 GB of that is the engine's gclient checkout) and ~55 min.

## Files
Same split as the rest of the harness (see `README.md`): the scripts are here,
the disk and the SSH key are in `$STARLING_VM` (default `~/starling-vm`).

- `diskbuild2604.qcow2` — the disk, in `$STARLING_VM` (overlay on
  `ubuntu-2604-server-cloudimg-amd64.img`). 200 GB and not reproducible from
  the repo; recreate with `qemu-img create -f qcow2 -F qcow2 -b <base> \
  diskbuild2604.qcow2 200G`.
- `launch-buildvm.sh` — boot it. SSH on **2223**, QMP `qmpbuild.sock`, serial `serialbuild.log`.
- `ssh-buildvm.sh` — SSH in (user `tester`, key `id_starling`).
- `b1-engine-sync.sh` `b2-engine-build.sh` `b3-desktop-prep.sh` `b4-desktop-build.sh`
  — the guest-side steps, in order: DEPS sync → gn+ninja → Swift toolchain +
  deps + clone → swift build + stage. They are the executable form of
  docs/BUILDING.md, including the 26.04 workarounds.
- `gshot.py` — native screenshot inside the guest (shared with the other VM).

## Snapshot (VM must be OFF to switch)
- `built-from-scratch` — everything built: 29 GB engine checkout, both engine
  configs, the shell + 5 apps, `.stage/`, and a working `.deb`.

```bash
qemu-img snapshot -l diskbuild2604.qcow2
qemu-img snapshot -a built-from-scratch diskbuild2604.qcow2
```

## Typical loop
```bash
bash launch-buildvm.sh &            # ~30 s to SSH
./ssh-buildvm.sh 'bash ~/b1-engine-sync.sh'      # 25 min
./ssh-buildvm.sh 'bash ~/b2-engine-build.sh'     # 15 min
./ssh-buildvm.sh 'bash ~/b3-desktop-prep.sh'
./ssh-buildvm.sh 'bash ~/b4-desktop-build.sh'    # 11 min
# run it (nothing else holds the GPU on this image):
./ssh-buildvm.sh 'cd ~/dev/starling-build/starling-desktop && sudo build/run-desktop.sh --no-stage' &
./ssh-buildvm.sh 'sudo python3 ~/gshot.py'       # -> /root/starling-shot.ppm
```

The guest clones both private repos over SSH with the `starling-build-dev`
deploy key at `~/.ssh/id_ed25519` (copied from the host's
`~/.ssh/id_ed25519_starling`).

## Gotcha
`pgrep -f b4-desktop-build` run over SSH matches its own `bash -c` line and
always reports "running" — use `pgrep -f "[b]4-desktop-build"`.
