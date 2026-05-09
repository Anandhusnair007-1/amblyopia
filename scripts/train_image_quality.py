import os
import pandas as pd
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models, applications
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix
import matplotlib.pyplot as plt

# Config
DATASET_DIR = 'ambyo_dataset_clean'
LABELS_CSV = os.path.join(DATASET_DIR, 'labels.csv')
IMAGE_DIR = os.path.join(DATASET_DIR, 'images')
IMG_SIZE = (224, 224)
BATCH_SIZE = 32
EPOCHS = 15
MODEL_NAME = 'ambyo_quality_v1'

# Classes defined by the user
CLASSES = ['good', 'blurred', 'dark', 'bad_crop', 'reflection_issue']

def load_data():
    df = pd.read_csv(LABELS_CSV)
    
    # 1. Basic usability check
    df = df[df['usable_for_training'] == True]
    
    # 2. Medical Audit Check (MUST be verified by doctor)
    df = df[df['audit_status'] == 'verified']
    
    # 3. Quality Column Check
    # We use the ground truth provided by the doctor
    df = df[df['doctor_verified_quality'].isin(CLASSES)]
    
    # Path setup
    df['full_path'] = df['image_path'].apply(lambda x: os.path.join(DATASET_DIR, x))
    df = df[df['full_path'].apply(os.path.exists)]
    
    print(f"Total verified quality records: {len(df)}")
    print(df['doctor_verified_quality'].value_counts())
    
    return df

def build_quality_model(num_classes):
    # Using MobileNetV3Small for lightweight edge deployment
    base_model = applications.MobileNetV3Small(
        input_shape=(*IMG_SIZE, 3), 
        include_top=False, 
        weights='imagenet'
    )
    base_model.trainable = False # Initial freeze

    model = models.Sequential([
        base_model,
        layers.GlobalAveragePooling2D(),
        layers.Dense(128, activation='relu'),
        layers.Dropout(0.4),
        layers.Dense(num_classes, activation='softmax')
    ])

    model.compile(
        optimizer='adam',
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )
    return model

def train():
    df = load_data()
    if len(df) < 10:
        print("CRITICAL: Not enough 'verified' data. Ask the ophthalmologist to verify labels.csv first.")
        return

    # Split
    train_df, val_df = train_test_split(
        df, test_size=0.2, 
        stratify=df['doctor_verified_quality'], 
        random_state=42
    )

    # Augmentation
    train_datagen = tf.keras.preprocessing.image.ImageDataGenerator(
        rescale=1./255,
        brightness_range=[0.8, 1.2], # Useful for 'dark' class training
        horizontal_flip=True,
        fill_mode='nearest'
    )

    val_datagen = tf.keras.preprocessing.image.ImageDataGenerator(rescale=1./255)

    train_gen = train_datagen.flow_from_dataframe(
        train_df, x_col='full_path', y_col='doctor_verified_quality',
        target_size=IMG_SIZE, batch_size=BATCH_SIZE, class_mode='categorical',
        classes=CLASSES
    )

    val_gen = val_datagen.flow_from_dataframe(
        val_df, x_col='full_path', y_col='doctor_verified_quality',
        target_size=IMG_SIZE, batch_size=BATCH_SIZE, class_mode='categorical',
        classes=CLASSES
    )

    model = build_quality_model(len(CLASSES))
    
    print(f"Training {MODEL_NAME}...")
    # history = model.fit(train_gen, validation_data=val_gen, epochs=EPOCHS)
    
    print("Next Steps:")
    print(f"1. Save model: model.save('{MODEL_NAME}.h5')")
    print(f"2. Convert to TF.js for PWA integration.")

if __name__ == "__main__":
    train()
