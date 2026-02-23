"""
YOLO Integration — Amblyopia Care System
=========================================
Eye / face detection and strabismus signal extraction using YOLOv8-nano.
Wraps the Ultralytics YOLOv8 library.
"""
from __future__ import annotations

import logging
import math
import os
import time
from typing import Dict, List, Tuple, Union

try:
    import cv2
    _CV2_AVAILABLE = True
except ImportError:
    cv2 = None  # type: ignore[assignment]
    _CV2_AVAILABLE = False
import numpy as np

logger = logging.getLogger(__name__)

# Confidence threshold below which detections are discarded
_MIN_CONFIDENCE = 0.25

# COCO class IDs that belong to face/eye region
# 0 = person; face/eye not in COCO by default, so we rely on spatial filtering
_FACE_CLASSES: set = {0}


class YOLOIntegration:
    """
    YOLOv8-nano wrapper for eye region detection and strabismus signal extraction.

    Uses YOLOv8 for general object/person detection, then applies spatial
    heuristics to isolate the eye bounding boxes from face/head detections.
    When no YOLOv8-eye-specific model is available, uses OpenCV Haar cascade
    as a local fallback for eye detection.

    Usage:
        y = YOLOIntegration('models/yolo/yolov8n.pt')
        boxes = y.detect_eyes(image)
        signals = y.detect_strabismus_signals(image)
    """

    def __init__(self, model_path: str) -> None:
        if not os.path.isfile(model_path):
            raise FileNotFoundError(
                f"YOLOv8 model not found: {model_path}\n"
                f"Run: bash setup/download_models.sh"
            )

        try:
            from ultralytics import YOLO  # type: ignore
        except ImportError as e:
            raise ImportError(
                f"ultralytics not installed: {e}\n"
                f"Run: pip install ultralytics"
            ) from e

        self._model = YOLO(model_path)
        self._eye_cascade = cv2.CascadeClassifier(
            cv2.data.haarcascades + "haarcascade_eye.xml"
        )
        logger.info("YOLOv8 loaded successfully from %s", model_path)

    def _load_image(self, image: Union[str, np.ndarray]) -> np.ndarray:
        if isinstance(image, str):
            img = cv2.imread(image, cv2.IMREAD_COLOR)
            if img is None:
                raise ValueError(f"Cannot read image: {image}")
            return img
        if not isinstance(image, np.ndarray):
            raise TypeError(f"Expected str or numpy array, got {type(image)}")
        img = image.copy()
        if img.dtype != np.uint8:
            img = np.clip(img, 0, 255).astype(np.uint8)
        return img

    def detect_eyes(
        self, image: Union[str, np.ndarray]
    ) -> List[Dict]:
        """
        Detect eye regions in the image.

        Strategy:
          1. Run YOLOv8 to find person/face bounding boxes.
          2. For each face region, apply Haar cascade to find eyes.
          3. If no YOLO detections, apply Haar cascade on full image.

        Returns:
            List of dicts: [{x1, y1, x2, y2, confidence, class}]
        """
        t0 = time.perf_counter()
        img = self._load_image(image)
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

        results: List[Dict] = []

        # ── YOLOv8 detection ─────────────────────────────────────────────
        yolo_results = self._model(img, conf=_MIN_CONFIDENCE, verbose=False)
        face_regions: List[Tuple] = []  # (x1, y1, x2, y2)

        for r in yolo_results:
            if r.boxes is None:
                continue
            for box in r.boxes:
                cls_id = int(box.cls[0])
                conf   = float(box.conf[0])
                x1, y1, x2, y2 = (int(v) for v in box.xyxy[0])
                if cls_id in _FACE_CLASSES and conf >= _MIN_CONFIDENCE:
                    # Use upper half of person bbox as face region
                    face_h = y2 - y1
                    face_regions.append((x1, y1, x2, y1 + face_h // 2))

        # ── Haar eye detection within YOLO face regions ───────────────────
        search_regions = face_regions if face_regions else [(0, 0, img.shape[1], img.shape[0])]
        for (rx1, ry1, rx2, ry2) in search_regions:
            roi_gray = gray[ry1:ry2, rx1:rx2]
            eyes = self._eye_cascade.detectMultiScale(
                roi_gray, scaleFactor=1.1, minNeighbors=5, minSize=(15, 15)
            )
            for (ex, ey, ew, eh) in eyes:
                results.append({
                    "x1": rx1 + ex,
                    "y1": ry1 + ey,
                    "x2": rx1 + ex + ew,
                    "y2": ry1 + ey + eh,
                    "confidence": 0.85,  # Haar cascade doesn't produce raw conf
                    "class": "eye",
                })

        elapsed_ms = (time.perf_counter() - t0) * 1000
        logger.info("YOLO detect_eyes: %d eyes found in %.0fms", len(results), elapsed_ms)
        return results

    def detect_strabismus_signals(
        self, image: Union[str, np.ndarray]
    ) -> Dict:
        """
        Detect both eyes and compute alignment metrics for strabismus screening.

        Strabismus flag is raised when:
          • Only one eye detected (asymmetry), OR
          • Vertical misalignment > 10px, OR
          • Misalignment angle > 5°

        Returns:
            {
              "left_eye_bbox":       [x1,y1,x2,y2] or None,
              "right_eye_bbox":      [x1,y1,x2,y2] or None,
              "misalignment_angle":  float (degrees),
              "vertical_offset_px":  float,
              "strabismus_flag":     bool,
              "confidence":          float,
              "detection_count":     int,
            }
        """
        img     = self._load_image(image)
        detections = self.detect_eyes(img)
        w_img   = img.shape[1]

        # Sort by x-center to identify left/right
        detections_sorted = sorted(
            detections, key=lambda d: (d["x1"] + d["x2"]) / 2
        )

        left_bbox  = None
        right_bbox = None
        angle      = 0.0
        vert_off   = 0.0
        strab_flag = False
        confidence = 0.0

        if len(detections_sorted) >= 2:
            # Take the two most-left and most-right eyes
            left  = detections_sorted[0]
            right = detections_sorted[-1]
            left_bbox  = [left["x1"],  left["y1"],  left["x2"],  left["y2"]]
            right_bbox = [right["x1"], right["y1"], right["x2"], right["y2"]]

            # Centers
            lx = (left["x1"]  + left["x2"])  / 2
            ly = (left["y1"]  + left["y2"])  / 2
            rx = (right["x1"] + right["x2"]) / 2
            ry = (right["y1"] + right["y2"]) / 2

            dx = rx - lx
            dy = ry - ly
            vert_off = abs(dy)
            angle    = math.degrees(math.atan2(abs(dy), max(abs(dx), 1)))

            strab_flag = (vert_off > 10) or (angle > 5.0)
            confidence = float(
                np.mean([left["confidence"], right["confidence"]])
            )

        elif len(detections_sorted) == 1:
            strab_flag = True  # Only one eye visible — abnormal
            confidence = detections_sorted[0]["confidence"]
            # Assign to left or right based on position in frame
            cx = (detections_sorted[0]["x1"] + detections_sorted[0]["x2"]) / 2
            bbox = [
                detections_sorted[0]["x1"], detections_sorted[0]["y1"],
                detections_sorted[0]["x2"], detections_sorted[0]["y2"],
            ]
            if cx < w_img / 2:
                left_bbox = bbox
            else:
                right_bbox = bbox

        return {
            "left_eye_bbox":      left_bbox,
            "right_eye_bbox":     right_bbox,
            "misalignment_angle": round(angle, 3),
            "vertical_offset_px": round(vert_off, 1),
            "strabismus_flag":    strab_flag,
            "confidence":         round(confidence, 4),
            "detection_count":    len(detections_sorted),
        }

    def test_with_sample(self, asset_dir: str = "test_assets") -> bool:
        """
        Load sample_eye_image.jpg, detect eyes, draw boxes, save output.
        Returns True if at least 1 eye detected.
        """
        input_path  = os.path.join(asset_dir, "sample_eye_image.jpg")
        output_path = os.path.join(asset_dir, "yolo_output.jpg")

        if not os.path.exists(input_path):
            logger.error("Test asset not found: %s", input_path)
            return False

        img        = cv2.imread(input_path)
        detections = self.detect_eyes(img)
        result_img = img.copy()

        for d in detections:
            cv2.rectangle(
                result_img,
                (d["x1"], d["y1"]), (d["x2"], d["y2"]),
                (0, 255, 0), 2
            )
            cv2.putText(
                result_img,
                f"{d['class']} {d['confidence']:.2f}",
                (d["x1"], d["y1"] - 5),
                cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 0), 1,
            )

        cv2.imwrite(output_path, result_img)

        signals = self.detect_strabismus_signals(img)
        print(f"  YOLO test:")
        print(f"    Detections:       {len(detections)}")
        for i, d in enumerate(detections):
            print(f"      [{i+1}] {d['class']} conf={d['confidence']:.2f} "
                  f"bbox=({d['x1']},{d['y1']},{d['x2']},{d['y2']})")
        print(f"    Strabismus flag:  {signals['strabismus_flag']}")
        print(f"    Misalign angle:   {signals['misalignment_angle']}°")
        print(f"    Saved: {output_path}")

        return len(detections) > 0
