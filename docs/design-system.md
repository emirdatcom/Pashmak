# سیستم طراحی (پرامپت 22)

الگوی تجربه و سبک بصری «مرجع داخلی تیم» است؛ هیچ دارایی (تصویر/آیکون/فونت/متن/نام) از اپ مرجع وارد مخزن نمی‌شود (قاعده‌ی هویت پرامپت 22). اسکرین‌شات‌ها در `input/reference/finch/` هستند و مقایسه‌ی بصری هر صفحه در `docs/visual-diff/` ثبت شده (پرامپت 23).

## ۱. ناوبری
نوار تب پایین ۵ تبه (راست‌به‌چپ، خانه سمت راست): `/home` · `/quests` · `/shop` · `/bag` · `/cat`. رنگ نوار هم‌رنگ پس‌زمینه‌ی تب جاری. منوی همبرگری ← `/menu`. تب «دوستان» و بخش «جامعه» ساخته نمی‌شوند (spec §۱۵). `/habits/*` ← `/goals/*` با redirect برای deep linkهای نوتیف/ویجت.

## ۲. Tokenها (`core/theme/tokens.dart`)
پس‌زمینه‌ها **دقیقاً** از مرجع نمونه‌برداری شده‌اند (`app/tool/visual_compare/sample_colors.py`: میانه‌ی رنگ غالب هر اسکرین‌شات). برای رسیدن به AA هیچ پس‌زمینه‌ای تیره‌تر نشده؛ فقط رنگ متن/آیکون انتخاب می‌شود: سفید، `textPrimary`، `textDeep` (`#1A2226`، همان `onPrimary`) یا `textSecondary`.

| token | مقدار | کاربرد |
|---|---|---|
| `bgQuests` | `#AF7E56` | مأموریت‌ها (متن `textDeep`) |
| `bgShopPanel` / `shopTile` / `bgShopScene` | `#633F2F` / `#9B614B` / `#87A045` | پنل، کاشی و صحنه فروشگاه |
| `bgBag` / `bgBagScene` / `bgBagLocked` | `#F4A838` / `#3F3D6E` / `#EC910D` | کیف |
| `bgCat` / `cardCat` | `#E9D3A1` / `#FFF6ED` | پروفایل گربه |
| `bgSettings` | `#D3E1EE` | تنظیمات و منو |
| `bgExercises` / `bgBreathing` | `#6F52BC` / `#96DFB2` | تمرین‌ها / اجرای تنفس |
| `bgHomeGround` | `#7BB65C` | زمین خانه و ساخت هدف |
| `primaryGreen` (+ لبه `#3E9440`) | `#55B752` | دکمه تأیید؛ برچسب `onPrimary` تیره |
| `progressYellow` / ریل | `#FFC845` / `#EFEFEF` | نوار پیشرفت |
| `doneBg` / `doneText` | `#E8E9C1` / `#256D2A` | انجام‌شده |
| `premiumBadge` | `#566FD6` | پریمیوم |
| `textPrimary` / `textSecondary` / `textDeep` | `#2E3A3F` / `#47535A` / `#1A2226` | متن |
| رنگ‌های صحنه (`scene*`) | تپه، دیوار، درخت، حوض، گلدان | حیاط حوض‌دار |
| `card` | سفید، radius 28 | کارت |
| `button.3d` | radius 20، لبه ۴dp | دکمه |

رنگ hard-code بیرون از `tokens.dart` ممنوع است. تم تیره غیرفعال است.

### کنتراست جفت‌ها (WCAG AA ≥ ۴.۵)
`test/theme_test.dart` همه‌ی این جفت‌ها را می‌سنجد.

| متن/آیکون | پس‌زمینه | نسبت |
|---|---|---|
| `textPrimary` #2E3A3F | `card` #FFFFFF | 11.71 |
| `textSecondary` #47535A | `card` #FFFFFF | 7.92 |
| `textSecondary` #47535A | `cardCat` #FFF6ED | 7.41 |
| `textDeep` #1A2226 | `bgQuests` #AF7E56 | 4.57 |
| `onDark` #FFFFFF | `bgShopPanel` #633F2F | 9.20 |
| `textDeep` #1A2226 | `bgShopScene` #87A045 | 5.49 |
| `onDark` #FFFFFF | `shopTile` #9B614B | 4.99 |
| `textPrimary` #2E3A3F | `bgBag` #F4A838 | 5.86 |
| `textDeep` #1A2226 | `bgBagLocked` #EC910D | 6.63 |
| `onDark` #FFFFFF | `bgBagScene` #3F3D6E | 9.98 |
| `textPrimary` #2E3A3F | `bgCat` #E9D3A1 | 7.97 |
| `textSecondary` #47535A | `bgCat` #E9D3A1 | 5.39 |
| `textPrimary` #2E3A3F | `bgSettings` #D3E1EE | 8.80 |
| `textSecondary` #47535A | `bgSettings` #D3E1EE | 5.95 |
| `onDark` #FFFFFF | `bgExercises` #6F52BC | 5.82 |
| `textPrimary` #2E3A3F | `bgBreathing` #96DFB2 | 7.53 |
| `textPrimary` #2E3A3F | `bgHomeGround` #7BB65C | 4.85 |
| `textDeep` #1A2226 | `bgHomeGround` #7BB65C | 6.68 |
| `onPrimary` #1A2226 | `primaryGreen` #55B752 | 6.37 |
| `textPrimary` #2E3A3F | `progressYellow` #FFC845 | 7.58 |
| `doneText` #256D2A | `doneBg` #E8E9C1 | 5.11 |
| `textSecondary` #47535A | `doneBg` #E8E9C1 | 6.35 |
| `onDark` #FFFFFF | `premiumBadge` #566FD6 | 4.53 |
| `textPrimary` #2E3A3F | `neutralButton` #E3E7EA | 9.42 |

سفید روی `bgQuests` فقط ۳.۵۳ است (مناسب متن بزرگ ≥ ۳)؛ برای همه‌ی متن‌های آن صفحه `textDeep` به‌کار می‌رود. برچسب سفید روی `primaryGreen` ۲.۵۴ بود؛ دکمه‌ها برچسب تیره‌ی Bold می‌گیرند.

## ۳. کامپوننت‌ها (`core/widgets/`)
`ChunkyButton` (فشرده‌شدن ۸۰ms، لبه ۴dp→۰) · `RoundCard` · `ProgressPill` (عدد وسط) · `QuestTimeline` · `CountdownChip` · `PremiumBadge` · `HintButton` · `SpeechBubble` · `ItemTile` · `TabPills` · `BottomTabBar` · `SceneHeader`. با `disableAnimations` همه‌ی حرکت‌ها حذف می‌شوند.

## ۴. فونت
- متن: Vazirmatn (OFL) Regular و Bold.
- **تیتر و اعداد بزرگ: Baloo Bhaijaan 2 ExtraBold** (OFL، `assets/fonts/BalooBhaijaan2-ExtraBold.ttf`، نمونه‌ی ثابت وزن ۸۰۰ از فونت متغیر، subset: لاتین پایه + حروف و ارقام فارسی/عربی + نشانه‌گذاری). منبع و مجوز: مخزن `google/fonts` (`ofl/baloobhaijaan2`)، «Copyright 2019 The Baloo 2 Project Authors»؛ فایل مجوز در `app/assets/fonts/LICENSES/`. هیچ «Reserved Font Name» اعلام نشده و subset مجاز است. Vazirmatn پشتیبان (`fontFamilyFallback`) است.
- کاندیداها در [`docs/font-candidates.png`](font-candidates.png): Lalezar (OFL؛ بسیار سنگین و خوشنویسانه، حروف باریک‌تر)، Rakkas (OFL؛ سبک دستی، خوانایی کم در اندازه‌ی کوچک) و Baloo Bhaijaan 2 (گرد، پهن و ضخیم، خوانا؛ انتخاب‌شده). Lalezar و Rakkas ZWNJ ندارند.
- حجم کل فونت‌ها ≈ ۱۹۵KB (بودجه ۳۵۰KB).
- مجوز هر فایل از مخزن رسمی خوانده شد؛ **راستی‌آزمایی** بعدی: مالک می‌تواند OFL را در بازبینی حقوقی تأیید کند.

## ۵. تفاوت‌های عمدی با مرجع
RTL (جهت‌ها آینه می‌شوند)؛ حذف دوستان/جامعه/هدیه اشتراک/فروشگاه کالا؛ نام‌ها و متن‌ها اورجینال فارسی؛ گربه به‌جای پرنده؛ فروشنده‌ی اورجینال؛ بدون ادعای آماری در بنر اشتراک؛ مراحل رشد `kitten/young/adult`؛ آیکون‌ها فعلاً Material رنگی در دایره (placeholder تا آرت نهایی)؛ مرتب‌سازی اهداف فقط در «اهداف من» (نه روی کارت‌های خانه)؛ تب دسته‌ی پیشنهادها بالای فهرست؛ هدر فروشگاه قهوه‌ای؛ جزئیات هر صفحه در `docs/visual-diff/README.md`.

## ۶. وضعیت پیاده‌سازی و تفاوت‌ها (پرامپت 22)
- پس‌زمینه‌ها دقیقاً مقدار مرجع‌اند و AA (۴.۵:۱) با رنگ متن حاصل می‌شود (§۲)؛ آزمون `theme_test.dart` همه جفت‌ها را می‌سنجد و `no_hardcoded_colors_test.dart` رنگ خارج از tokens را رد می‌کند.
- ناوبری: ۵ تب (`AppShell`)، منو، `/goals/*` و redirect از `/habits/*` پیاده شد. مرتب‌سازی با کشیدن در صفحه «اهداف من» است (نه روی کارت‌های خانه).
- آنبوردینگ ۱۱ گام، `GoalRecommender`، مأموریت‌ها، فروشگاه چرخشی، کیف، پروفایل/کشفیات، حالت استراحت و تمرین‌های تب‌دار پیاده شدند. پاسخ سؤال «آرامش» معکوس ذخیره می‌شود.
- صدای راهنمای تمرین هنوز ساخته نشده (سوییچ خاموش و غیرفعال).
- دایره‌ی `SceneHeader` و گربه/اکسسوری‌ها placeholder کد-محورند. golden ۱۵ صفحه و مقایسه با مرجع در پرامپت 23 انجام شد (`docs/visual-diff/`)؛ علاوه بر آن تست overflow/semantics در مقیاس ۱.۰ و ۱.۳ برای همه‌ی صفحات جدید وجود دارد.
