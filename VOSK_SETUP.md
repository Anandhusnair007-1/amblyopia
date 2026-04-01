# Vosk Model Setup Guide

## Download Models

Visit: https://alphacephei.com/vosk/models

Download these 4 models:

1. English (small):
   vosk-model-small-en-us-0.15
   Rename folder to: vosk-en
   Place at: assets/vosk/vosk-en/

2. Malayalam:
   vosk-model-ml-0.42
   Rename folder to: vosk-ml
   Place at: assets/vosk/vosk-ml/

3. Hindi:
   vosk-model-small-hi-0.22
   Rename folder to: vosk-hi
   Place at: assets/vosk/vosk-hi/

4. Tamil:
   vosk-model-small-ta-0.42
   Rename folder to: vosk-ta
   Place at: assets/vosk/vosk-ta/

## Required Files Per Model
Each folder must contain:
- am/final.mdl
- conf/mfcc.conf
- conf/model.conf
- graph/HCLG.fst
- graph/words.txt
- ivector/final.ie
- ivector/final.mat
- ivector/splice.conf

## Add to pubspec.yaml assets
  - assets/vosk/vosk-en/
  - assets/vosk/vosk-ml/
  - assets/vosk/vosk-hi/
  - assets/vosk/vosk-ta/

## Language Support

| Language   | Engine        | Status          |
|-----------|----------------|-----------------|
| English   | Vosk offline   | Ready           |
| Hindi     | Vosk offline   | Ready           |
| Malayalam | Device STT     | Auto fallback   |
| Tamil     | Device STT     | Auto fallback   |

Malayalam and Tamil Vosk models are not available on alphacephei. The app automatically uses Android's built-in speech recognition for these languages. This works offline on Android 10+ devices.

If Malayalam/Tamil Vosk models become available in future:

1. Download model zip
2. Extract to `assets/vosk/vosk-ml/` or `assets/vosk/vosk-ta/`
3. Update `_getVoskModelPath()` in `lib/features/offline/vosk_service.dart` to add `'ml'` and `'ta'` cases.

