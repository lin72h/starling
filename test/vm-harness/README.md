# vm-harness — the VM the release gate runs on

A fresh **Ubuntu 26.04 (resolute)** VM with **GPU-accelerated** virtio-gpu (virgl on
the host GPU), used to verify that `starling-desktop_*.deb` installs and runs
through the normal GDM login. `test/vm.sh` drives everything here; the manual
equivalent of each of its steps is below.

## Scripts here, state in `$STARLING_VM`

The scripts are repo content. The VM **state** is not, and cannot be: the disk
images run to tens of gigabytes and the SSH key is a secret. It lives at
`$STARLING_VM` (default `~/starling-vm`), and every host-side script here
sources `vm-state.sh`, which resolves that directory and makes it the CWD — so
QEMU's relative `-drive`, `-serial`, `-pidfile` and `-qmp` paths land beside the
images, and the scripts can be run from anywhere.

| in `$STARLING_VM` (machine-local, not in git) | what it is |
|---|---|
| `disk2604.qcow2` | the .deb test VM — an overlay carrying the snapshots |
| `diskmin2604.qcow2` | the **minimal** VM (see dependency testing below) |
| `diskbuild2604.qcow2` | the build-from-scratch VM (`README-buildvm.md`) |
| `ubuntu-2604-server-cloudimg-amd64.img` | base image; the overlays name it as a **relative** backing file, so it must sit beside them |
| `seed2604.iso` | the cloud-init seed, built from `seed/` here |
| `id_starling{,.pub}` | throwaway SSH key for the guest |
| `serial*.log`, `qemu*.pid`, `qmp*.sock` | per-run output |

Host-side scripts here: `launch-*.sh` (boot a VM), `ssh-vm.sh` / `scp-vm.sh` /
`ssh-buildvm.sh` (reach it), `qmp-click.py` / `qmp-abs-click.py` (inject input
below the guest), `screendump.py` (host-side framebuffer grab), `rfb-grab.py`
(the same through VNC, i.e. what a console viewer sees).

Guest-side scripts, copied in and run there — they source nothing and need no
state: `g1-install.sh` `g2-setup-login.sh` `g3-check.sh` (the release gate's
three steps), `b1`–`b4` (the build VM), `gshot.py` (native Starling capture:
SIGUSR1 + a forced frame tick, the same protocol as `build/shell-drive.py shot`).

### Building a state directory from scratch

A fresh checkout has every script and none of the state. To make one:

```bash
mkdir -p ~/starling-vm && cd ~/starling-vm
curl -fLO https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img
mv resolute-server-cloudimg-amd64.img ubuntu-2604-server-cloudimg-amd64.img

# The guest trusts one key and the private half never leaves this machine, so a
# new state dir needs a new key AND the matching line in seed/user-data.
ssh-keygen -t ed25519 -N '' -C starling-vm -f id_starling
# replace the ssh_authorized_keys entry in <repo>/test/vm-harness/seed/user-data
# with the contents of id_starling.pub, then build the seed:
genisoimage -output seed2604.iso -volid cidata -joliet -rock \
    <repo>/test/vm-harness/seed/user-data <repo>/test/vm-harness/seed/meta-data

qemu-img create -f qcow2 -F qcow2 -b ubuntu-2604-server-cloudimg-amd64.img \
                disk2604.qcow2 28G
bash <repo>/test/vm-harness/launch-vm-2604.sh     # first boot runs cloud-init
```

That gives a booting guest. The `desktop-ready` snapshot the gate reverts to is
made by hand, once: install GDM (`g2-setup-login.sh` does exactly that work),
**`apt install seatd && systemctl enable --now seatd`**, power the VM off, then
`qemu-img snapshot -c desktop-ready disk2604.qcow2`.

seatd is not optional. Without it libseat falls back to the logind backend,
which refuses the uinput devices `shell-drive.py` creates for every keystroke
and click — the shell logs `libseat_open_device(...) failed`, loses that
keyboard for the rest of the session, and the suite fails wherever it types
into a client window. It presents as a recording of a motionless desktop, not
as an input error. The dev box has seatd because the shipping path wants it
(see the repo CLAUDE.md); the VM image needs it for the same reason.

## The VMs

- `launch-vm-2604.sh` — the gate's first pass. virtio-vga-gl + egl-headless on
  a **chosen** render node (amdgpu/i915/xe/radeon preferred over nouveau,
  `STARLING_VM_RENDERNODE` overrides), so the guest gets a virgl 3D GPU and
  QMP screendump
  reads back the accelerated scanout. SSH on 127.0.0.1:2222.
- `launch-vm-2604-nogl.sh` — the SAME disk with **no 3D acceleration** (plain
  `virtio-vga`), which is what GNOME Boxes, VirtualBox and VMware give a guest
  by default. The guest still gets `/dev/dri/renderD128`, but Mesa is llvmpipe
  via kms_swrast, so buffers come from `DRM_IOCTL_MODE_CREATE_DUMB` — which
  render nodes reject and the primary node allows. That difference broke every
  app in v0.2 while the shell itself ran fine. `test/vm.sh` boots this second,
  after the virgl pass, and requires the file.
- `launch-vm-2604-stdvga.sh` / `launch-stdvga-vnc.sh` — the same disk on QEMU's
  **std VGA** (bochs-drm): Proxmox's default, and a third display stack again —
  KMS primary node only, dumb buffers only, 16 MiB of VRAM. Starling 0.2.1 died
  on it before its first `[EGL]` line (issue #9) while both gated tiers passed.
  The `-vnc` variant serves 127.0.0.1:5, for `rfb-grab.py`.
- `launch-minvm-2604.sh` — the **minimal** VM: a fresh overlay straight on the
  base cloud image, so no GDM, no GNOME, no portal stack. This is the one for
  dependency testing (below).

`STARLING_VM_TABLET=1` adds a USB tablet — an **absolute** pointing device — to
the nogl and stdvga launchers. Only then can QEMU's `input-send-event` click a
given pixel: the default PS/2 mouse is relative, so injected deltas go through
pointer acceleration and land somewhere else entirely. `qmp-abs-click.py` needs
it; `qmp-click.py` is the relative-motion fallback that was proven against
GNOME. Off by default, so the release gate keeps the device set it was proved
on.

Only **one VM at a time** — every launcher binds 127.0.0.1:2222 except the
build VM, which uses 2223.

## Credentials

User `tester`, password `starling`, passwordless sudo, SSH key `id_starling`.
Throwaway credentials for a local-only guest: the launchers forward SSH from
127.0.0.1 only, and nothing else is exposed.

## Snapshots (offline; VM must be OFF to switch)

- `desktop-ready` — clean 26.04 + GDM, **no Starling**. Start here to test a new .deb.
- `starling-installed` — the working Starling desktop.

```bash
cd ~/starling-vm
qemu-img snapshot -l disk2604.qcow2                 # list
qemu-img snapshot -a desktop-ready  disk2604.qcow2  # revert to clean base
qemu-img snapshot -a starling-installed disk2604.qcow2
```

## Typical loop (test a freshly built .deb)

`test/vm.sh` does all of this and more. By hand, from this directory:

```bash
(cd ~/starling-vm && qemu-img snapshot -a desktop-ready disk2604.qcow2)
bash launch-vm-2604.sh                       # boots headless (background it)
./scp-vm.sh /tmp/starling-pkg/starling-desktop_0.1-1_amd64.deb '~/'
for g in g1-install.sh g2-setup-login.sh g3-check.sh; do ./scp-vm.sh $g '~/'; done
./ssh-vm.sh 'bash ~/g1-install.sh starling-desktop_0.1-1_amd64.deb'
./ssh-vm.sh 'bash ~/g2-setup-login.sh' && ./ssh-vm.sh 'sudo systemctl reboot'
# after it comes back:
./ssh-vm.sh 'bash ~/g3-check.sh'             # GDM -> launcher -> libseat + virgl
./scp-vm.sh gshot.py '~/' && ./ssh-vm.sh 'sudo python3 ~/gshot.py'
```

`screendump.py` is the host-side alternative to `gshot.py`, and works only for
the software-GL VM — it returns "no surface" on the virgl scanout.

## Testing whether the .deb's Depends are correct (use the MINIMAL VM)

`desktop-ready` is the wrong VM for this: it already has GDM, and GDM drags in
**542 packages** — including `xdg-desktop-portal`, which depends on
`bubblewrap`. Anything our package forgot to declare is likely present anyway,
so the test passes for the wrong reason. Start from the base cloud image
instead (679 packages, no GUI at all):

```bash
(cd ~/starling-vm && qemu-img create -f qcow2 -F qcow2 \
     -b ubuntu-2604-server-cloudimg-amd64.img diskmin2604.qcow2 20G)   # pristine
bash launch-minvm-2604.sh
./scp-vm.sh /tmp/starling-pkg/starling-desktop_0.1-1_amd64.deb '~/'
# --no-install-recommends => ONLY our Depends closure, nothing else
./ssh-vm.sh 'sudo apt-get install -y --no-install-recommends ./starling-desktop_0.1-1_amd64.deb'
# the actual verdict: does every shipped ELF resolve with just that closure?
./ssh-vm.sh 'for f in /usr/lib/starling/DesktopShellApp /usr/lib/starling/apps/[A-Z]* \
                      /usr/lib/starling/*.so; do ldd "$f" | grep "not found"; done'
```

Verified 2026-07-25: the closure is **26 packages** on top of minimal, and every
NEEDED lib resolves. Running the shell over SSH then fails at
`libseat_open_seat` — that is correct (no logind seat outside a DM session) and
proves the libraries are complete. Then `g2-setup-login.sh` + reboot for the
real GDM path.

`XRES`/`YRES` override the guest's preferred mode on the minimal VM, e.g. for
16:9 screenshots on a guest that otherwise comes up ultrawide:
`XRES=3840 YRES=2160 bash launch-minvm-2604.sh`.

## Start / stop

- Start: `bash launch-vm-2604.sh` (QEMU runs in the foreground — background it
  or use another terminal). SSH: `./ssh-vm.sh`.
- Stop: `./ssh-vm.sh 'sudo systemctl poweroff'`, or
  `kill $(cat ~/starling-vm/qemu2604.pid)` (`qemumin2604.pid` for the minimal
  VM). Note `pgrep -f qemu-system-x86_64` matches its own shell line — wait on
  the pidfile with `kill -0` instead.
