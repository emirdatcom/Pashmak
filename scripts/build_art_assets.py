"""Slice AI-generated source sheets into per-asset PNGs under app/assets/art.

Usage: python scripts/build_art_assets.py <src_dir>
<src_dir> holds: background.webp, cat_sheet.webp, cat_body_green.webp, emoji_sheet_{1..4}.webp
"""
import json, os, shutil, sys
import numpy as np
import scipy.ndimage as ndi
from PIL import Image

SRC = sys.argv[1]
OUT = os.path.join(os.path.dirname(__file__), "..", "app", "assets", "art")
CANVAS, FIT = 384, 352

# (sheet, index) -> (folder, name). Anything not listed is a duplicate and is dropped.
EMOJI = {
 (1,1):("misc","flag_in_hole"),(1,2):("hygiene","soap"),(1,3):("home","mirror"),(1,4):("animals","chick"),
 (1,5):("clothing","jeans"),(1,6):("calm","candle"),(1,7):("misc","magnifier"),(1,8):("hygiene","bathtub"),
 (1,10):("hygiene","shower"),(1,11):("nav","shop"),(1,12):("nature","leafy_plant"),(1,13):("nature","pumpkin"),
 (1,14):("clothing","sweatpants"),(1,15):("clothing","dress"),(1,16):("animals","cat"),(1,17):("nature","mushroom"),
 (1,18):("nature","log"),(1,19):("nature","flower"),(1,20):("nature","herb_sprig"),(1,22):("nav","quests"),
 (1,23):("nav","home"),(1,24):("nav","friends"),(1,25):("nav","sparkles"),
 (2,3):("home","bed"),(2,4):("nature","landscape"),(2,5):("calm","dove_peace"),(2,6):("food","cutlery"),
 (2,7):("faces","relieved"),(2,8):("hearts","sparkling_heart"),(2,9):("hands","folded_hands"),
 (2,10):("connection","people_hugging"),(2,12):("hearts","orange_heart"),(2,13):("faces","smiling_blush"),
 (2,14):("body","lungs"),(2,15):("tech","smartphone"),(2,16):("connection","love_letter"),
 (2,17):("connection","teddy_bear"),(2,18):("connection","selfie"),(2,19):("connection","telephone"),
 (2,20):("faces","smiling_halo"),(2,21):("connection","speech_bubble"),(2,24):("misc","notepad_pencil"),
 (2,25):("tech","bell_off"),
 (3,3):("hobbies","soccer_ball"),(3,4):("faces","winking_tongue"),(3,5):("home","laundry_basket"),
 (3,7):("hands","waving_hand"),(3,9):("faces","hugging"),(3,11):("food","matcha"),(3,12):("food","croissant"),
 (3,13):("home","ladder"),(3,14):("nature","seedling"),(3,15):("animals","monkey"),(3,16):("misc","ticket"),
 (3,17):("misc","star"),(3,18):("tech","phone_off"),(3,19):("people","person_raising_hand"),
 (3,20):("food","frying_pan_egg"),(3,21):("hobbies","yarn_knitting"),(3,23):("connection","people_search"),
 (4,2):("misc","medal_first"),(4,3):("body","brain"),(4,5):("home","broom"),(4,10):("misc","gift"),
 (4,11):("body","sweat_droplets"),(4,12):("animals","lion"),(4,13):("clothing","shirt_tie"),
 (4,14):("clothing","socks"),(4,16):("hobbies","sewing_thread"),(4,17):("hobbies","paintbrush"),
 (4,19):("clothing","tshirt"),(4,23):("tech","keyboard"),(4,24):("hands","clapping_hands"),
 (4,25):("hygiene","lotion_pump"),
}

def boxes(a, dil):
    lab, _ = ndi.label(ndi.binary_dilation(a[..., 3] > 40, iterations=dil))
    return [(o[0].start, o[0].stop, o[1].start, o[1].stop) for o in ndi.find_objects(lab)]

def tight(im):
    bb = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    return im.crop(bb)

def save(im, path, canvas=None, fit=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if canvas:
        s = fit / max(im.size)
        im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
        c = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        c.alpha_composite(im, ((canvas - im.width) // 2, (canvas - im.height) // 2))
        im = c
    im.save(path, optimize=True)

# ---- emoji
manifest = []
for s in range(1, 5):
    im = Image.open(f"{SRC}/emoji_sheet_{s}.webp").convert("RGBA"); W = im.width
    bx = boxes(np.array(im), int(W * 0.012))
    bx.sort(key=lambda b: (round(((b[0] + b[1]) / 2) / (W / 5) - 0.5), (b[2] + b[3]) / 2))
    assert len(bx) == 25, (s, len(bx))
    for i, (y0, y1, x0, x1) in enumerate(bx, 1):
        if (s, i) not in EMOJI: continue
        folder, name = EMOJI[(s, i)]
        save(tight(im.crop((x0, y0, x1, y1))), f"{OUT}/emoji/{folder}/{name}.png", CANVAS, FIT)
        manifest.append({"id": f"{folder}/{name}", "path": f"assets/art/emoji/{folder}/{name}.png", "source": f"sheet{s}#{i}"})
manifest.sort(key=lambda m: m["id"])
json.dump(manifest, open(f"{OUT}/emoji/manifest.json", "w"), indent=2)
print("emoji:", len(manifest))

# ---- cat parts (screen-side naming: *_left = left on screen)
sheet = Image.open(f"{SRC}/cat_sheet.webp").convert("RGBA")
bx = boxes(np.array(sheet), 20)
assert len(bx) == 9, len(bx)
find = lambda f: [b for b in bx if f(b)]
cx = lambda b: (b[2] + b[3]) / 2; cy = lambda b: (b[0] + b[1]) / 2
rows = sorted(bx, key=cy)
parts = {}
body_old = min(find(lambda b: cx(b) < 700 and cy(b) < 800), key=cx)
head = find(lambda b: 700 < cx(b) < 1400 and cy(b) < 800)[0]
eyes = sorted(find(lambda b: cx(b) > 1400 and cy(b) < 800), key=cx)
arms = sorted(find(lambda b: 800 < cy(b) < 1300), key=cx)
legs = sorted(find(lambda b: cy(b) > 1300 and cx(b) < 1200), key=cx)
tail = find(lambda b: cy(b) > 1300 and cx(b) > 1400)[0]
crop = lambda b: sheet.crop((b[2], b[0], b[3], b[1]))
named = {"head": head, "eye_left": eyes[0], "eye_right": eyes[1], "arm_left": arms[0], "arm_right": arms[1],
         "leg_left": legs[0], "leg_right": legs[1], "tail": tail}
for n, b in named.items(): save(tight(crop(b)), f"{OUT}/cat/{n}.png")
# new body (green screen, no feet) rescaled to the old body's width so it matches the other parts
g = np.array(Image.open(f"{SRC}/cat_body_green.webp").convert("RGB")).astype(float)
r, gr, bl = g[..., 0], g[..., 1], g[..., 2]
spill = gr - np.maximum(r, bl)
alpha = ndi.grey_erosion(np.clip(1 - (spill - 30) / 90, 0, 1), size=3)  # 1px erode kills green fringe
g[..., 1] = np.minimum(gr, np.maximum(r, bl) + 10 * (1 - alpha))
body = Image.fromarray(np.dstack([g, alpha * 255]).astype("uint8"), "RGBA")
body = tight(body)
w_old = body_old[3] - body_old[2]
body = body.resize((w_old, round(body.height * w_old / body.width)), Image.LANCZOS)
save(body, f"{OUT}/cat/body.png")
print("cat parts:", len(named) + 1)

# ---- background
os.makedirs(f"{OUT}/background", exist_ok=True)
shutil.copy(f"{SRC}/background.webp", f"{OUT}/background/home_forest.webp")
