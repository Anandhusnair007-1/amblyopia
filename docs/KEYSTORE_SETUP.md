# AmbyoAI Release Keystore Setup

## First Time Setup

Run this command to create the keystore:

```bash
keytool -genkey -v \
  -keystore android/ambyoai-release.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias ambyoai
```

Answer the prompts:

- **First/last name:** Your name
- **Organization unit:** Amrita School of Computing
- **Organization:** Amrita University
- **City:** Coimbatore
- **State:** Tamil Nadu
- **Country code:** IN

Then create `android/key.properties` (copy from `android/key.properties.template`):

```
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=ambyoai
storeFile=../ambyoai-release.jks
```

## IMPORTANT

- Keep `ambyoai-release.jks` safe.
- Keep `key.properties` safe.
- **NEVER** commit either to git.
- Back up **BOTH** files.
- If lost: you cannot update the app on Play Store or for users who already have it installed.

## Build Signed APK

```bash
flutter build apk --release --obfuscate --split-debug-info=debug/
```

## Build Without Keystore (testing)

Remove or rename `key.properties` and build. The build will use the debug keystore automatically. The APK is installable on a test device but **cannot** be distributed (e.g. Play Store).

## Install on device

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```
