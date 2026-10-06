# پرامپت‌های آرت فروشگاه (دسته‌ای)

هر پرامپت یک «برد» می‌سازد: چند آیتم در یک تصویر مربعی. **اسکرین‌شات فروشگاه رو کنار پرامپت پیوست کن** (فقط مرجع سبک است؛ هیچ آیتم یا شخصیتی کپی نمی‌شود).

بعد از ساختن هر برد، تصویر رو بفرست یا خودت این دستور رو اجرا کن (ترتیب اسم‌ها همان ترتیب شماره‌های پرامپت است):

```
python3 scripts/slice_board.py board.png <name1> <name2> ...
```

اسکریپت پس‌زمینه‌ی خاکستری را حذف می‌کند، هر آیتم را جدا و وسط یک PNG شفاف ۳۸۴×۳۸۴ می‌گذارد. تا وقتی تصویر آیتمی نیامده، اپ یک کاشی ساده با آیکون دسته نشان می‌دهد و چیزی خراب نمی‌شود.

نکته‌ها:
- آیتم‌های لباس روی گربه هم کشیده می‌شوند، برای همین باید از روبه‌رو و به اندازه‌ی گربه‌ی تپل کشیده شوند.
- رنگ‌های دیگر هر آیتم را اپ با چرخاندن رنگ (hue) می‌سازد؛ پس رنگ اصلی آیتم باید رنگی و شفاف باشد، نه سفید/خاکستری/مشکی.
- اگر مدل تعداد آیتم‌ها را کم یا زیاد کشید، اسکریپت خطا می‌دهد؛ همان برد را دوباره بساز.


## فهرست بردها (15 برد)

- لباس 1: تی‌شرت ساده، بلوز راه‌راه، هودی گرم، ژاکت بافتنی، کاپشن پفی، بارونی زرد، پولوشرت، پیراهن فوتبال، جلیقه‌ی سوزن‌دوزی، پیراهن گل‌دار، ژاکت دکمه‌دار، پیراهن یقه‌دار، رکابی، پیراهن ساحلی، بلوز پولکی، تی‌شرت هندونه
- لباس 2: شلوارک، شلوار جین، دامن پلیسه، شلوار گرمکن، شلوارک چهارخونه، شلوار جیب‌دار، مایو شورتی، دامن تور، شلوار ضدآب، شلوار گشاد محلی، لباس‌خواب سرهمی، سرهمی جین، لباس خرسی، لباس دایناسوری، لباس زنبوری، شنل بارونی
- لباس 3: لباس اناری، گرمکن سرهمی، کلاه بافتنی، کلاه گل‌دار، کلاه نمدی، کلاه کپ، کلاه حصیری، کلاه بارونی، کلاه تولد، تاج گل، کلاه بره، کلاه منگوله‌دار، کلاه باکت، کلاه توت‌فرنگی، هدبند ورزشی، پاپیون مو
- لباس 4: گوش‌گیر، کلاه فارغ‌التحصیلی، عینک گرد، عینک ستاره‌ای، عینک آفتابی، عینک قلبی، عینک مطالعه، عینک شنا، عینک اسکی، کک‌مک، شال پشمی، شال راه‌راه، شال ابریشمی، شال‌گردن بلند، دستمال‌گردن، گردنبند فیروزه‌ای
- لباس 5: گردنبند قرمز، گردنبند زنگوله‌دار، پاپیون، کراوات، گردنبند مروارید، گردنبند فیروزه، حلقه‌ی گل، کتونی، چکمه‌ی بارونی، دمپایی پشمالو، جوراب راه‌راه، گیوه، صندل، پوتین زمستونی، کفش عروسکی، بادکنک
- لباس 6: چتر، کتاب، بستنی یخی، استکان چای، شاخه‌ی گل، راکت، بادبادک، عروسک خرسی
- وسایل خونه 1: تخت ساده، تخت گرد دنج، تخت سایبون‌دار، تشک کف‌خواب، صندلی چوبی، مبل دونفره، پف نرم، صندلی حصیری، چارپایه، چراغ آویز، لوستر شمعی، فانوس، ریسه‌ی چراغ، آباژور ایستاده، قاب عکس، تابلو‌فرش
- وسایل خونه 2: ساعت دیواری، آینه‌ی قدی، تخته‌ی عکس، کاشی فیروزه‌ای، تابلوی خوشنویسی، پوستر گربه، آویز بافتنی، قفسه‌ی کتاب، قفسه‌ی گلدون، طاقچه، کتابخونه‌ی بلند، کمد کشودار، بوفه، صندوقچه، سماور، استکان چای
- وسایل خونه 3: گلدون شمعدانی، کاسه‌ی مسی، چراغ گرم، میز تحریر، میز عسلی، کرسی، شمع و گلدون، رادیو قدیمی، تُنگ ماهی، گلدون سانسوریا، گلدون آویز، گلدون برگ‌پهن، کاکتوس، بونسای، فرش کوچیک، پتوی گل‌دار
- وسایل خونه 4: پشتی نرم، فرش دستباف، پشتی، قالیچه‌ی گرد، فرش پشمالو، گبه، پادری، جالباسی، جاکفشی، جاچتری، کاغذدیواری راه‌راه، کاغذدیواری گل‌دار، دیوار آجری، کاغذدیواری ستاره‌ای، کف چوبی، کف کاشی
- وسایل خونه 5: کف شطرنجی، پنجره با کرکره، پنجره‌ی ارسی، پرده‌ی پارچه‌ای، پنجره‌ی گرد، در سفید، در چوبی کنده‌کاری، در طاق‌دار
- پس‌زمینه‌ها، فروشنده‌ها و آیکون‌ها: چهار برد آخر


---

## برد لباس 1 (16 آیتم)

| # | کلید | اسم | دسته | رنگ‌ها |
|---|---|---|---|---|
| 1 | `top_tshirt` | تی‌شرت ساده | بالاتنه | 6 |
| 2 | `top_striped` | بلوز راه‌راه | بالاتنه | 4 |
| 3 | `top_hoodie` | هودی گرم | بالاتنه | 5 |
| 4 | `top_knit_sweater` | ژاکت بافتنی | بالاتنه | 4 |
| 5 | `top_puffer` | کاپشن پفی | بالاتنه | 5 |
| 6 | `top_raincoat` | بارونی زرد | بالاتنه | 3 |
| 7 | `top_polo` | پولوشرت | بالاتنه | 5 |
| 8 | `top_jersey` | پیراهن فوتبال | بالاتنه | 4 |
| 9 | `top_vest_embroidered` | جلیقه‌ی سوزن‌دوزی | بالاتنه | 3 |
| 10 | `top_shirt_floral` | پیراهن گل‌دار | بالاتنه | 4 |
| 11 | `top_cardigan` | ژاکت دکمه‌دار | بالاتنه | 4 |
| 12 | `top_collar_shirt` | پیراهن یقه‌دار | بالاتنه | 3 |
| 13 | `top_tank` | رکابی | بالاتنه | 6 |
| 14 | `top_beach_shirt` | پیراهن ساحلی | بالاتنه | 4 |
| 15 | `top_sequin` | بلوز پولکی | بالاتنه | 3 |
| 16 | `top_watermelon` | تی‌شرت هندونه | بالاتنه | 1 |

```
Using the attached shop screenshot ONLY as a STYLE reference for the item art on its tiles (flat vector illustration, soft simple shading, no outline, rounded chunky friendly shapes, clean edges, bright cheerful palette), draw the NEW items listed below in exactly that style. Do not copy any item, character, text, logo or UI element from the screenshot.

Every item is drawn FRONT-FACING exactly as it would look WORN by a small, round, chubby cartoon cat (big round head, short round body, short arms and legs) — but draw ONLY the item, never the cat. Tops and onesies are short, wide and rounded with stubby sleeves; bottoms are short and wide; shoes are a pair seen from the front; hats sit as if on a big round head; glasses/face items are sized for a wide round face; neck items wrap a short thick neck; held items are drawn upright as if held in one paw.

Colour: paint each item mainly in the colour given (a clear, saturated mid-tone), because the app makes the other colour variants by shifting the hue — so avoid making the main part white, grey or black unless the description says so.

Output: ONE square image, plain flat mid-grey background (#4A4A4A), a 4×4 grid read left to right, top to bottom, in the numbered order. Every item centred in its own cell, all items at a similar visual size, generous empty space between items (nothing touches or overlaps), no shadows on the background, no text, no numbers, no labels.

1. a plain short-sleeved t-shirt, coral red
2. a long-sleeved top with horizontal navy and cream stripes (navy part recolours)
3. a cosy hoodie with a front pocket and drawstrings, mint green
4. a chunky cable-knit sweater, mustard yellow
5. a puffy quilted winter jacket with a zip, bright blue
6. a yellow rubber raincoat with toggles
7. a polo shirt with a collar and two buttons, green
8. a sports jersey with a big white star on the chest, red
9. a dark red vest with gold Persian embroidery over a white shirt
10. a short-sleeved shirt with small pink flowers on light blue
11. a buttoned cardigan with pockets, lilac purple
12. a school shirt with a pointed collar, sky blue
13. a simple tank top, orange
14. a loose beach shirt with palm leaves, teal
15. a sparkly sequin party top, magenta
16. a t-shirt printed like a watermelon slice (green rim, red middle, black seeds)
```

برش:
```
python3 scripts/slice_board.py board.png items/top_tshirt items/top_striped items/top_hoodie items/top_knit_sweater items/top_puffer items/top_raincoat items/top_polo items/top_jersey items/top_vest_embroidered items/top_shirt_floral items/top_cardigan items/top_collar_shirt items/top_tank items/top_beach_shirt items/top_sequin items/top_watermelon
```

---

## برد لباس 2 (16 آیتم)

| # | کلید | اسم | دسته | رنگ‌ها |
|---|---|---|---|---|
| 1 | `bottom_shorts` | شلوارک | پایین‌تنه | 6 |
| 2 | `bottom_jeans` | شلوار جین | پایین‌تنه | 3 |
| 3 | `bottom_pleated_skirt` | دامن پلیسه | پایین‌تنه | 5 |
| 4 | `bottom_sweatpants` | شلوار گرمکن | پایین‌تنه | 5 |
| 5 | `bottom_plaid_shorts` | شلوارک چهارخونه | پایین‌تنه | 4 |
| 6 | `bottom_cargo` | شلوار جیب‌دار | پایین‌تنه | 3 |
| 7 | `bottom_swim` | مایو شورتی | پایین‌تنه | 5 |
| 8 | `bottom_tutu` | دامن تور | پایین‌تنه | 4 |
| 9 | `bottom_rain_pants` | شلوار ضدآب | پایین‌تنه | 3 |
| 10 | `bottom_folk_pants` | شلوار گشاد محلی | پایین‌تنه | 3 |
| 11 | `onesie_pajama` | لباس‌خواب سرهمی | سرهمی | 5 |
| 12 | `onesie_overalls` | سرهمی جین | سرهمی | 3 |
| 13 | `onesie_bear` | لباس خرسی | سرهمی | 3 |
| 14 | `onesie_dino` | لباس دایناسوری | سرهمی | 3 |
| 15 | `onesie_bee` | لباس زنبوری | سرهمی | 1 |
| 16 | `onesie_rain_cape` | شنل بارونی | سرهمی | 4 |

```
Using the attached shop screenshot ONLY as a STYLE reference for the item art on its tiles (flat vector illustration, soft simple shading, no outline, rounded chunky friendly shapes, clean edges, bright cheerful palette), draw the NEW items listed below in exactly that style. Do not copy any item, character, text, logo or UI element from the screenshot.

Every item is drawn FRONT-FACING exactly as it would look WORN by a small, round, chubby cartoon cat (big round head, short round body, short arms and legs) — but draw ONLY the item, never the cat. Tops and onesies are short, wide and rounded with stubby sleeves; bottoms are short and wide; shoes are a pair seen from the front; hats sit as if on a big round head; glasses/face items are sized for a wide round face; neck items wrap a short thick neck; held items are drawn upright as if held in one paw.

Colour: paint each item mainly in the colour given (a clear, saturated mid-tone), because the app makes the other colour variants by shifting the hue — so avoid making the main part white, grey or black unless the description says so.

Output: ONE square image, plain flat mid-grey background (#4A4A4A), a 4×4 grid read left to right, top to bottom, in the numbered order. Every item centred in its own cell, all items at a similar visual size, generous empty space between items (nothing touches or overlaps), no shadows on the background, no text, no numbers, no labels.

1. simple shorts with an elastic waist, purple
2. blue jeans with rolled-up hems
3. a short pleated school skirt, navy blue
4. soft jogger sweatpants with cuffed ankles, grey-blue
5. plaid shorts, pink checks
6. cargo trousers with side pockets, olive green
7. swim shorts with a white side stripe, aqua
8. a fluffy layered tulle tutu skirt, pink
9. waterproof rain trousers, yellow
10. wide Persian folk trousers (shalvar) with an embroidered hem, deep red
11. a full-body pyjama onesie with buttons and little stars, light blue
12. denim dungarees/overalls with a bib pocket and straps over a white tee
13. a full-body teddy-bear costume with a hood with round ears, brown
14. a full-body dinosaur costume with spikes on the hood and back, green
15. a full-body bumblebee costume, yellow and black stripes with tiny wings
16. a hooded rain poncho cape, green
```

برش:
```
python3 scripts/slice_board.py board.png items/bottom_shorts items/bottom_jeans items/bottom_pleated_skirt items/bottom_sweatpants items/bottom_plaid_shorts items/bottom_cargo items/bottom_swim items/bottom_tutu items/bottom_rain_pants items/bottom_folk_pants items/onesie_pajama items/onesie_overalls items/onesie_bear items/onesie_dino items/onesie_bee items/onesie_rain_cape
```

---

## برد لباس 3 (16 آیتم)

| # | کلید | اسم | دسته | رنگ‌ها |
|---|---|---|---|---|
| 1 | `onesie_pomegranate` | لباس اناری | سرهمی | 1 |
| 2 | `onesie_tracksuit` | گرمکن سرهمی | سرهمی | 4 |
| 3 | `hat_beanie` | کلاه بافتنی | کلاه | 5 |
| 4 | `hat_flower` | کلاه گل‌دار | کلاه | 1 |
| 5 | `hat_felt` | کلاه نمدی | کلاه | 1 |
| 6 | `hat_cap` | کلاه کپ | کلاه | 8 |
| 7 | `hat_straw` | کلاه حصیری | کلاه | 3 |
| 8 | `hat_rain` | کلاه بارونی | کلاه | 3 |
| 9 | `hat_party` | کلاه تولد | کلاه | 5 |
| 10 | `hat_flower_crown` | تاج گل | کلاه | 3 |
| 11 | `hat_beret` | کلاه بره | کلاه | 6 |
| 12 | `hat_pompom` | کلاه منگوله‌دار | کلاه | 5 |
| 13 | `hat_bucket` | کلاه باکت | کلاه | 5 |
| 14 | `hat_strawberry` | کلاه توت‌فرنگی | کلاه | 1 |
| 15 | `hat_headband` | هدبند ورزشی | کلاه | 6 |
| 16 | `hat_hair_bow` | پاپیون مو | کلاه | 6 |

```
Using the attached shop screenshot ONLY as a STYLE reference for the item art on its tiles (flat vector illustration, soft simple shading, no outline, rounded chunky friendly shapes, clean edges, bright cheerful palette), draw the NEW items listed below in exactly that style. Do not copy any item, character, text, logo or UI element from the screenshot.

Every item is drawn FRONT-FACING exactly as it would look WORN by a small, round, chubby cartoon cat (big round head, short round body, short arms and legs) — but draw ONLY the item, never the cat. Tops and onesies are short, wide and rounded with stubby sleeves; bottoms are short and wide; shoes are a pair seen from the front; hats sit as if on a big round head; glasses/face items are sized for a wide round face; neck items wrap a short thick neck; held items are drawn upright as if held in one paw.

Colour: paint each item mainly in the colour given (a clear, saturated mid-tone), because the app makes the other colour variants by shifting the hue — so avoid making the main part white, grey or black unless the description says so.

Output: ONE square image, plain flat mid-grey background (#4A4A4A), a 4×4 grid read left to right, top to bottom, in the numbered order. Every item centred in its own cell, all items at a similar visual size, generous empty space between items (nothing touches or overlaps), no shadows on the background, no text, no numbers, no labels.

1. a round pomegranate costume (red body, crown-shaped collar), for Yalda night
2. a one-piece tracksuit with white side stripes, red
3. a teal knitted beanie with a white pom-pom
4. a little wreath of five pink flowers worn on the head
5. a traditional brown Persian felt cap (namad), rounded dome shape
6. a baseball cap with a curved brim, red
7. a wide-brim straw sun hat with a ribbon, natural straw with a blue ribbon
8. a rain hat (sou'wester), yellow
9. a cone party hat with dots and a pom-pom, blue
10. a flower crown of small daisies and leaves
11. a soft beret, red
12. a knitted winter hat with a big pom-pom and ear flaps, pink
13. a bucket hat, orange
14. a strawberry-shaped hat with green leaf top and yellow seeds
15. a sporty terry headband, blue
16. a big hair bow on a clip, pink
```

برش:
```
python3 scripts/slice_board.py board.png items/onesie_pomegranate items/onesie_tracksuit items/hat_beanie items/hat_flower items/hat_felt items/hat_cap items/hat_straw items/hat_rain items/hat_party items/hat_flower_crown items/hat_beret items/hat_pompom items/hat_bucket items/hat_strawberry items/hat_headband items/hat_hair_bow
```

---

## برد لباس 4 (16 آیتم)

| # | کلید | اسم | دسته | رنگ‌ها |
|---|---|---|---|---|
| 1 | `hat_earmuffs` | گوش‌گیر | کلاه | 4 |
| 2 | `hat_graduation` | کلاه فارغ‌التحصیلی | کلاه | 1 |
| 3 | `glasses_round` | عینک گرد | صورت | 4 |
| 4 | `glasses_star` | عینک ستاره‌ای | صورت | 4 |
| 5 | `glasses_sun` | عینک آفتابی | صورت | 4 |
| 6 | `glasses_heart` | عینک قلبی | صورت | 4 |
| 7 | `glasses_reading` | عینک مطالعه | صورت | 4 |
| 8 | `glasses_swim` | عینک شنا | صورت | 4 |
| 9 | `glasses_ski` | عینک اسکی | صورت | 3 |
| 10 | `glasses_freckles` | کک‌مک | صورت | 1 |
| 11 | `scarf_wool` | شال پشمی | گردن | 5 |
| 12 | `scarf_stripe` | شال راه‌راه | گردن | 4 |
| 13 | `scarf_silk` | شال ابریشمی | گردن | 3 |
| 14 | `scarf_long_knit` | شال‌گردن بلند | گردن | 5 |
| 15 | `scarf_bandana` | دستمال‌گردن | گردن | 6 |
| 16 | `collar_turquoise` | گردنبند فیروزه‌ای | گردن | 1 |

```
Using the attached shop screenshot ONLY as a STYLE reference for the item art on its tiles (flat vector illustration, soft simple shading, no outline, rounded chunky friendly shapes, clean edges, bright cheerful palette), draw the NEW items listed below in exactly that style. Do not copy any item, character, text, logo or UI element from the screenshot.

Every item is drawn FRONT-FACING exactly as it would look WORN by a small, round, chubby cartoon cat (big round head, short round body, short arms and legs) — but draw ONLY the item, never the cat. Tops and onesies are short, wide and rounded with stubby sleeves; bottoms are short and wide; shoes are a pair seen from the front; hats sit as if on a big round head; glasses/face items are sized for a wide round face; neck items wrap a short thick neck; held items are drawn upright as if held in one paw.

Colour: paint each item mainly in the colour given (a clear, saturated mid-tone), because the app makes the other colour variants by shifting the hue — so avoid making the main part white, grey or black unless the description says so.

Output: ONE square image, plain flat mid-grey background (#4A4A4A), a 4×4 grid read left to right, top to bottom, in the numbered order. Every item centred in its own cell, all items at a similar visual size, generous empty space between items (nothing touches or overlaps), no shadows on the background, no text, no numbers, no labels.

1. fluffy earmuffs on a band, white fluff with a red band (band recolours)
2. a black graduation cap with a gold tassel
3. round thin-rim glasses, orange frame
4. star-shaped party glasses, pink frame
5. cool sunglasses with dark lenses, red frame
6. heart-shaped glasses, pink frame and pink lenses
7. rectangular reading glasses, tortoise brown frame
8. swimming goggles with a strap, blue
9. big ski goggles with a mirrored lens, orange
10. a set of soft brown freckles for both cheeks (just the dots, arranged as on a face)
11. a chunky blue wool scarf wrapped around the neck with one end hanging
12. a red and cream striped knitted scarf wrapped around the neck
13. a purple silk neck scarf with a small paisley (boteh) pattern, tied in a knot
14. a very long knitted scarf with fringes, green
15. a triangle bandana tied around the neck, red with white dots
16. a turquoise leather pet collar with a small round gold tag
```

برش:
```
python3 scripts/slice_board.py board.png items/hat_earmuffs items/hat_graduation items/glasses_round items/glasses_star items/glasses_sun items/glasses_heart items/glasses_reading items/glasses_swim items/glasses_ski items/glasses_freckles items/scarf_wool items/scarf_stripe items/scarf_silk items/scarf_long_knit items/scarf_bandana items/collar_turquoise
```

---

## برد لباس 5 (16 آیتم)

| # | کلید | اسم | دسته | رنگ‌ها |
|---|---|---|---|---|
| 1 | `collar_red` | گردنبند قرمز | گردن | 1 |
| 2 | `collar_bell` | گردنبند زنگوله‌دار | گردن | 1 |
| 3 | `collar_bowtie` | پاپیون | گردن | 6 |
| 4 | `collar_tie` | کراوات | گردن | 4 |
| 5 | `collar_pearls` | گردنبند مروارید | گردن | 1 |
| 6 | `collar_turquoise_beads` | گردنبند فیروزه | گردن | 1 |
| 7 | `collar_lei` | حلقه‌ی گل | گردن | 3 |
| 8 | `shoes_sneakers` | کتونی | کفش | 6 |
| 9 | `shoes_rain_boots` | چکمه‌ی بارونی | کفش | 4 |
| 10 | `shoes_fluffy_slippers` | دمپایی پشمالو | کفش | 5 |
| 11 | `shoes_striped_socks` | جوراب راه‌راه | کفش | 5 |
| 12 | `shoes_giveh` | گیوه | کفش | 2 |
| 13 | `shoes_sandals` | صندل | کفش | 4 |
| 14 | `shoes_winter_boots` | پوتین زمستونی | کفش | 3 |
| 15 | `shoes_mary_janes` | کفش عروسکی | کفش | 4 |
| 16 | `held_balloon` | بادکنک | دستی | 8 |

```
Using the attached shop screenshot ONLY as a STYLE reference for the item art on its tiles (flat vector illustration, soft simple shading, no outline, rounded chunky friendly shapes, clean edges, bright cheerful palette), draw the NEW items listed below in exactly that style. Do not copy any item, character, text, logo or UI element from the screenshot.

Every item is drawn FRONT-FACING exactly as it would look WORN by a small, round, chubby cartoon cat (big round head, short round body, short arms and legs) — but draw ONLY the item, never the cat. Tops and onesies are short, wide and rounded with stubby sleeves; bottoms are short and wide; shoes are a pair seen from the front; hats sit as if on a big round head; glasses/face items are sized for a wide round face; neck items wrap a short thick neck; held items are drawn upright as if held in one paw.

Colour: paint each item mainly in the colour given (a clear, saturated mid-tone), because the app makes the other colour variants by shifting the hue — so avoid making the main part white, grey or black unless the description says so.

Output: ONE square image, plain flat mid-grey background (#4A4A4A), a 4×4 grid read left to right, top to bottom, in the numbered order. Every item centred in its own cell, all items at a similar visual size, generous empty space between items (nothing touches or overlaps), no shadows on the background, no text, no numbers, no labels.

1. a red leather pet collar with a small round gold tag
2. a soft pink pet collar with a big shiny gold jingle bell
3. a bow tie, red
4. a neck tie with diagonal stripes, blue
5. a pearl necklace
6. a necklace of Persian turquoise (firouzeh) beads with a silver pendant
7. a Hawaiian flower lei necklace, pink flowers
8. a pair of sneakers with white soles, red
9. a pair of rubber rain boots, yellow
10. a pair of fluffy slippers, pink
11. a pair of striped socks, red and white
12. a pair of traditional Persian giveh shoes (white woven cotton tops, light sole), with a coloured stitched band
13. a pair of strappy sandals, orange
14. a pair of fur-lined winter boots, brown with cream fur cuffs
15. a pair of shiny Mary Jane shoes with a strap, red
16. a round balloon on a string, red
```

برش:
```
python3 scripts/slice_board.py board.png items/collar_red items/collar_bell items/collar_bowtie items/collar_tie items/collar_pearls items/collar_turquoise_beads items/collar_lei items/shoes_sneakers items/shoes_rain_boots items/shoes_fluffy_slippers items/shoes_striped_socks items/shoes_giveh items/shoes_sandals items/shoes_winter_boots items/shoes_mary_janes items/held_balloon
```

---

## برد لباس 6 (8 آیتم)

| # | کلید | اسم | دسته | رنگ‌ها |
|---|---|---|---|---|
| 1 | `held_umbrella` | چتر | دستی | 5 |
| 2 | `held_book` | کتاب | دستی | 4 |
| 3 | `held_ice_pop` | بستنی یخی | دستی | 5 |
| 4 | `held_tea_glass` | استکان چای | دستی | 1 |
| 5 | `held_flower` | شاخه‌ی گل | دستی | 4 |
| 6 | `held_racket` | راکت | دستی | 3 |
| 7 | `held_kite` | بادبادک | دستی | 4 |
| 8 | `held_teddy` | عروسک خرسی | دستی | 3 |

```
Using the attached shop screenshot ONLY as a STYLE reference for the item art on its tiles (flat vector illustration, soft simple shading, no outline, rounded chunky friendly shapes, clean edges, bright cheerful palette), draw the NEW items listed below in exactly that style. Do not copy any item, character, text, logo or UI element from the screenshot.

Every item is drawn FRONT-FACING exactly as it would look WORN by a small, round, chubby cartoon cat (big round head, short round body, short arms and legs) — but draw ONLY the item, never the cat. Tops and onesies are short, wide and rounded with stubby sleeves; bottoms are short and wide; shoes are a pair seen from the front; hats sit as if on a big round head; glasses/face items are sized for a wide round face; neck items wrap a short thick neck; held items are drawn upright as if held in one paw.

Colour: paint each item mainly in the colour given (a clear, saturated mid-tone), because the app makes the other colour variants by shifting the hue — so avoid making the main part white, grey or black unless the description says so.

Output: ONE square image, plain flat mid-grey background (#4A4A4A), a 3×3 grid read left to right, top to bottom, in the numbered order. Every item centred in its own cell, all items at a similar visual size, generous empty space between items (nothing touches or overlaps), no shadows on the background, no text, no numbers, no labels.

1. an open umbrella, blue
2. a closed book with a bookmark, green cover
3. an ice lolly on a stick, pink with a bite taken
4. a Persian tea glass (estekan) of amber tea on a small saucer
5. a single long-stem flower, pink tulip
6. a tennis racket, blue frame
7. a diamond kite with a ribbon tail, orange
8. a small teddy bear toy, brown
```

برش:
```
python3 scripts/slice_board.py board.png items/held_umbrella items/held_book items/held_ice_pop items/held_tea_glass items/held_flower items/held_racket items/held_kite items/held_teddy
```

---

## برد وسایل خونه 1 (16 آیتم)

| # | کلید | اسم | دسته | رنگ‌ها |
|---|---|---|---|---|
| 1 | `bed_simple` | تخت ساده | bed | 4 |
| 2 | `bed_round_nest` | تخت گرد دنج | bed | 3 |
| 3 | `bed_canopy` | تخت سایبون‌دار | bed | 3 |
| 4 | `bed_floor_mattress` | تشک کف‌خواب | bed | 4 |
| 5 | `chair_wood` | صندلی چوبی | seat | 3 |
| 6 | `sofa_small` | مبل دونفره | seat | 5 |
| 7 | `beanbag` | پف نرم | seat | 6 |
| 8 | `chair_rattan` | صندلی حصیری | seat | 1 |
| 9 | `stool` | چارپایه | seat | 4 |
| 10 | `lamp_pendant` | چراغ آویز | lamp | 4 |
| 11 | `chandelier_candle` | لوستر شمعی | lamp | 1 |
| 12 | `lantern` | فانوس | lamp | 3 |
| 13 | `string_lights` | ریسه‌ی چراغ | lamp | 5 |
| 14 | `lamp_floor` | آباژور ایستاده | lamp | 4 |
| 15 | `wall_frame` | قاب عکس | wall | 1 |
| 16 | `wall_tapestry` | تابلو‌فرش | wall | 1 |

```
Using the attached shop screenshot ONLY as a STYLE reference for the item art on its tiles (flat vector illustration, soft simple shading, no outline, rounded chunky friendly shapes, clean edges, bright cheerful palette), draw the NEW items listed below in exactly that style. Do not copy any item, character, text, logo or UI element from the screenshot.

Colour: paint each item mainly in the colour given (a clear, saturated mid-tone), because the app makes the other colour variants by shifting the hue — so avoid making the main part white, grey or black unless the description says so.
Furniture is drawn in a gentle 3/4 front view (rugs and floor swatches slightly from above), each piece standing on its own with no floor or wall around it.

Output: ONE square image, plain flat mid-grey background (#4A4A4A), a 4×4 grid read left to right, top to bottom, in the numbered order. Every item centred in its own cell, all items at a similar visual size, generous empty space between items (nothing touches or overlaps), no shadows on the background, no text, no numbers, no labels.

1. a simple bed with a pillow and a duvet, blue
2. a round cosy pet bed like a nest, with a cushion, pink
3. a bed with a fabric canopy and fairy lights, lilac
4. a thin Persian floor mattress (toshak) with a pillow and a patterned cover, orange
5. a wooden chair with a cushion, green cushion
6. a small two-seat sofa, red
7. a squishy beanbag chair, orange
8. a rattan armchair with a cream cushion
9. a round wooden stool, blue seat
10. a pendant ceiling lamp with a dome shade on a cord, yellow
11. a small iron chandelier with four candles
12. a Persian copper lantern with patterned cut-outs and a glow, coloured glass panels (blue)
13. a garland of string lights with round bulbs, multi-coloured (pink bulbs)
14. a standing floor lamp with a fabric shade, teal
15. a framed picture of a mountain landscape
16. a wall hanging with a Persian paisley (boteh) pattern
```

برش:
```
python3 scripts/slice_board.py board.png items/bed_simple items/bed_round_nest items/bed_canopy items/bed_floor_mattress items/chair_wood items/sofa_small items/beanbag items/chair_rattan items/stool items/lamp_pendant items/chandelier_candle items/lantern items/string_lights items/lamp_floor items/wall_frame items/wall_tapestry
```

---

## برد وسایل خونه 2 (16 آیتم)

| # | کلید | اسم | دسته | رنگ‌ها |
|---|---|---|---|---|
| 1 | `clock_wall` | ساعت دیواری | wall | 4 |
| 2 | `mirror_tall` | آینه‌ی قدی | wall | 1 |
| 3 | `photo_grid` | تخته‌ی عکس | wall | 1 |
| 4 | `tile_panel` | کاشی فیروزه‌ای | wall | 1 |
| 5 | `calligraphy_frame` | تابلوی خوشنویسی | wall | 1 |
| 6 | `poster_cat` | پوستر گربه | wall | 4 |
| 7 | `macrame_hanging` | آویز بافتنی | wall | 1 |
| 8 | `shelf_books` | قفسه‌ی کتاب | shelf | 1 |
| 9 | `shelf_plants` | قفسه‌ی گلدون | shelf | 1 |
| 10 | `shelf_niche` | طاقچه | shelf | 3 |
| 11 | `bookcase_tall` | کتابخونه‌ی بلند | shelf | 3 |
| 12 | `dresser_wood` | کمد کشودار | dresser | 4 |
| 13 | `sideboard` | بوفه | dresser | 3 |
| 14 | `chest_trunk` | صندوقچه | dresser | 3 |
| 15 | `samovar` | سماور | table | 1 |
| 16 | `tea_glass` | استکان چای | table | 1 |

```
Using the attached shop screenshot ONLY as a STYLE reference for the item art on its tiles (flat vector illustration, soft simple shading, no outline, rounded chunky friendly shapes, clean edges, bright cheerful palette), draw the NEW items listed below in exactly that style. Do not copy any item, character, text, logo or UI element from the screenshot.

Colour: paint each item mainly in the colour given (a clear, saturated mid-tone), because the app makes the other colour variants by shifting the hue — so avoid making the main part white, grey or black unless the description says so.
Furniture is drawn in a gentle 3/4 front view (rugs and floor swatches slightly from above), each piece standing on its own with no floor or wall around it.

Output: ONE square image, plain flat mid-grey background (#4A4A4A), a 4×4 grid read left to right, top to bottom, in the numbered order. Every item centred in its own cell, all items at a similar visual size, generous empty space between items (nothing touches or overlaps), no shadows on the background, no text, no numbers, no labels.

1. a round wall clock, red rim
2. a tall standing mirror with a wooden frame
3. a wire grid board with clipped photos and notes
4. a decorative wall panel of Persian turquoise tiles with a floral pattern
5. a framed Persian calligraphy artwork (abstract strokes, no readable text)
6. a framed poster of a cute cat face, blue background
7. a macrame wall hanging on a wooden stick
8. a wall shelf with colourful books
9. a wall shelf with small potted plants
10. a wall niche (taghcheh) with a vase and a small mirror, painted frame (blue)
11. a tall bookcase full of books, wooden with green books
12. a chest of drawers with round knobs, yellow
13. a low sideboard cabinet with two doors, green
14. a wooden treasure-style storage trunk with metal corners, red
15. a brass Persian samovar with a teapot on top
16. a Persian tea glass (estekan) on a saucer with two sugar cubes
```

برش:
```
python3 scripts/slice_board.py board.png items/clock_wall items/mirror_tall items/photo_grid items/tile_panel items/calligraphy_frame items/poster_cat items/macrame_hanging items/shelf_books items/shelf_plants items/shelf_niche items/bookcase_tall items/dresser_wood items/sideboard items/chest_trunk items/samovar items/tea_glass
```

---

## برد وسایل خونه 3 (16 آیتم)

| # | کلید | اسم | دسته | رنگ‌ها |
|---|---|---|---|---|
| 1 | `geranium_pot` | گلدون شمعدانی | table | 1 |
| 2 | `copper_bowl` | کاسه‌ی مسی | table | 1 |
| 3 | `lamp_warm` | چراغ گرم | table | 1 |
| 4 | `desk_study` | میز تحریر | table | 3 |
| 5 | `table_side` | میز عسلی | table | 4 |
| 6 | `korsi` | کرسی | table | 1 |
| 7 | `candle_vase` | شمع و گلدون | table | 1 |
| 8 | `radio_old` | رادیو قدیمی | table | 3 |
| 9 | `fish_bowl` | تُنگ ماهی | table | 1 |
| 10 | `plant_snake` | گلدون سانسوریا | plant | 1 |
| 11 | `plant_hanging` | گلدون آویز | plant | 3 |
| 12 | `plant_monstera` | گلدون برگ‌پهن | plant | 1 |
| 13 | `cactus` | کاکتوس | plant | 3 |
| 14 | `bonsai` | بونسای | plant | 1 |
| 15 | `rug_small` | فرش کوچیک | floor | 4 |
| 16 | `blanket_floral` | پتوی گل‌دار | floor | 3 |

```
Using the attached shop screenshot ONLY as a STYLE reference for the item art on its tiles (flat vector illustration, soft simple shading, no outline, rounded chunky friendly shapes, clean edges, bright cheerful palette), draw the NEW items listed below in exactly that style. Do not copy any item, character, text, logo or UI element from the screenshot.

Colour: paint each item mainly in the colour given (a clear, saturated mid-tone), because the app makes the other colour variants by shifting the hue — so avoid making the main part white, grey or black unless the description says so.
Furniture is drawn in a gentle 3/4 front view (rugs and floor swatches slightly from above), each piece standing on its own with no floor or wall around it.

Output: ONE square image, plain flat mid-grey background (#4A4A4A), a 4×4 grid read left to right, top to bottom, in the numbered order. Every item centred in its own cell, all items at a similar visual size, generous empty space between items (nothing touches or overlaps), no shadows on the background, no text, no numbers, no labels.

1. a clay pot of red geraniums (sham-dooni)
2. a hammered copper bowl full of fruit
3. a small table lamp with a warm glowing shade
4. a study desk with a lamp and a notebook, blue
5. a round side table, orange
6. a Persian korsi: low square table covered by a big patterned quilt with cushions around
7. a candle and a glass vase with dried flowers
8. a retro radio with knobs, red
9. a round goldfish bowl with a red fish (like Nowruz haft-sin)
10. a snake plant in a white pot
11. a hanging planter with trailing ivy, terracotta pot (pink)
12. a monstera plant with big leaves in a basket pot
13. a round cactus in a pot, pot is blue
14. a small bonsai tree in a shallow pot
15. a small rectangular rug with fringes, red
16. a folded quilt with a floral pattern, pink
```

برش:
```
python3 scripts/slice_board.py board.png items/geranium_pot items/copper_bowl items/lamp_warm items/desk_study items/table_side items/korsi items/candle_vase items/radio_old items/fish_bowl items/plant_snake items/plant_hanging items/plant_monstera items/cactus items/bonsai items/rug_small items/blanket_floral
```

---

## برد وسایل خونه 4 (16 آیتم)

| # | کلید | اسم | دسته | رنگ‌ها |
|---|---|---|---|---|
| 1 | `pillow_cozy` | پشتی نرم | floor | 5 |
| 2 | `rug_persian` | فرش دستباف | floor | 1 |
| 3 | `cushion_back` | پشتی | floor | 3 |
| 4 | `rug_round` | قالیچه‌ی گرد | floor | 5 |
| 5 | `rug_fluffy` | فرش پشمالو | floor | 5 |
| 6 | `gabbeh` | گبه | floor | 3 |
| 7 | `doormat` | پادری | doorside | 5 |
| 8 | `coat_rack` | جالباسی | doorside | 3 |
| 9 | `shoe_rack` | جاکفشی | doorside | 3 |
| 10 | `umbrella_stand` | جاچتری | doorside | 1 |
| 11 | `wallpaper_stripes` | کاغذدیواری راه‌راه | wallpaper | 5 |
| 12 | `wallpaper_floral` | کاغذدیواری گل‌دار | wallpaper | 4 |
| 13 | `wallpaper_brick` | دیوار آجری | wallpaper | 1 |
| 14 | `wallpaper_stars` | کاغذدیواری ستاره‌ای | wallpaper | 3 |
| 15 | `floor_wood` | کف چوبی | flooring | 3 |
| 16 | `floor_tiles` | کف کاشی | flooring | 3 |

```
Using the attached shop screenshot ONLY as a STYLE reference for the item art on its tiles (flat vector illustration, soft simple shading, no outline, rounded chunky friendly shapes, clean edges, bright cheerful palette), draw the NEW items listed below in exactly that style. Do not copy any item, character, text, logo or UI element from the screenshot.

Colour: paint each item mainly in the colour given (a clear, saturated mid-tone), because the app makes the other colour variants by shifting the hue — so avoid making the main part white, grey or black unless the description says so.
Furniture is drawn in a gentle 3/4 front view (rugs and floor swatches slightly from above), each piece standing on its own with no floor or wall around it.

Output: ONE square image, plain flat mid-grey background (#4A4A4A), a 4×4 grid read left to right, top to bottom, in the numbered order. Every item centred in its own cell, all items at a similar visual size, generous empty space between items (nothing touches or overlaps), no shadows on the background, no text, no numbers, no labels.

1. a soft square floor pillow, yellow
2. a Persian carpet with a medallion pattern, deep red and navy, seen from slightly above
3. a long Persian floor back-cushion (poshti) with a termeh pattern, red
4. a round rug with circle pattern, blue, seen from slightly above
5. a fluffy shaggy rug, pink, seen from slightly above
6. a Persian gabbeh rug with a simple deer/tree motif, red-orange, seen from slightly above
7. a doormat with a paw print, green
8. a standing coat rack with a scarf and a hat, wooden with a red scarf
9. a small shoe rack with two pairs of shoes, blue
10. an umbrella stand with two umbrellas
11. a square swatch of striped wallpaper, pink and cream (fill the square, slight rounded corners)
12. a square swatch of floral wallpaper, green leaves on cream (fill the square, slight rounded corners)
13. a square swatch of red brick wall (fill the square, slight rounded corners)
14. a square swatch of wallpaper with small stars, navy blue (fill the square, slight rounded corners)
15. a square swatch of wooden parquet floor, honey wood (fill the square, slight rounded corners)
16. a square swatch of Persian patterned floor tiles, blue (fill the square, slight rounded corners)
```

برش:
```
python3 scripts/slice_board.py board.png items/pillow_cozy items/rug_persian items/cushion_back items/rug_round items/rug_fluffy items/gabbeh items/doormat items/coat_rack items/shoe_rack items/umbrella_stand items/wallpaper_stripes items/wallpaper_floral items/wallpaper_brick items/wallpaper_stars items/floor_wood items/floor_tiles
```

---

## برد وسایل خونه 5 (8 آیتم)

| # | کلید | اسم | دسته | رنگ‌ها |
|---|---|---|---|---|
| 1 | `floor_checker` | کف شطرنجی | flooring | 4 |
| 2 | `window_blinds` | پنجره با کرکره | window | 3 |
| 3 | `window_orosi` | پنجره‌ی ارسی | window | 1 |
| 4 | `curtains` | پرده‌ی پارچه‌ای | window | 5 |
| 5 | `window_round` | پنجره‌ی گرد | window | 1 |
| 6 | `door_white` | در سفید | door | 4 |
| 7 | `door_carved` | در چوبی کنده‌کاری | door | 1 |
| 8 | `door_arched` | در طاق‌دار | door | 3 |

```
Using the attached shop screenshot ONLY as a STYLE reference for the item art on its tiles (flat vector illustration, soft simple shading, no outline, rounded chunky friendly shapes, clean edges, bright cheerful palette), draw the NEW items listed below in exactly that style. Do not copy any item, character, text, logo or UI element from the screenshot.

Colour: paint each item mainly in the colour given (a clear, saturated mid-tone), because the app makes the other colour variants by shifting the hue — so avoid making the main part white, grey or black unless the description says so.
Furniture is drawn in a gentle 3/4 front view (rugs and floor swatches slightly from above), each piece standing on its own with no floor or wall around it.

Output: ONE square image, plain flat mid-grey background (#4A4A4A), a 3×3 grid read left to right, top to bottom, in the numbered order. Every item centred in its own cell, all items at a similar visual size, generous empty space between items (nothing touches or overlaps), no shadows on the background, no text, no numbers, no labels.

1. a square swatch of black-and-white checker floor with a coloured border, red border
2. a square window with roller blinds half down, white frame, yellow blind
3. a Persian orosi window: wooden lattice with coloured stained glass (red, blue, yellow)
4. a window with fabric curtains tied at the sides, red curtains
5. a round window with a wooden frame showing sky and a tree
6. a simple panel door with a round knob, painted mint
7. a carved wooden Persian double door with two knockers
8. an arched garden door with a small window, green
```

برش:
```
python3 scripts/slice_board.py board.png items/floor_checker items/window_blinds items/window_orosi items/curtains items/window_round items/door_white items/door_carved items/door_arched
```

---

## برد پس‌زمینه‌های گربه (۳ صحنه)

```
Using the attached shop screenshot ONLY as a STYLE reference (flat vector illustration, soft shading, no outline, rounded friendly shapes), draw THREE small square background scenes for a cute cat game. Each scene completely fills its own rounded square card. No characters, no animals, no text.

Output: ONE wide image, plain flat mid-grey background (#4A4A4A), the three square cards side by side with wide gaps between them.

1. a square scene of a Persian alley at sunset (brick walls, a mulberry tree, warm light) — background scene, fill the whole square
2. a square scene of a Tehran rooftop at night with stars and string lights — background scene, fill the whole square
3. a square scene of a Persian garden in spring with a pool, cypress trees and blossoms — background scene, fill the whole square
```
برش:
```
python3 scripts/slice_board.py board.png items/bg_alley_evening items/bg_rooftop_night items/bg_garden_spring
```

---

## برد فروشنده‌ها و آیکون‌های فروشگاه (استیکری)

کنار `docs/art-refs/style-stickers.png` بذار.

```
Using the attached image only as a STYLE reference (emoji-like sticker: flat soft shading, rounded shapes, and a thick clean WHITE outline around every object), draw the NEW stickers listed below in exactly that style. Do not redraw the stickers from the reference, and do not add any text or letters.

Output: ONE square board, plain flat mid-grey background (#4A4A4A), a 3×2 grid, generous empty space between items, every sticker the same visual size and centred in its cell.

1. An original shopkeeper character: a friendly round hedgehog tailor, upper body, wearing a small brown Persian felt cap (namad), round glasses and a measuring tape around the neck, holding a pair of scissors, waving.
2. An original shopkeeper character: a cheerful crow carpenter, upper body, wearing a felt cap and a little apron with a pencil behind the ear, holding a small hammer.
3. Clothes on a hanger: an orange t-shirt and a red shirt hanging on a small rail (the clothes shop icon).
4. A cosy red armchair with a standing lamp next to it (the furniture shop icon).
5. A thick catalogue book with a magnifying glass on its cover (the catalogue button).
6. A cloth money pouch tied with a string, with a coin peeking out (the sell button).
```
برش:
```
python3 scripts/slice_board.py board.png emoji/animals/keeper_outfit emoji/animals/keeper_furniture emoji/nav/outfit emoji/nav/furniture emoji/misc/catalog emoji/misc/sell_bag
```

---

## برد آیکون‌های دسته‌ها (سفید، تخت)

```
Draw 20 simple category icons as solid filled silhouettes in a single flat colour (pure black), rounded friendly shapes, no outline, no shading, no text — like app tab icons. All the same visual size and line weight.

Output: ONE square image, plain white background, a 5×4 grid read left to right, top to bottom, wide gaps between icons.

1. a 3×3 grid of dots (all items)
2. a t-shirt (tops)
3. a pair of shorts (bottoms)
4. a baby onesie / romper (full body)
5. a top hat (hats)
6. a pair of glasses (face)
7. a scarf (neck)
8. a sneaker (shoes)
9. a balloon on a string (held items)
10. a bed (beds)
11. an armchair (seats)
12. a hanging lamp (lights)
13. a picture frame (wall)
14. a chest of drawers (storage)
15. a small table (tables)
16. a potted plant (plants)
17. a rug with fringes (rugs)
18. a door mat with a coat hook (by the door)
19. a window (room decor)
20. a mountain landscape (backgrounds)
```
برش (اسکریپت سفیدشان می‌کند؛ اپ رنگشان را خودش می‌دهد):
```
python3 scripts/slice_board.py board.png glyph:cat_all glyph:cat_top glyph:cat_bottom glyph:cat_onesie glyph:cat_hat glyph:cat_glasses glyph:cat_neck glyph:cat_shoes glyph:cat_held glyph:cat_bed glyph:cat_seat glyph:cat_lamp glyph:cat_wall glyph:cat_storage glyph:cat_table glyph:cat_plant glyph:cat_rug glyph:cat_doorside glyph:cat_interior glyph:cat_background
```

---

## صحنه‌های فروشگاه (هر کدام جدا، بدون برش)

پایه‌ی مشترک:
```
A cute flat vector illustration scene for a mobile game shop, portrait 1080×1350, soft shading, rounded chunky shapes, no outline. No characters, no animals, no text. Keep the upper half calm and simple (a card is placed on top) and the lower-left corner empty (the shopkeeper stands there).

Scene: …
```
- `app/assets/art/background/shop_outfit.webp`: `Scene: the back wall of a small tailor's shop in a Persian bazaar — olive-green walls, soft silhouettes of hanging fabrics and a few branches, a little wooden counter edge at the bottom.`
- `app/assets/art/background/shop_furniture.webp`: `Scene: an autumn yard of a carpenter's workshop — warm orange sky, rolling clouds, a wooden fence, a few pumpkins and stacked planks at the bottom right.`
- `app/assets/art/background/shop_hub.webp` (۱۰۸۰×۱۲۰۰): `Scene: a dusky evening view of a covered Persian bazaar entrance with a big arch, warm lanterns and a few rooftops — quite dark overall so white text and a cat read on top; keep the centre open.`

