# The 3D desktop's room

`room.mesh` and the two atlases beside it are **baked**, not authored
here: `build/tools/room-fetch.py` downloads the furniture and
`build/tools/room-import.py` turns it, the room's own geometry and the
light into the three files. Neither tool runs on a user's machine and
neither is a build dependency — change the room by re-running the
importer and committing what it writes.

The **sky** is Poly Haven's `meadow_2` HDRI. It does two jobs: it is the
view out of the windows, and it is the room's light — the importer takes
its sun's direction and colour, and projects the rest of it onto nine
spherical-harmonic coefficients that reproduce how that sky lights a
surface facing any direction. So the weather outside and the light
inside are the same weather.

The furniture is from [Poly Haven](https://polyhaven.com), whose library
is CC0: usable for any purpose including commercial, with no attribution
required (checked 2026-09-17). Credited here anyway, because they earned
it. The room's shell, its windows and all of its lighting are ours.

Assets used: Sofa_01, ArmChair_01, modern_coffee_table_02, side_table_01,
ClassicConsole_01, ceramic_vase_02, brass_vase_01, potted_plant_04,
modern_ceiling_lamp_01. Sky: meadow_2.
