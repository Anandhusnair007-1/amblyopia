import os
import json
import pandas as pd
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models, applications, callbacks
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix, precision_recall_fscore_support
from sklearn.utils import class_weight
import matplotlib.pyplot as plt
import seaborn as sns
import shutil

# Config
np.random.seed(42)
tf.random.set_seed(42)

DATA_DIR = 'ambyo_dataset_v1'
IMAGE_DIR = os.path.join(DATA_DIR, 'images')
LABELS_CSV = os.path.join(DATA_DIR, 'verified_training_labels.csv')
MODEL_OUT_DIR = 'backend/models'
IMG_SIZE = (224, 224)
BATCH_SIZE = 16
INITIAL_EPOCHS = 10
FINE_TUNE_EPOCHS = 5

os.makedirs(MODEL_OUT_DIR, exist_ok=True)

def train_quality_model():
    if not os.path.exists(LABELS_CSV):
        print(f"Error: {LABELS_CSV} missing. Run create_frozen_v1.py first.")
        return

    df = pd.read_csv(LABELS_CSV)
    
    # 1. Filter for valid labels
    df = df[df['doctor_verified_quality'].notna()]
    unique_classes = sorted(df['doctor_verified_quality'].unique())
    print(f"Classes: {unique_classes}")

    # 2. Stratified Split (Avoiding original_file leakage)
    # Group by original_file if it exists
    if 'original_file' in df.columns:
        unique_groups = df[['original_file', 'doctor_verified_quality']].drop_duplicates()
        # Since stratification is on files, we use the first occurrence's quality for the group
        group_df = unique_groups.groupby('original_file').first().reset_index()
        
        train_groups, temp_groups = train_test_split(
            group_df['original_file'], test_size=0.3, 
            stratify=group_df['doctor_verified_quality'], random_state=42
        )
        val_groups, test_groups = train_test_split(
            temp_groups, test_size=0.5, 
            random_state=42 # smaller set, harder to stratify perfectly
        )
        
        train_df = df[df['original_file'].isin(train_groups)]
        val_df = df[df['original_file'].isin(val_groups)]
        test_df = df[df['original_file'].isin(test_groups)]
    else:
        train_df, temp_df = train_test_split(df, test_size=0.3, stratify=df['doctor_verified_quality'], random_state=42)
        val_df, test_df = train_test_split(temp_df, test_size=0.5, stratify=temp_df['doctor_verified_quality'], random_state=42)

    # Save manifest
    manifest = pd.concat([
        train_df.assign(split='train'),
        val_df.assign(split='val'),
        test_df.assign(split='test')
    ])
    manifest.to_csv(os.path.join(DATA_DIR, 'split_manifest.csv'), index=False)

    # 3. Data Generators
    train_datagen = tf.keras.preprocessing.image.ImageDataGenerator(
        rescale=1./255,
        rotation_range=15,
        zoom_range=0.1,
        brightness_range=[0.8, 1.2],
        horizontal_flip=True,
        fill_mode='nearest'
    )
    val_datagen = tf.keras.preprocessing.image.ImageDataGenerator(rescale=1./255)
    test_datagen = tf.keras.preprocessing.image.ImageDataGenerator(rescale=1./255)

    # Note: image_path in frozen v1 is just the filename
    train_df['frozen_path'] = train_df['image_path'].apply(lambda x: os.path.join(DATA_DIR, 'images', os.path.basename(x)))
    val_df['frozen_path'] = val_df['image_path'].apply(lambda x: os.path.join(DATA_DIR, 'images', os.path.basename(x)))
    test_df['frozen_path'] = test_df['image_path'].apply(lambda x: os.path.join(DATA_DIR, 'images', os.path.basename(x)))

    train_gen = train_datagen.flow_from_dataframe(
        train_df, x_col='frozen_path', y_col='doctor_verified_quality',
        target_size=IMG_SIZE, batch_size=BATCH_SIZE, class_mode='categorical'
    )
    val_gen = val_datagen.flow_from_dataframe(
        val_df, x_col='frozen_path', y_col='doctor_verified_quality',
        target_size=IMG_SIZE, batch_size=BATCH_SIZE, class_mode='categorical'
    )
    test_gen = test_datagen.flow_from_dataframe(
        test_df, x_col='frozen_path', y_col='doctor_verified_quality',
        target_size=IMG_SIZE, batch_size=BATCH_SIZE, class_mode='categorical', shuffle=False
    )

    # 4. Model (MobileNetV3Small)
    base_model = applications.MobileNetV3Small(input_shape=(*IMG_SIZE, 3), include_top=False, weights='imagenet')
    base_model.trainable = False

    model = models.Sequential([
        base_model,
        layers.GlobalAveragePooling2D(),
        layers.Dense(128, activation='relu'),
        layers.Dropout(0.3),
        layers.Dense(len(unique_classes), activation='softmax')
    ])

    model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])

    # 5. Training
    stop = callbacks.EarlyStopping(monitor='val_loss', patience=3, restore_best_weights=True)
    
    print("\n--- Initial Training ---")
    model.fit(train_gen, validation_data=val_gen, epochs=INITIAL_EPOCHS, callbacks=[stop])

    print("\n--- Fine-Tuning ---")
    base_model.trainable = True
    for layer in base_model.layers[:-20]:
        layer.trainable = False
    
    model.compile(optimizer=tf.keras.optimizers.Adam(1e-5), loss='categorical_crossentropy', metrics=['accuracy'])
    model.fit(train_gen, validation_data=val_gen, epochs=FINE_TUNE_EPOCHS, callbacks=[stop])

    # 6. Evaluation
    print("\n--- Final Evaluation ---")
    y_pred = model.predict(test_gen)
    y_pred_idx = np.argmax(y_pred, axis=1)
    y_true_idx = test_gen.classes
    class_labels = list(train_gen.class_indices.keys())

    # Metrics
    report = classification_report(y_true_idx, y_pred_idx, target_names=class_labels, output_dict=True)
    print(classification_report(y_true_idx, y_pred_idx, target_names=class_labels))

    # Confusion Matrix
    cm = confusion_matrix(y_true_idx, y_pred_idx)
    plt.figure(figsize=(10, 8))
    sns.heatmap(cm, annot=True, fmt='d', xticklabels=class_labels, yticklabels=class_labels, cmap='Blues')
    plt.savefig(os.path.join(MODEL_OUT_DIR, 'eye_quality_v1_confusion_matrix.png'))

    # False Accepts / Rejects
    test_df['pred_class'] = [class_labels[i] for i in y_pred_idx]
    test_df['confidence'] = np.max(y_pred, axis=1)
    
    false_accepts = test_df[(test_df['doctor_verified_quality'] != 'good') & (test_df['pred_class'] == 'good')]
    false_rejects = test_df[(test_df['doctor_verified_quality'] == 'good') & (test_df['pred_class'] != 'good')]

    eval_summary = {
        "report": report,
        "false_accept_count": len(false_accepts),
        "false_reject_count": len(false_rejects)
    }
    with open(os.path.join(MODEL_OUT_DIR, 'eye_quality_v1_report.json'), 'w') as f:
        json.dump(eval_summary, f, indent=2)

    # 7. Save
    model.save(os.path.join(MODEL_OUT_DIR, 'eye_quality_v1.keras'))
    with open(os.path.join(MODEL_OUT_DIR, 'eye_quality_v1_labels.json'), 'w') as f:
        json.dump(train_gen.class_indices, f)

    print(f"Training complete. Artifacts in {MODEL_OUT_DIR}")

if __name__ == "__main__":
    train_quality_model()
