"""
Placeholder ambyo_model.tflite for testing.
Uses synthetic data and clinical-style risk weighting.
Replace with real trained model after Aravind pilot data.

Input: 10 test scores
Output: 4 risk classes (Normal, Mild, Moderate, Severe)
"""
import numpy as np
import tensorflow as tf

# Input: 10 test scores
# Output: 4 risk classes
model = tf.keras.Sequential([
    tf.keras.layers.Dense(64, activation="relu", input_shape=(10,)),
    tf.keras.layers.BatchNormalization(),
    tf.keras.layers.Dropout(0.3),
    tf.keras.layers.Dense(32, activation="relu"),
    tf.keras.layers.Dropout(0.2),
    tf.keras.layers.Dense(4, activation="softmax"),
])

model.compile(
    optimizer="adam",
    loss="categorical_crossentropy",
    metrics=["accuracy"],
)

# Synthetic training data based on clinical rules
# Index 0=visual acuity, 1=gaze deviation, 2=prism diopter, 3=suppression,
# 4=depth score, 5=stereo score, 6=color score, 7=red reflex, 8=age (norm), 9=hirschberg
np.random.seed(42)
X = np.random.rand(2000, 10).astype(np.float32)

y = np.zeros((2000, 4), dtype=np.float32)
for i in range(2000):
    risk = (
        (1 - X[i][0]) * 0.20
        + X[i][1] * 0.15
        + X[i][2] * 0.15
        + X[i][3] * 0.15
        + (1 - X[i][4]) * 0.10
        + (1 - X[i][5]) * 0.10
        + (1 - X[i][7]) * 0.10
        + X[i][9] * 0.05
    )
    if risk < 0.2:
        y[i][0] = 1  # Normal
    elif risk < 0.45:
        y[i][1] = 1  # Mild
    elif risk < 0.70:
        y[i][2] = 1  # Moderate
    else:
        y[i][3] = 1  # Severe

model.fit(
    X,
    y,
    epochs=30,
    batch_size=32,
    validation_split=0.2,
    verbose=1,
)

# Convert to TFLite float16
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]
tflite_model = converter.convert()

out_path = "assets/models/ambyo_model.tflite"
with open(out_path, "wb") as f:
    f.write(tflite_model)

kb = len(tflite_model) / 1024
print("Model saved successfully!")
print(f"Size: {kb:.1f} KB")

# Verify model works
interpreter = tf.lite.Interpreter(model_content=tflite_model)
interpreter.allocate_tensors()
inp = interpreter.get_input_details()
out = interpreter.get_output_details()
print(f"Input shape: {inp[0]['shape']}")
print(f"Output shape: {out[0]['shape']}")

test_input = np.array(
    [[0.5, 0.3, 0.2, 0.1, 0.8, 0.9, 1.0, 0.9, 0.4, 0.1]],
    dtype=np.float32,
)
interpreter.set_tensor(inp[0]["index"], test_input)
interpreter.invoke()
output = interpreter.get_tensor(out[0]["index"])
classes = ["Normal", "Mild", "Moderate", "Severe"]
predicted = classes[output[0].argmax()]
print(f"Test prediction: {predicted}")
print("Model verified OK!")
