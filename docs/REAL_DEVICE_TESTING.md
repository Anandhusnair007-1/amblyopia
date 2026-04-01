# Real Device Testing Checklist

Use this when testing the Ambyo/Drishti app on a physical Android device.

## Prerequisites

1. **TFLite model:** Ensure `assets/models/ambyo_model.tflite` exists (run `scripts/train_placeholder_model.py` from repo root). Without it, the app uses fallback rules (works but less accurate).
2. **Connect Android phone via USB**
3. **Enable Developer Options** (Settings → About phone → tap Build number 7×)
4. **Enable USB debugging** (Settings → Developer options)
5. **Verify device:** `flutter devices` — your phone should appear

## Build & install

```bash
# Clean and rebuild
cd ~/projects/drishti_ai
flutter clean
flutter pub get
flutter build apk --release

# APK location
# build/app/outputs/flutter-apk/app-release.apk

# Install on connected Android phone
adb install -r build/app/outputs/flutter-apk/app-release.apk

# If adb not found
# sudo apt install android-tools-adb

# If phone not found: enable USB debugging (Settings → About → Build number 7× → Developer options → USB debugging ON), reconnect cable
adb devices
```

**Or run directly:** `flutter run --release`

---

## FLOW 1 — Patient offline (WiFi OFF)

Turn WiFi off. Install APK and run through:

| # | Step | ✓ |
|---|------|---|
| 1 | App opens → splash animation plays | ☐ |
| 2 | Onboarding: 3 slides shown | ☐ |
| 3 | Login → **Patient** role selected | ☐ |
| 4 | Enter any 10-digit phone number | ☐ |
| 5 | OTP screen → type **1 2 3 4** | ☐ |
| 6 | Patient home loads | ☐ |
| 7 | Stats show (0 tests, no history) | ☐ |
| 8 | 10 test cards visible | ☐ |
| 9 | **[Start Full Screening]** tapped | ☐ |

**Eye Scan**

| # | Step | ✓ |
|---|------|---|
| 10 | Camera activates (front) | ☐ |
| 11 | HUD overlay visible | ☐ |
| 12 | Corner brackets animate | ☐ |
| 13 | Face detected → brackets contract | ☐ |
| 14 | "IRIS LOCKED" status shows | ☐ |
| 15 | Auto-advances to Gaze test | ☐ |

**Gaze test**

| # | Step | ✓ |
|---|------|---|
| 16 | Amber dot moves to 9 positions | ☐ |
| 17 | Iris tracking follows dot | ☐ |
| 18 | 9 readings captured automatically | ☐ |
| 19 | Result card shows (Δ value) | ☐ |
| 20 | Auto-advances in 3s | ☐ |

**Hirschberg**

| # | Step | ✓ |
|---|------|---|
| 21 | Instructions shown | ☐ |
| 22 | Front camera activates | ☐ |
| 23 | Torch flashes briefly | ☐ |
| 24 | "Analyzing..." shown | ☐ |
| 25 | Result shows (mm displacement) | ☐ |
| 26 | Auto-advances | ☐ |

**Prism diopter**

| # | Step | ✓ |
|---|------|---|
| 27 | Calculation screen shows | ☐ |
| 28 | Δ = 100 × tan(θ) shown | ☐ |
| 29 | 3×3 direction grid shows values | ☐ |
| 30 | Auto-advances | ☐ |

**Red reflex**

| # | Step | ✓ |
|---|------|---|
| 31 | **Rear** camera activates | ☐ |
| 32 | Torch activates | ☐ |
| 33 | "Hold 30–40 cm from face" shown | ☐ |
| 34 | Flash captures image | ☐ |
| 35 | Result shows (Normal/Abnormal) | ☐ |
| 36 | Auto-advances | ☐ |

**Suppression (rivalry)**

| # | Step | ✓ |
|---|------|---|
| 37 | Red + blue stripe pattern visible | ☐ |
| 38 | "Reading 1 of 6" shows | ☐ |
| 39 | Mic icon pulses | ☐ |
| 40 | Say "horizontal" → H bubble appears | ☐ |
| 41 | Say "vertical" → V bubble appears | ☐ |
| 42 | Say "switching" → S bubble appears | ☐ |
| 43 | 6 readings complete | ☐ |
| 44 | Switch count shown | ☐ |
| 45 | Result badge shown | ☐ |
| 46 | Auto-advances | ☐ |

**Depth perception**

| # | Step | ✓ |
|---|------|---|
| 47 | Parallax image moves with head | ☐ |
| 48 | Mic listens for "front" or "back" | ☐ |
| 49 | 6 trials scored | ☐ |
| 50 | Grade shown (Excellent/Good etc) | ☐ |
| 51 | Auto-advances | ☐ |

**Titmus stereo**

| # | Step | ✓ |
|---|------|---|
| 52 | Fly image shows with parallax | ☐ |
| 53 | Mic listens for "yes" or "no" | ☐ |
| 54 | Animals shown → voice response | ☐ |
| 55 | Circles shown → voice response | ☐ |
| 56 | Arc-seconds score shown | ☐ |
| 57 | Auto-advances | ☐ |

**Lang stereo**

| # | Step | ✓ |
|---|------|---|
| 58 | Random dot pattern shows | ☐ |
| 59 | Mic listens for "star/car/cat" | ☐ |
| 60 | 3 patterns tested | ☐ |
| 61 | "Patterns detected X/3" shown | ☐ |
| 62 | Auto-advances | ☐ |

**Ishihara color**

| # | Step | ✓ |
|---|------|---|
| 63 | 8 colored plates shown one by one | ☐ |
| 64 | Mic listens for number | ☐ |
| 65 | "Heard: 8" (or number) flashes | ☐ |
| 66 | Score shown | ☐ |
| 67 | Auto-advances | ☐ |

**Snellen chart**

| # | Step | ✓ |
|---|------|---|
| 68 | Large letters displayed | ☐ |
| 69 | Gets smaller each line | ☐ |
| 70 | Mic listens for each letter | ☐ |
| 71 | Stops when 2 errors on line | ☐ |
| 72 | "6/9" or similar shown | ☐ |
| 73 | Auto-advances | ☐ |

**AI prediction**

| # | Step | ✓ |
|---|------|---|
| 74 | "Analyzing results..." shows | ☐ |
| 75 | TFLite model runs on device | ☐ |
| 76 | Normal/Mild/Moderate/Severe badge | ☐ |
| 77 | Risk score (0.xx) shown | ☐ |

**PDF & report**

| # | Step | ✓ |
|---|------|---|
| 78 | "Generating report..." shows | ☐ |
| 79 | PDF created on device | ☐ |
| 80 | 8-page report with all results | ☐ |
| 81 | Preview opens automatically | ☐ |
| 82 | PDF renders correctly | ☐ |
| 83 | All 10 test results visible | ☐ |
| 84 | Patient name + date correct | ☐ |
| 85 | AI score shown | ☐ |
| 86 | **[Share]** button works | ☐ |
| 87 | **[Download]** saves to phone | ☐ |

---

## FLOW 2 — Individual test

| # | Step | ✓ |
|---|------|---|
| 1 | From patient home tap any test card | ☐ |
| 2 | Only that test runs | ☐ |
| 3 | Mini result sheet appears after | ☐ |
| 4 | History updates on home screen | ☐ |

---

## FLOW 3 — Urgent finding

| # | Step | ✓ |
|---|------|---|
| 1 | If any test shows critical finding | ☐ |
| 2 | Red urgent screen appears | ☐ |
| 3 | Critical findings listed | ☐ |
| 4 | **[Generate PDF]** works | ☐ |
| 5 | **[Continue Tests]** returns to flow | ☐ |

---

## FLOW 4 — WiFi on (sync test)

| # | Step | ✓ |
|---|------|---|
| 1 | Turn WiFi back on | ☐ |
| 2 | Green "Connected" flash shows | ☐ |
| 3 | Results sync to backend | ☐ |
| 4 | Start backend: `cd backend && docker compose up` | ☐ |
| 5 | Doctor login: **doctor** / **AmbyoDoc#9274!** | ☐ |
| 6 | Patient appears in doctor portal | ☐ |
| 7 | Report visible to doctor | ☐ |
| 8 | Doctor adds diagnosis notes | ☐ |

---

## TEST FLOW A–E (short form)

Same as above; Flow A = Patient full screening (summary table below for quick ref).

| # | Step | ✓ |
|---|------|---|
| 1 | App launches → Splash | ☐ |
| 2 | Onboarding 3 slides | ☐ |
| 3 | Login → Patient | ☐ |
| 4 | 10-digit phone → OTP **1234** | ☐ |
| 5 | Patient home + 10 test cards | ☐ |
| 6 | Full Screening → Eye Scan → … → PDF → Share | ☐ |

---

## After testing passes

1. **Fix device-specific issues** (camera resolution, voice accuracy, PDF layout, animation speed).
2. **Deploy backend** to a real server (e.g. AWS EC2, DigitalOcean, Amrita server, or ngrok for initial testing).
3. **Update baseUrl in app:**
   - `lib/features/doctor_portal/services/doctor_api_service.dart`: change `http://10.0.2.2:8000` to `https://your-server-ip:8000` (or your backend URL).
   - If sync uses a central URL, set `lib/core/constants/app_constants.dart` `baseUrl` to the same backend.
4. **Final release build:**
   ```bash
   flutter build apk --release --obfuscate --split-debug-info=debug/
   ```
5. **Send APK to Aravind Eye Hospital clinical team**; install on Android tablets; train staff on Patient, Worker, and Doctor workflows.
6. **Clinical validation:** screen 20–30 children in the first week; doctors add diagnosis labels; use labels for training pipeline and model improvement.

---

## Notes

- **OTP:** Use **1234** for any phone in dev/demo.
- **Doctor credentials:** **doctor** / **AmbyoDoc#9274!** (backend must be running for Flow C / Flow 4).
- **Release build:** Use `flutter run --release` or install `app-release.apk` for performance and camera behavior close to production.
