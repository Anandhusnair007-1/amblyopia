# AmbyoAI Dataset - Template & Instructions

## ⚠️ Security Warning
This repository contains scripts for processing medical data. **NEVER** commit the following to source control:
- Raw Excel/XLSX files containing patient data.
- Extracted eye images (`ambyo_dataset_clean/images/`).
- `labels.csv` or any file containing PHI (Protected Health Information).
- Trained model files (`.h5`, `.tflite`).

## Dataset Overview
The scripts in `scripts/` are designed to process a pediatric amblyopia dataset.

### Expected Source
`Image_Summary_With_Embedded_Images1.xlsx` (not included in repo).

### Processing Steps
1. Place the source Excel file in the root directory.
2. Run `python3 scripts/extract_dataset.py` (or `scavenge_dataset.py` for corrupted files).
3. The cleaned, anonymized dataset will be generated in `ambyo_dataset_clean/`.

## Column Definitions (labels.csv)
- **image_id**: Anonymized ID (e.g., `eye_000001`)
- **image_path**: Relative path to the extracted image
- **deviation_type**: XT (Exotropia), ET (Esotropia), Ortho
- **age**: Patient age (numeric)
- **sex**: M / F
- **usable_for_training**: Boolean flag after PHI screening
- **audit_status**: `pending` (initial), `verified` (approved by doctor), `rejected` (bad data/mapping)
- **doctor_verified_deviation_type**: Ground truth label confirmed by a professional.

## Medical Audit Workflow
Before training any model, a qualified ophthalmologist must:
1. Open `ambyo_dataset_clean/labels.csv`.
2. Inspect the image corresponding to each row.
3. Fill in the `doctor_verified_*` columns.
4. Set `audit_status` to `verified` for all high-quality, correctly-mapped records.
5. The training script will ignore any records not marked as `verified`.

## Model Roadmap (Priority Order)
1.  **Image Quality Classifier**: `good`, `blurred`, `dark`, `bad_crop`, `reflection_issue`.
2.  **Eye Deviation Classifier**: `normal`, `XT`, `ET`, `vertical`, `palsy`.
3.  **Prism Diopter Regression**: For quantifying deviation magnitude.

## Training
The training script for the first model is located at `scripts/train_image_quality.py`.
It strictly requires `audit_status == 'verified'`.
