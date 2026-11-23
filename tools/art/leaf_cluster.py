# Offline art tool (not part of the game build). Needs Python 3 with Pillow, SciPy and NumPy.
# Usage: python3 tools/art/leaf_cluster.py <dir with extracted ambientCG LeafSet024 + LeafSet022 1K-PNG zips> project/assets/textures/cc0/leaf_spray.png
# Builds a leaf-spray sprite (RGBA) from CC0 ambientCG leaf atlases (LeafSet024, LeafSet022).
import sys, random, math
from PIL import Image
from scipy import ndimage
import numpy as np
src = sys.argv[1]; out = sys.argv[2]
random.seed(7)
leaves = []
for sid in ["LeafSet024", "LeafSet022"]:
    col = Image.open(f"{src}/{sid}/{sid}_1K-PNG_Color.png").convert("RGB")
    op = np.array(Image.open(f"{src}/{sid}/{sid}_1K-PNG_Opacity.png").convert("L"))
    lab, n = ndimage.label(op > 40)
    for sl in ndimage.find_objects(lab):
        h = sl[0].stop - sl[0].start; w = sl[1].stop - sl[1].start
        if h * w < 4000: continue
        box = (sl[1].start, sl[0].start, sl[1].stop, sl[0].stop)
        c = col.crop(box); a = Image.fromarray(op).crop(box)
        rgba = c.copy(); rgba.putalpha(a)
        leaves.append(rgba)
print("leaves", len(leaves))
N = 512
canvas = Image.new("RGBA", (N, N), (0, 0, 0, 0))
# Leaves radiate from twigs along a few curved stems; leaf tips point outward.
cx, cy = N / 2, N * 0.5
for i in range(120):
    ang = random.uniform(0, math.tau)
    r = (random.random() ** 0.7) * 0.38 * N
    x = cx + math.cos(ang) * r; y = cy + math.sin(ang) * r
    leaf = random.choice(leaves)
    s = random.uniform(0.11, 0.17) * N / max(leaf.size)
    lf = leaf.resize((max(1, int(leaf.size[0] * s)), max(1, int(leaf.size[1] * s))), Image.LANCZOS)
    # Atlas leaves point up (stem at bottom); rotate so the tip points away from the centre.
    lf = lf.rotate(-math.degrees(ang) - 90 + random.uniform(-25, 25), expand=True, resample=Image.BICUBIC)
    shade = random.uniform(0.55, 1.0) * (0.7 + 0.3 * (r / (0.38 * N)))  # inner leaves darker
    rgb = Image.eval(lf.convert("RGB"), lambda v: int(v * shade)); rgb.putalpha(lf.getchannel("A"))
    canvas.alpha_composite(rgb, (int(x - rgb.size[0] / 2), int(y - rgb.size[1] / 2)))
# Fade the alpha at the canvas border so cards never show a hard square edge.
a = np.array(canvas.getchannel("A")).astype(float)
yy, xx = np.mgrid[0:N, 0:N]
edge = np.clip(np.minimum.reduce([xx, yy, N - 1 - xx, N - 1 - yy]) / 12.0, 0, 1)
canvas.putalpha(Image.fromarray((a * edge).astype("uint8")))
# Bleed colour into transparent pixels (avoids dark fringes when mipmapped).
rgb = np.array(canvas.convert("RGB")).astype(float); m = np.array(canvas.getchannel("A")) > 8
avg = rgb[m].mean(axis=0)
rgb[~m] = avg
img = Image.fromarray(rgb.astype("uint8")); img.putalpha(canvas.getchannel("A"))
img.save(out)
print("saved", out, "coverage %.2f" % m.mean())
