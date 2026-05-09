import os
import json
import pandas as pd
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models, applications, callbacks, optimizers
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix, balanced_accuracy_score, precision_recall_fscore_support
import matplotlib.pyplot as plt
import seaborn as sns

# Config
DATA_DIR = 'ambyo_dataset_clean'
LABELS_CSV = os.path.join(DATA_DIR, 'verified_training_labels.csv')
MODEL_OUT_DIR = 'backend/models/deviation_v0_2_debug'
IMG_SIZE = (224, 224)
BATCH_SIZE = 16
CLASS_MAP = {'XT': 0, 'ET': 1}
REVERSE_MAP = {0: 'XT', 1: 'ET'}

os.makedirs(MODEL_OUT_DIR, exist_ok=True)

def train_deviation_debug():
    if not os.path.exists(LABELS_CSV):
        print("Error: Verified labels missing.")
        return

    df = pd.read_csv(LABELS_CSV)
    df = df[df['doctor_verified_deviation_type'].isin(CLASS_MAP.keys())]
    
    val_counts = df['doctor_verified_deviation_type'].value_counts()
    majority_class = val_counts.idxmax()
    baseline_acc = val_counts.max() / len(df)
    print(f"\n--- Dataset Analysis ---")
    print(f"Majority Baseline: {baseline_acc:.4f} ({majority_class})")

    # Split
    unique_groups = df['original_file'].unique()
    train_groups, temp_groups = train_test_split(unique_groups, test_size=0.3, random_state=42)
    val_groups, test_groups = train_test_split(temp_groups, test_size=0.5, random_state=42)
    
    train_df = df[df['original_file'].isin(train_groups)].copy()
    val_df = df[df['original_file'].isin(val_groups)].copy()
    test_df = df[df['original_file'].isin(test_groups)].copy()

    # Oversampling ET (Class 1) to match XT (Class 0)
    et_df = train_df[train_df['doctor_verified_deviation_type'] == 'ET']
    xt_df = train_df[train_df['doctor_verified_deviation_type'] == 'XT']
    if len(et_df) < len(xt_df):
        upsampled_et = et_df.sample(len(xt_df), replace=True, random_state=42)
        train_df = pd.concat([xt_df, upsampled_et])
    print(f"Balanced Training Set: {train_df['doctor_verified_deviation_type'].value_counts().to_dict()}")

    def get_path(x): return os.path.join(DATA_DIR, 'images', os.path.basename(str(x)))
    for d in [train_df, val_df, test_df]: d['frozen_path'] = d['image_path'].apply(get_path)

    # 3. Preprocessing: EfficientNetB0 handles [0, 255] internally. 
    train_datagen = tf.keras.preprocessing.image.ImageDataGenerator(
        rotation_range=15, width_shift_range=0.15, height_shift_range=0.15,
        shear_range=0.15, zoom_range=0.15, horizontal_flip=True, fill_mode='nearest',
        brightness_range=[0.8, 1.2] # Critical for handling variable lighting in eye photos
    )
    val_test_datagen = tf.keras.preprocessing.image.ImageDataGenerator()

    train_gen = train_datagen.flow_from_dataframe(
        train_df, x_col='frozen_path', y_col='doctor_verified_deviation_type',
        target_size=IMG_SIZE, batch_size=BATCH_SIZE, class_mode='binary', classes=list(CLASS_MAP.keys())
    )
    val_gen = val_test_datagen.flow_from_dataframe(
        val_df, x_col='frozen_path', y_col='doctor_verified_deviation_type',
        target_size=IMG_SIZE, batch_size=BATCH_SIZE, class_mode='binary', classes=list(CLASS_MAP.keys())
    )
    test_gen = val_test_datagen.flow_from_dataframe(
        test_df, x_col='frozen_path', y_col='doctor_verified_deviation_type',
        target_size=IMG_SIZE, batch_size=BATCH_SIZE, class_mode='binary', classes=list(CLASS_MAP.keys()), shuffle=False
    )

    # Model - Upgrade to EfficientNetB0 for better feature extraction
    base_model = applications.EfficientNetB0(input_shape=(*IMG_SIZE, 3), include_top=False, weights='imagenet')
    
    # Fine-tuning: Unfreeze some layers
    base_model.trainable = True
    # Freeze everything except the top 40 layers
    for layer in base_model.layers[:-40]:
        layer.trainable = False

    model = models.Sequential([
        base_model,
        layers.GlobalAveragePooling2D(),
        layers.BatchNormalization(),
        layers.Dropout(0.3),
        layers.Dense(256, activation='relu', kernel_regularizer=tf.keras.regularizers.l2(0.01)),
        layers.BatchNormalization(),
        layers.Dropout(0.5),
        layers.Dense(1, activation='sigmoid')
    ])

    model.compile(
        optimizer=optimizers.Adam(1e-4), # Higher starting LR
        loss='binary_crossentropy',
        metrics=['accuracy', tf.keras.metrics.AUC(name='auc')]
    )

    stop = callbacks.EarlyStopping(monitor='val_auc', mode='max', patience=15, restore_best_weights=True)
    reduce_lr = callbacks.ReduceLROnPlateau(monitor='val_auc', mode='max', factor=0.5, patience=5, min_lr=1e-6, verbose=1)
    
    print("\n--- Training (EfficientNetB0 Fine-tuning) ---")
    model.fit(train_gen, validation_data=val_gen, epochs=60, callbacks=[stop, reduce_lr])

    # Final Evaluation
    preds = model.predict(test_gen).flatten()
    y_true = test_gen.classes
    
    thresholds = [0.30, 0.40, 0.50, 0.60, 0.70]
    thresh_results = []
    for t in thresholds:
        y_pred = (preds >= t).astype(int)
        b_acc = balanced_accuracy_score(y_true, y_pred)
        p, r, f, _ = precision_recall_fscore_support(y_true, y_pred, average=None, labels=[0, 1], zero_division=0)
        thresh_results.append({"threshold": t, "XT_recall": r[0], "XT_precision": p[0], "ET_recall": r[1], "ET_precision": p[1], "balanced_accuracy": b_acc, "macro_f1": np.mean(f)})

    thresh_df = pd.DataFrame(thresh_results)
    thresh_df.to_csv(os.path.join(MODEL_OUT_DIR, 'threshold_report.csv'), index=False)
    print("\n--- Threshold Analysis ---")
    print(thresh_df.to_string(index=False))

    final_preds = (preds >= 0.5).astype(int)
    unique_preds = np.unique(final_preds)
    passed = (len(unique_preds) > 1)

    if not passed:
        print(f"\n!!! MODEL FAILED: single-class prediction collapse !!! Predicted: {REVERSE_MAP[unique_preds[0]]}")
    else:
        print("\nModel passed diversity check.")

    model.save(os.path.join(MODEL_OUT_DIR, 'model.keras'))
    with open(os.path.join(MODEL_OUT_DIR, 'labels.json'), 'w') as f: json.dump(CLASS_MAP, f)
    report = classification_report(y_true, final_preds, target_names=['XT', 'ET'], output_dict=True, zero_division=0)
    with open(os.path.join(MODEL_OUT_DIR, 'classification_report.json'), 'w') as f: json.dump(report, f, indent=2)
    
    cm = confusion_matrix(y_true, final_preds)
    plt.figure(figsize=(6,5)); sns.heatmap(cm, annot=True, fmt='d', xticklabels=['XT', 'ET'], yticklabels=['XT', 'ET'], cmap='Oranges'); plt.savefig(os.path.join(MODEL_OUT_DIR, 'confusion_matrix.png'))

    test_df['score'] = preds
    test_df['pred'] = [REVERSE_MAP[p] for p in final_preds]
    test_df['true'] = [REVERSE_MAP[t] for t in y_true]
    
    print(f"\nFinal Summary:")
    print(f"XT Samples: {val_counts['XT']} | ET Samples: {val_counts['ET']}")
    print(f"ET Recall (0.5): {report['ET']['recall']:.4f} | ET Precision (0.5): {report['ET']['precision']:.4f}")
    print(f"Baseline Accuracy: {baseline_acc:.4f} | Status: {'PASSED' if passed else 'FAILED'}")

if __name__ == "__main__":
    train_deviation_debug()
