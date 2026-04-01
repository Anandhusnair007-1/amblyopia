# AmbyoAI Model Training Guide

## Option A: Use Existing Weights
Run backend training pipeline:

```
cd backend
python training/train.py --mode synthetic --samples 1000
```

This creates a synthetic training set and trains EfficientNet-B0.
Output: assets/models/ambyo_model.tflite

## Option B: Manual Training
1. Collect labeled screening data via doctor portal diagnosis labels.
2. Wait for 50+ labeled samples (backend auto-trains at 2AM).
3. Model auto-downloads to devices via OTA update system.

## Placeholder Model
Until a real model is trained, clinical fallback rules are active.
The app works correctly without the .tflite file using rule-based risk assessment.

## Model Input Format
10 float values:
[visual_acuity, gaze_deviation, prism_diopter, suppression_level, depth_score, stereo_score,
 color_score, red_reflex, patient_age, hirschberg_deviation]

## Model Output
4-class softmax:
[normal, mild, moderate, severe]

