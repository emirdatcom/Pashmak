# پرامپت‌های آرت: صفحه‌ی مأموریت‌ها و سؤال روزانه

کد این تصاویر را از این مسیرها می‌خواند. تا وقتی فایلی نیامده، جایگزین موقت نشان داده می‌شود و صفحه خراب نمی‌شود.

| فایل | کجا دیده می‌شود | جایگزین موقت |
|---|---|---|
| `app/assets/art/emoji/misc/crystal.png` | کاشی مأموریت «دریافت پاداش امروز» | `misc/gift` |
| `app/assets/art/emoji/misc/padlock.png` | قفل بزرگ وسط بنر فصل | `ui/lock` |
| `app/assets/art/emoji/faces/blob_low.png` | گزینه‌ی منفی سؤال‌های «حست دربارهٔ …» | `faces/thinking` |
| `app/assets/art/emoji/faces/blob_mid.png` | گزینه‌ی خنثی | `faces/relieved` |
| `app/assets/art/emoji/faces/blob_high.png` | گزینه‌ی مثبت | `faces/smiling_blush` |
| `app/assets/art/emoji/nature/cloud.png` | گزینه‌ی «یه کم ابری» | `calm/zzz` |
| `app/assets/art/background/season_yalda.webp` | تصویر پس‌زمینه‌ی بنر فصل یلدا | گرادیان قهوه‌ای تیره |
| `app/assets/art/background/season_nowruz.webp` | بنر نوروز | همان |
| `app/assets/art/background/season_ramadan.webp` | بنر رمضان | همان |

استیکرها: PNG شفاف، ۳۸۴×۳۸۴، شیء وسط تصویر و حدود ۹۰٪ از کادر. بنرها: WebP، ۱۰۸۰×۶۶۷ (نسبت ۱٫۶۲)، حداکثر ۱۵۰KB.

---

## پرامپت ۱: استیکرها (کنار `docs/art-refs/style-stickers.png` بگذار)

```
Using the attached image only as a STYLE reference (emoji-like sticker: flat soft shading, rounded shapes, and a thick clean WHITE outline around every object), draw the NEW stickers listed below in exactly that style. Do not redraw the stickers from the reference, and do not add any text, letters, numbers, characters, animals or faces unless listed.

Output: ONE square board, plain flat mid-grey background (#4A4A4A), a 2×2 grid, generous empty space between items so each sticker can be cut out cleanly, every sticker the same visual size and centred in its cell, no shadows on the background.

1. A cluster of three rainbow-iridescent crystals (pastel pink, mint, sky blue, lemon), faceted, glowing softly — a daily reward gem.
2. A big chunky golden-yellow padlock, closed, with a rounded silver-lilac shackle and a dark keyhole — friendly and toy-like, not scary.
3. A soft fluffy cloud, light blue-grey with a white highlight, slightly puffy and round.
4. A small pomegranate cut in half showing ruby seeds (spare, for the Yalda season).
```

ترتیب برش: ۱ → `misc/crystal`، ۲ → `misc/padlock`، ۳ → `nature/cloud`، ۴ → `food/pomegranate` (فعلاً استفاده نمی‌شود؛ برای فصل یلدا).

## پرامپت ۲: صورتک‌های حال (کنار `docs/art-refs/style-flat-icons.png` بگذار)

```
Using the attached image only as a STYLE reference (flat, soft rounded shapes, same colour palette, no outline, no shadow), draw the NEW icons listed below. Do not redraw the icons from the reference.

Output: ONE square board, plain white background, a single row of 3 icons with wide empty space between them, every icon the same size and centred in its cell. No text.

Three cute mood blobs, each a simple round creature with only two dot eyes and a small mouth (no arms, no legs, no nose):
1. LOW: a lavender-purple spiky blob (soft rounded spikes all around, like a fuzzy sun), eyes closed in a tired squint, small frown.
2. MID: a sky-blue perfectly round blob, two dot eyes, a short straight flat mouth — calm, neutral.
3. HIGH: a warm-orange scalloped flower-shaped blob (8 rounded petals as the outline), two dot eyes, a big open happy smile showing a dark mouth.
```

ترتیب برش: ۱ → `faces/blob_low`، ۲ → `faces/blob_mid`، ۳ → `faces/blob_high`.

## پرامپت ۳: بنرهای فصل (هر کدام جدا بساز)

پایه‌ی مشترک؛ فقط خط آخر را برای هر فصل عوض کن:

```
A cosy, warm illustrated interior scene for a mobile game season banner, wide landscape 1080×667. Flat vector style with soft shading, rounded chunky shapes, warm low evening light, slightly dark overall so white text and a big padlock can sit on top of the centre. Keep the centre third of the image calm and uncluttered (no important object there). No people, no animals, no characters, no text, no letters, no logos.

Scene: …
```

- **یلدا** (`season_yalda.webp`): `Scene: a Persian living room on Yalda night — a korsi table covered with a patterned quilt, a big bowl of pomegranates, a sliced watermelon, nuts and dried fruit, a closed old poetry book, candles and a brass samovar, a window showing a long dark snowy night with stars.`
- **نوروز** (`season_nowruz.webp`): `Scene: a bright spring room for Nowruz — a haft-sin table with green sabzeh sprouts, painted eggs, a goldfish bowl, red apples, hyacinths, a mirror and candles, an open window with blossoming pink trees.`
- **رمضان** (`season_ramadan.webp`): `Scene: a calm courtyard at iftar time — hanging warm lanterns, a low table with dates, a teapot and glasses of tea, a bowl of soup, a crescent moon in a deep blue-purple sky.`

---

بعد از ساختن، تصاویر را بفرست (برد کامل کافیه)؛ برش، شفاف‌سازی پس‌زمینه و جایگذاری با `scripts/build_art_assets.py` انجام می‌شود.
