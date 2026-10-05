"""Print the dominant colours of each reference screenshot with exact (bucket-median) values.
Internal reference only; nothing is copied into app/.   usage: python3 sample_colors.py [ref_dir]
"""
import statistics
import sys
from collections import defaultdict
from pathlib import Path

from PIL import Image

ref = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[3] / 'input/reference/finch')


def dominant(path, n=5):
    im = Image.open(path).convert('RGB').resize((270, 600))
    px = list(im.get_flattened_data() if hasattr(im, 'get_flattened_data') else im.getdata())
    buckets = defaultdict(list)
    for r, g, b in px:
        buckets[(r // 8, g // 8, b // 8)].append((r, g, b))
    out = []
    for vals in sorted(buckets.values(), key=len, reverse=True)[:n]:
        m = tuple(int(statistics.median(v[i] for v in vals)) for i in range(3))
        out.append(('#%02X%02X%02X' % m, len(vals) * 100 / len(px)))
    return out


if __name__ == '__main__':
    for p in sorted(ref.glob('*.jpg')):
        print(p.name, ', '.join('%s %.0f%%' % c for c in dominant(p)))
