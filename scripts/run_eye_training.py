#!/usr/bin/env python3
"""
End-to-end training runner for eye.ipynb dataset.

Creates a timestamped run folder under `amblyopia-main/eye_runs/` and saves:
- cleaned CSV snapshot
- image manifest (found/missing)
- copied images (if found)
- train/val/test splits
- metrics JSON, confusion matrix, and final model

Designed to work even when image filenames in the CSV do not match on-disk names
(e.g. CSV has eye_110.jpg while disk has eye_000110.jpg).
"""

from __future__ import annotations

import json
import os
import re
import shutil
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
CSV_DEFAULT = ROOT / "Image_Summary_With_Embedded_Images1(Cropped Results).csv"


@dataclass
class RunPaths:
    run_dir: Path
    artifacts: Path
    images: Path
    models: Path
    reports: Path


def make_run_paths() -> RunPaths:
    run_root = ROOT / "eye_runs"
    run_id = datetime.now().strftime("run-%Y%m%d-%H%M%S")
    run_dir = run_root / run_id
    artifacts = run_dir / "artifacts"
    images = run_dir / "images"
    models = run_dir / "models"
    reports = run_dir / "reports"
    for p in (run_root, run_dir, artifacts, images, models, reports):
        p.mkdir(parents=True, exist_ok=True)
    return RunPaths(run_dir, artifacts, images, models, reports)


def read_and_clean_csv(csv_path: Path) -> pd.DataFrame:
    df = pd.read_csv(
        csv_path,
        encoding="latin1",
        engine="python",
        sep=",",
        quotechar='"',
        skip_blank_lines=True,
        on_bad_lines="skip",
    )
    df.columns = [str(c).strip() for c in df.columns]
    df = df.dropna(how="all")
    first_col = df.columns[0]
    df = df.dropna(subset=[first_col])

    for col in [
        "Original File",
        "Cropped Eye Image",
        "Text in Image",
        "EYE",
        "AGE",
        "SEX",
        "CR ( DEGREE )",
        "PCT/ MKT IN PD",
    ]:
        if col not in df.columns:
            df[col] = None

    img_pat = re.compile(r"(?i)\beye_\d+\.(jpg|jpeg|png)\b")
    orig_pat = re.compile(r"(?i).+?\.(jpg|jpeg|png)")

    orig_raw = df["Original File"].astype(str)
    cropped_from_orig = orig_raw.apply(lambda s: (img_pat.search(s).group(0) if img_pat.search(s) else None))
    original_photo = orig_raw.apply(lambda s: (orig_pat.search(s).group(0).strip() if orig_pat.search(s) else s.strip()))

    if df["Cropped Eye Image"].isna().mean() > 0.8:
        df["Cropped Eye Image"] = cropped_from_orig
    df["Original File"] = original_photo

    image_file = df["Cropped Eye Image"].astype(str)
    image_file = image_file.where(~df["Cropped Eye Image"].isna(), cropped_from_orig)
    df["image_file"] = image_file

    for c in ["Original File", "Cropped Eye Image", "image_file", "EYE", "SEX"]:
        df[c] = df[c].astype(str).str.strip().replace({"nan": None, "None": None, "": None})

    return df


def extract_diagnosis(text: object) -> str:
    if text is None or (isinstance(text, float) and np.isnan(text)):
        return "Normal"
    t = str(text).upper()
    if "XT" in t:
        return "XT"
    if "ET" in t:
        return "ET"
    if "HT" in t or "HYPER" in t:
        return "HT"
    return "Normal"


def resolve_images(df: pd.DataFrame, img_roots: list[Path]):
    expected = [x for x in df["image_file"].dropna().astype(str).tolist() if x.strip()]
    expected = sorted(set(expected))
    eye_pat = re.compile(r"(?i)^eye_(\d+)\.(jpg|jpeg|png)$")

    def resolve_one(fname: str):
        fname = str(fname).strip()
        if not fname:
            return None, "empty"
        for root in img_roots:
            p = root / fname
            if p.exists() and p.is_file():
                return p, "exact"
        m = eye_pat.match(fname)
        if m:
            num = int(m.group(1))
            for ext in ("jpg", "jpeg", "png"):
                alt = f"eye_{num:06d}.{ext}"
                for root in img_roots:
                    p = root / alt
                    if p.exists() and p.is_file():
                        return p, f"padded:{alt}"
        return None, "not_found"

    resolved = {}
    missing = []
    for fname in expected:
        p, note = resolve_one(fname)
        if p is not None:
            resolved[fname] = {"src": str(p), "note": note}
        else:
            missing.append(fname)

    return expected, resolved, missing


def main():
    paths = make_run_paths()

    csv_path = Path(os.environ.get("EYE_CSV", str(CSV_DEFAULT)))
    if not csv_path.exists():
        raise SystemExit(f"CSV not found: {csv_path}")

    # Candidate image roots
    img_roots = []
    if "EYE_IMG_DIR" in os.environ:
        img_roots.append(Path(os.environ["EYE_IMG_DIR"]))
    img_roots.extend(
        [
            csv_path.parent / "images",
            ROOT / "et_doctor_review_pack" / "images",
        ]
    )
    img_roots = [p for p in img_roots if p.exists() and p.is_dir()]

    df = read_and_clean_csv(csv_path)
    df["diagnosis"] = df["Text in Image"].apply(extract_diagnosis)

    # Save dataset snapshots
    df.to_csv(paths.artifacts / "cleaned_dataset.csv", index=False)
    shutil.copy2(csv_path, paths.artifacts / csv_path.name)

    expected, resolved, missing = resolve_images(df, img_roots)

    manifest = {
        "csv_path": str(csv_path),
        "run_dir": str(paths.run_dir),
        "img_roots_checked": [str(p) for p in img_roots],
        "expected_images": len(expected),
        "found_images": len(resolved),
        "missing_images": len(missing),
        "missing_sample": missing[:25],
        "resolved_sample": {k: resolved[k] for k in list(resolved.keys())[:10]},
    }
    (paths.artifacts / "image_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print(json.dumps({k: manifest[k] for k in ["expected_images", "found_images", "missing_images"]}, indent=2))

    if len(resolved) < 40:
        print(
            "\nWARNING: very few images were found. Training can run but results will not be reliable.\n"
            "Add the full cropped-image dataset (eye_1.jpg .. eye_703.jpg or eye_000001.jpg ..) into one of the image roots\n"
            "and re-run.\n"
        )

    # Copy images into run folder (expected filename)
    for fname, meta in resolved.items():
        src = Path(meta["src"])
        dst = paths.images / fname
        if not dst.exists():
            shutil.copy2(src, dst)

    # If no images were found, we cannot train anything.
    if len(resolved) == 0:
        raise SystemExit("No images found; cannot train.")

    # We intentionally prefer a lightweight sklearn baseline by default (works on any machine).
    # A deep CNN can be added later once tensorflow is available.
    from PIL import Image  # type: ignore
    from sklearn.metrics import accuracy_score, classification_report, confusion_matrix, f1_score  # type: ignore
    from sklearn.model_selection import train_test_split  # type: ignore
    from sklearn.pipeline import make_pipeline  # type: ignore
    from sklearn.preprocessing import StandardScaler  # type: ignore
    from sklearn.linear_model import LogisticRegression  # type: ignore
    from sklearn.svm import LinearSVC  # type: ignore
    from sklearn.ensemble import RandomForestClassifier  # type: ignore

    # Build dataset arrays
    full_label_map = {"Normal": 0, "XT": 1, "ET": 2, "HT": 3}
    full_class_names = list(full_label_map.keys())
    img_dir = paths.images
    img_size = (128, 128)  # smaller for fast baselines

    rows = df.dropna(subset=["image_file", "diagnosis"]).copy()
    rows = rows[rows["image_file"].isin(resolved.keys())].copy()

    def read_img(p: Path):
        try:
            im = Image.open(p).convert("RGB")
            im = im.resize(img_size)
            return np.asarray(im, dtype=np.float32) / 255.0
        except Exception:
            return None

    X_list, y_list = [], []
    for _, r in rows.iterrows():
        fname = str(r["image_file"])
        p = img_dir / fname
        img = read_img(p)
        if img is None:
            continue
        X_list.append(img)
        y_list.append(full_label_map.get(str(r["diagnosis"]).strip(), 0))

    X = np.array(X_list, dtype=np.float32)
    y = np.array(y_list, dtype=np.int64)
    full_counts = np.bincount(y, minlength=len(full_label_map))
    print("Training set from found images:", X.shape, "label_counts:", full_counts)

    # If some classes are missing, we cannot train a multi-class model for them.
    present = [i for i, c in enumerate(full_counts) if c > 0]
    if len(present) < 2:
        raise SystemExit(
            "Only one diagnosis class is present in the found images; cannot train a classifier. "
            "Add more labeled images for other classes and re-run."
        )

    if len(present) != len(full_label_map):
        print(
            "WARNING: Some classes have 0 samples in the found images. "
            "Training will run only on present classes:",
            [full_class_names[i] for i in present],
        )

    # Remap labels to contiguous [0..k-1] for present classes
    remap = {old: new for new, old in enumerate(present)}
    inv_remap = {v: k for k, v in remap.items()}
    y = np.array([remap[v] for v in y], dtype=np.int64)
    class_names = [full_class_names[i] for i in present]

    # With tiny datasets, a train/val/test stratified split can fail.
    # Prefer cross-validation for model selection and only train a final model at the end.
    np.save(paths.artifacts / "X_all.npy", X)
    np.save(paths.artifacts / "y_all.npy", y)

    # Flatten images for classic ML baselines
    X_f = X.reshape((X.shape[0], -1))

    candidates = {
        "LogReg": make_pipeline(StandardScaler(with_mean=False), LogisticRegression(max_iter=2000)),
        "LinearSVM": make_pipeline(StandardScaler(with_mean=False), LinearSVC()),
        "RandomForest": RandomForestClassifier(n_estimators=300, random_state=42),
    }

    from sklearn.model_selection import StratifiedKFold, cross_val_predict, cross_validate  # type: ignore

    counts = np.bincount(y, minlength=len(class_names))
    min_count = int(np.min(counts))
    n_splits = 2 if min_count >= 2 else 0
    if n_splits < 2:
        raise SystemExit(
            "Not enough labeled images per class to run stratified CV. "
            f"Class counts: {counts.tolist()}. Add more images per class and re-run."
        )

    cv = StratifiedKFold(n_splits=n_splits, shuffle=True, random_state=42)

    all_metrics = []
    fitted = {}
    for name, clf in candidates.items():
        print("\n=== training", name, "===")
        scores = cross_validate(
            clf,
            X_f,
            y,
            cv=cv,
            scoring={"macro_f1": "f1_macro", "acc": "accuracy"},
            return_train_score=False,
        )
        met = {
            "model": name,
            "cv_macro_f1_mean": float(np.mean(scores["test_macro_f1"])),
            "cv_macro_f1_std": float(np.std(scores["test_macro_f1"])),
            "cv_accuracy_mean": float(np.mean(scores["test_acc"])),
            "cv_accuracy_std": float(np.std(scores["test_acc"])),
            "cv_splits": n_splits,
        }
        all_metrics.append(met)
        (paths.artifacts / f"metrics.{name}.json").write_text(json.dumps(met, indent=2), encoding="utf-8")

    best = sorted(all_metrics, key=lambda r: r["cv_macro_f1_mean"], reverse=True)[0]
    best_name = best["model"]
    best_model = candidates[best_name]

    # CV predictions for confusion matrix / report
    cv_pred = cross_val_predict(best_model, X_f, y, cv=cv)
    report = classification_report(y, cv_pred, target_names=class_names, output_dict=True)
    cm = confusion_matrix(y, cv_pred)

    (paths.artifacts / "best_model_selection.json").write_text(
        json.dumps(
            {"best_model": best_name, "best_cv_macro_f1_mean": best["cv_macro_f1_mean"], "all": all_metrics},
            indent=2,
        ),
        encoding="utf-8",
    )
    (paths.artifacts / f"classification_report.{best_name}.json").write_text(
        json.dumps(report, indent=2), encoding="utf-8"
    )
    np.save(paths.artifacts / f"confusion_matrix.{best_name}.npy", cm)

    # Fit the best model on ALL data and save it
    import joblib  # type: ignore

    best_path = paths.models / f"best_model.{best_name}.joblib"
    best_model.fit(X_f, y)
    joblib.dump(best_model, best_path)

    print("\nBEST MODEL:", best_name, "cv_macro_f1_mean=", best["cv_macro_f1_mean"])
    print("Saved model:", best_path)
    print("Run dir:", paths.run_dir)
    (paths.artifacts / "label_map_used.json").write_text(
        json.dumps(
            {
                "trained_on_classes": class_names,
                "note": "Only classes present in the found images are trained. Provide full dataset for full multi-class.",
                "remap_old_to_new": remap,
                "remap_new_to_old": inv_remap,
            },
            indent=2,
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()

