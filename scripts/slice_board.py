"""Cut a generated art board into separate transparent PNGs (384x384, object centred, ~92% of the frame).

Usage: python scripts/slice_board.py <board.png> <name> [<name> ...]
Names are read in board order (left to right, top to bottom) and resolved under app/assets/art/:
  items/hat_cap        -> app/assets/art/items/hat_cap.png
  emoji/misc/catalog   -> app/assets/art/emoji/misc/catalog.png
  glyph:cat_top        -> app/assets/art/emoji/glyph/cat_top.png, recoloured to pure white (tinted in the app)
A board with a flat background (no transparency) has the background colour, as sampled at the corners, removed.
"""
import os, sys
import numpy as np
import scipy.ndimage as ndi
from PIL import Image

ART = os.path.join(os.path.dirname(__file__), '..', 'app', 'assets', 'art')
CANVAS, FIT = 384, 352


def alpha_of(a):
    if a[..., 3].min() < 250:  # already transparent
        return a[..., 3]
    corners = np.array([a[2, 2, :3], a[2, -3, :3], a[-3, 2, :3], a[-3, -3, :3]], dtype=float).mean(0)
    near = np.abs(a[..., :3].astype(float) - corners).sum(-1) < 60
    lab, _ = ndi.label(near)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    return np.where(bg, 0, 255).astype(np.uint8)


def main():
    src, names = sys.argv[1], sys.argv[2:]
    a = np.array(Image.open(src).convert('RGBA'))
    a[..., 3] = alpha_of(a)
    mask = a[..., 3] > 40
    lab, n = ndi.label(ndi.binary_dilation(mask, iterations=6))
    objs = ndi.find_objects(lab)
    sizes = ndi.sum(mask, lab, range(1, n + 1))
    big = [i for i in range(n) if sizes[i] > max(sizes) * 0.04]
    # row-major: a new row starts when an object's centre is lower than half a typical height below the row's first
    cy = {i: (objs[i][0].start + objs[i][0].stop) / 2 for i in big}
    h = float(np.median([objs[i][0].stop - objs[i][0].start for i in big]))
    ordered, row = [], []
    for i in sorted(big, key=lambda j: cy[j]):
        if row and cy[i] - cy[row[0]] > h * 0.5:
            ordered += sorted(row, key=lambda j: objs[j][1].start)
            row = []
        row.append(i)
    ordered += sorted(row, key=lambda j: objs[j][1].start)
    if len(ordered) != len(names):
        sys.exit(f'found {len(ordered)} objects on the board but got {len(names)} names')
    for i, name in zip(ordered, names):
        sl = objs[i]
        crop = a[sl].copy()
        crop[..., 3] = np.where(lab[sl] == i + 1, crop[..., 3], 0)
        im = Image.fromarray(crop)
        im = im.crop(im.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox())
        glyph = name.startswith('glyph:')
        if glyph:
            name = 'emoji/glyph/' + name[len('glyph:'):]
            white = Image.new('RGBA', im.size, (255, 255, 255, 255))
            white.putalpha(im.getchannel('A'))
            im = white
        s = FIT / max(im.size)
        im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
        out = Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 0))
        out.alpha_composite(im, ((CANVAS - im.width) // 2, (CANVAS - im.height) // 2))
        path = os.path.join(ART, name + '.png')
        os.makedirs(os.path.dirname(path), exist_ok=True)
        out.save(path, optimize=True)
        print('wrote', os.path.relpath(path))


if __name__ == '__main__':
    main()
