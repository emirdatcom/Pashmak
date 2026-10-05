# گزارش عملکرد و حجم (پرامپت 15)

> **وضعیت صادقانه:** محیط ساخت این مخزن Android SDK، Gradle با دسترسی به مخزن‌های ماون و دستگاه مرجع نداشت. بنابراین **APK ساخته نشده** و دو هدف زیر **اندازه‌گیری نشده‌اند**؛ فقط آنچه از روی منابع قابل‌اندازه‌گیری است ثبت شده. این گزارش را باید روی CI/دستگاه واقعی پر کرد (دستورها پایین).

## اهداف (سند 20 §12 و پرامپت 15)
| هدف | وضعیت |
|---|---|
| APK arm64 هر flavor < 15MB | **اندازه‌گیری نشده** |
| شروع سرد < 2s روی دستگاه مرجع | **اندازه‌گیری نشده** |
| `textScale=1.3` بدون overflow | تست widget سبز (home، آمار، تنظیمات، چک‌این، «داده‌های تو»، ۴ مرحله‌ی آنبوردینگ؛ تم روشن و تیره) |

## آنچه اندازه‌گیری شد (assets و وابستگی‌ها)
| مورد | حجم |
|---|---|
| `assets/fonts` (Vazirmatn Regular + Bold + Baloo Bhaijaan 2 ExtraBold، subset) | ≈۲۰۰KB |
| `assets/content` (۷ pack) | ۶۴KB |
| `assets/config` | ۸KB |
| تصاویر گربه (WebP) | هنوز نیست؛ `StaticCatRenderer` با placeholder رسم‌شده (CustomPainter) کار می‌کند |

- وابستگی‌های بلااستفاده حذف شدند: `cupertino_icons`، `intl` (مستقیم؛ `flutter_localizations` خودش آن را می‌آورد).
- `sqlite3` به‌صورت hook با SQLCipher برای اندروید ساخته می‌شود (`pubspec.yaml → hooks.user_defines`)؛ **حجم کتابخانه‌ی native آن اندازه‌گیری نشده** و محتمل‌ترین سهم بزرگ APK است.
- کتابخانه‌های بازار فقط در flavor خودشان لینک می‌شوند (`bazaarImplementation` / `myketImplementation`).
- سرویس‌های غیرضروری lazy هستند (providerهای Riverpod فقط با اولین `watch`)؛ زمان‌بندی نوتیف، outbox و refresh entitlement بعد از اولین فریم از `HomeScreen._onOpen` اجرا می‌شوند.

## دستورهای اندازه‌گیری (باید اجرا شوند)
```bash
cd app
flutter build apk --release --flavor bazaar --target-platform android-arm64 --analyze-size -t lib/main_bazaar.dart
flutter build apk --release --flavor myket  --target-platform android-arm64 --analyze-size -t lib/main_myket.dart
ls -l build/app/outputs/flutter-apk/*.apk
# شروع سرد روی دستگاه مرجع
adb shell am start -S -W -n <applicationId>/.MainActivity   # عدد TotalTime
```
اگر APK از ۱۵MB گذشت: ابتدا اندازه‌ی SQLCipher و فونت‌ها، سپس `--split-debug-info` و `--obfuscate`، و حذف ABIهای غیر arm64 را بررسی کنید.
