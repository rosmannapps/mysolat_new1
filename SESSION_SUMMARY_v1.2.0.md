# MySolat — Session Summary, v1.2.0 work

**Last updated:** 21 May 2026
**Status:** All features implemented & tested locally. Ready to bump version + submit to stores.

---

## ✅ What was shipped this session (all live in code, untested in production)

### 1. Year-long offline caching
- **`lib/services/prayer_times_service.dart`** — Added `prefetchYear()`, `getCacheHealth()`, `_markFreshness()`, `purgeOldCache()`, `CacheHealth` class
- App now caches 365 days of prayer times per zone on first load
- `fetchDay(forceRefresh: true)` lets pin tap force-skip cache
- Cache hygiene runs on app startup (purges entries >60 days)
- 14-day cooldown on year-prefetch prevents JAKIM hammering

### 2. Freshness indicator in UI
- **`lib/pages/waktu_solat_page.dart`** — Added `_cacheHealth` state, `_refreshCacheHealth()`, `_buildFreshnessLabel()`
- Bottom of screen shows: `Sumber: JAKIM • Dikemas kini X minit lalu`
- Turns orange with cloud-off icon when >7 days stale

### 3. Replaced NEGERI/BANDAR dropdowns with Lokasi Saya pin
- Single red location-pin (tappable) → auto-detect location
- Below pin: "Tekan pin untuk kemaskini lokasi" hint
- Detected town name displayed prominently (e.g. "Kepala Batas")
- Small subtitle showing JAKIM zone code (e.g. "(Zon: PNG01)")
- Tap pin → forces fresh JAKIM hit (resets freshness timer to 0)
- App auto-detects on launch; uses cached location instantly while GPS refreshes in background

### 4. Precise locality detection
- `_pickTownDisplayName()` now prefers `subLocality` over `locality`
- e.g., shows "Sungai Dua" instead of "Butterworth" when GPS supports it
- Android (Google data) typically more precise than iOS (Apple data)

### 5. JAKIM-provided Hijri date
- **`lib/models/prayer_times.dart`** + **`lib/models/monthly_prayer_entry.dart`** — Added `hijri` field
- JAKIM's official moon-sighted date used when available; algorithmic fallback otherwise
- `_formatJakimHijri()` parses "1447-12-03" → "3 Zulhijjah 1447"

### 6. Sokong MySolat donation card
- **`lib/pages/tetapan_page.dart`** — New `_SokongCard` widget between settings grid and tip card
- Heart icon, green theme, BM copy
- Opens donation page in external browser via `url_launcher` (`LaunchMode.externalApplication`)
- Apple/Google can't take a cut because payment processing happens entirely off-app

### 7. Donation page live on GitHub Pages
- URL: **https://rosmannapps.github.io/sokong/**
- Repo: github.com/rosmannapps/sokong
- Files: `index.html`, `duitnow-qr.png`
- Source folder: `donation-page/` in this project
- Shows: DuitNow QR (cropped Maybank QR), TouchNGo, Maybank Islamic, BM du'a closing

---

## 🐛 Bugs fixed in this session

- **Cari Zon Solat Saya — "No location permissions"** → Added `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION` to AndroidManifest.xml (user fixed pre-session)
- **Quran page null-check** → User fixed pre-session

---

## 🚢 To ship to stores (next session)

### Step 1: Bump version (3 places)
```yaml
# pubspec.yaml
version: 1.2.0+18
```
```xml
<!-- ios/Runner/Info.plist -->
<key>CFBundleShortVersionString</key>
<string>1.2.0</string>
<key>CFBundleVersion</key>
<string>18</string>
```

### Step 2: Release notes (Bahasa Malaysia)
```
• Aplikasi kini berfungsi tanpa internet — waktu solat disimpan untuk setahun penuh
• Antara muka baharu: tekan pin lokasi untuk waktu solat ikut tempat anda berada (cth. Kepala Batas, Sungai Dua)
• Tarikh Hijri kini mengikut tarikh rasmi JAKIM (cerapan anak bulan)
• Penunjuk baharu: lihat bila data terakhir dikemas kini
• Pilihan untuk menyokong pembangunan MySolat (Tetapan > Sokong MySolat)
• Peningkatan kestabilan dan pembetulan pepijat
```

### Step 3: Android build
```bash
cd /Users/rosmannmba/mysolat_new1
flutter clean
flutter pub get
flutter build appbundle
# Upload build/app/outputs/bundle/release/app-release.aab to Play Console
```

### Step 4: iOS build
```bash
# Open ios/Runner.xcworkspace in Xcode
# Verify Info.plist Bundle version is 18 (it's hardcoded — pubspec doesn't auto-sync)
# Product → Clean Build Folder
# Product → Archive
# Distribute App → App Store Connect → Upload
```

### Step 5: Submit for review on both stores
- Same flow as last release (1.1.0+16) — full walkthrough in earlier session if needed

---

## 🔮 Future architecture roadmap (after v1.2.0 ships)

1. **Firebase Crashlytics** — automatic crash reporting (~1-2 hours setup)
2. **Firebase Analytics** — see what users actually do (~2 hours setup + ongoing)
3. **Firebase Remote Config** — change app behavior without releasing updates (~2-3 hours)
4. **Google Geocoding API** (optional) — replace native geocoder for consistent iOS/Android precision. Free tier covers <10k calls/month. Worth implementing only if iOS precision becomes a real problem.

---

## 📌 Quick-reference URLs

- Donation page: https://rosmannapps.github.io/sokong/
- GitHub repo: https://github.com/rosmannapps/sokong
- Play Console: https://play.google.com/console
- App Store Connect: https://appstoreconnect.apple.com
