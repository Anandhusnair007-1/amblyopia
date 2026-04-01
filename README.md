# AmbyoAI — Smart Vision Screening

## AI-Powered Amblyopia Detection Using Smartphones

AmbyoAI is a fully offline, touchless, voice-driven amblyopia screening application built for community health workers, nurses, and Anganwadi centers. No physical equipment required. Runs entirely on a smartphone.

### Credits

- Developed by : Amrita School of Computing
- Clinical Partner : Aravind Eye Hospital
- Guided by : Dr. Prema Nedungadi, Dr. Subbulakshmi S
- Clinical Guidance : Clinical Ophthalmology Team, Aravind Eye Hospital, Coimbatore

## How to Use AmbyoAI

### 1. Prerequisites

- **Flutter SDK**: Install Flutter (Stable branch) from [flutter.dev](https://docs.flutter.dev/get-started/install).
- **Android Studio / Xcode**: For building to Android/iOS devices.
- **Physical Device**: Recommended for testing voice recognition and camera-based screening.

### 2. Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/Anandhusnair007-1/amblyopia.git
   cd amblyopia
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```

### 3. Voice Recognition (VOSK) Setup

To use the offline voice-driven screening:

1. Download VOSK models from [VOSK Models](https://alphacephei.com/vosk/models).
2. Place the English (small) model in `assets/vosk/vosk-en/`.
3. Place the Hindi (small) model in `assets/vosk/vosk-hi/`.
4. Ensure your `pubspec.yaml` includes these asset paths.

For more details, see [VOSK_SETUP.md](./VOSK_SETUP.md).

### 4. Running the App

1. Connect your device.
2. Run the application:
   ```bash
   flutter run
   ```

### 5. Features

- **Voice-Driven**: Use voice commands to interact with the screening process.
- **Offline Mode**: Operates without an internet connection once models are installed.
- **Touchless**: Designed for hygienic use in community health settings.
