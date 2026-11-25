#!/usr/bin/env python3
"""Dev-only tool: convert COLLADA (.dae) models, which Godot 4.5 cannot import, to .glb.

Needs `pip install trimesh pycollada numpy` (NOT a game dependency; the game ships only the .glb).
Geometry and UVs only: the game assigns its own painterly stone material, so source textures are dropped.
Usage: python3 -I tools/art/convert_dae.py <out_dir> <model.dae> [more.dae ...]
Output is Y-up, metres, named after the input file (lower case)."""
import os, sys
import numpy as np
import trimesh


def convert(src: str, out_dir: str) -> str:
    scene = trimesh.load(src, force="scene")
    meshes = []
    for name in scene.graph.nodes_geometry:
        tf, gname = scene.graph[name]
        m = scene.geometry[gname].copy()
        m.apply_transform(tf)
        uv = getattr(m.visual, "uv", None)
        m.visual = trimesh.visual.TextureVisuals(uv=uv) if uv is not None else trimesh.visual.ColorVisuals()
        meshes.append(m)
    if not meshes:
        raise RuntimeError("no geometry in " + src)
    merged = trimesh.util.concatenate(meshes)
    with open(src, "r", errors="ignore") as f:
        z_up = "<up_axis>Z_UP" in f.read(4000)
    if z_up:  # glTF is Y-up: (x, y, z) -> (x, z, -y)
        merged.apply_transform(trimesh.transformations.rotation_matrix(-np.pi / 2, [1, 0, 0]))
    out = os.path.join(out_dir, os.path.splitext(os.path.basename(src))[0].lower() + ".glb")
    merged.export(out)
    b = merged.bounds
    print("%s: %d tris, size %s" % (os.path.basename(out), len(merged.faces), np.round(b[1] - b[0], 2)))
    return out


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    os.makedirs(sys.argv[1], exist_ok=True)
    for f in sys.argv[2:]:
        try:
            convert(f, sys.argv[1])
        except Exception as e:  # keep going: report which models failed
            print("FAILED %s: %s" % (f, e))
