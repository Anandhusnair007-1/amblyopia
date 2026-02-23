# GitHub Repository Secrets Required

Go to: **Settings → Secrets and variables → Actions → New repository secret**

## Backend CI (`ci.yml`)

| Secret | Description | How to get |
|--------|-------------|------------|
| `CI_ENCRYPTION_KEY` | 32-char AES key for test runs | `openssl rand -hex 16` |

## Flutter Release Build (`flutter-ci.yml`)

| Secret | Description | How to get |
|--------|-------------|------------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded `.jks` keystore | `base64 -w0 keystore.jks` |
| `ANDROID_KEY_ALIAS` | Alias name in keystore | From `keytool -list -v -keystore keystore.jks` |
| `ANDROID_KEY_PASSWORD` | Key password | Set when creating keystore |
| `ANDROID_STORE_PASSWORD` | Keystore password | Set when creating keystore |

### Generate Android Keystore (one-time)
```bash
keytool -genkey -v \
  -keystore amblyopia-release.jks \
  -alias amblyopia \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -dname "CN=Aravind Eye Hospital, OU=Amblyopia Care, O=Aravind, L=Coimbatore, ST=Tamil Nadu, C=IN"

base64 -w0 amblyopia-release.jks | xclip -selection clipboard
# Paste as ANDROID_KEYSTORE_BASE64 secret
```

## Notifications (optional)

| Secret | Description |
|--------|-------------|
| `SLACK_WEBHOOK` | Slack incoming webhook URL for failure alerts |
