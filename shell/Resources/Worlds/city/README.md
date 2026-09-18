# The 3D desktop's city

The world the Filament renderer walks you into when the 3D desktop is
on: a Minecraft-style city round a square, with a clock tower, a pool
where the dock's apps stand as bricks, and your windows on an arc round
it. Everything here is **generated**, not authored: `build/tools/
voxel-world.py` writes the glTF (`room.glb`), the block atlas and the
frame tile, `world.json` (where the square, the pool, the clock and the
camera's home are), and — through Filament's `cmgen` — the sky's two
KTX files. Regenerate with

    python3 build/tools/voxel-world.py --no-sky     # ~10 s, keeps the sky

and commit what it writes; `--no-sky` skips `cmgen`, which is only on a
box with a Filament build. The sky is procedural (a gradient and a sun),
so nothing here is anyone else's.

`build/stage.sh` installs this directory as `share/starling/worlds/city`,
and the shell chooses the Filament renderer whenever that world and
`libstarling_room.so` are both beside it (`STARLING_ROOM=gl` forces the
shell's own GL room; `STARLING_ROOM_DIR` points at a world elsewhere).
