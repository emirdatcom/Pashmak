"""Build docs/visual-diff/NN-<screen>.png sheets: reference | our golden | overlay (mirrored reference at 50%).

The app is RTL and the reference is LTR, so the overlay uses a horizontally mirrored reference to line up layouts.
Reads input/reference/finch/NN.jpg and app/test/visual/goldens/NN-<name>.png; writes docs/visual-diff/.
usage: python3 tool/visual_compare/compose.py   (run from the repo root or app/)
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[3]
REF = ROOT / 'input/reference/finch'
GOLD = ROOT / 'app/test/visual/goldens'
OUT = ROOT / 'docs/visual-diff'
SIZE = (900, 2000)


def label(im, text):
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 220, 44), fill=(0, 0, 0))
    d.text((10, 14), text, fill=(255, 255, 255))
    return im


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for g in sorted(GOLD.glob('*.png')):
        n, name = g.stem.split('-', 1)
        ref_path = REF / f'{n}.jpg'
        if not ref_path.exists():
            continue
        ref = Image.open(ref_path).convert('RGB').resize(SIZE)
        ours = Image.open(g).convert('RGB').resize(SIZE)
        overlay = Image.blend(ImageOps.mirror(ref), ours, 0.5)
        sheet = Image.new('RGB', (SIZE[0] * 3 + 40, SIZE[1]), (30, 30, 30))
        for i, (im, t) in enumerate([(ref.copy(), 'reference'), (ours, 'ours'), (overlay, 'overlay (ref mirrored)')]):
            sheet.paste(label(im, t), (i * (SIZE[0] + 20), 0))
        sheet.save(OUT / f'{n}-{name}.png', optimize=True)
        print('wrote', OUT / f'{n}-{name}.png')


if __name__ == '__main__':
    main()
