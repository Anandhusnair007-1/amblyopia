// MediaPipe Face Landmarker wrapper — face detection + distance calculation
import { FaceLandmarker, FilesetResolver } from "@mediapipe/tasks-vision";

let landmarker = null;
let resolver = null;

export async function loadLandmarker() {
  if (landmarker) return landmarker;
  try {
    resolver = await FilesetResolver.forVisionTasks(
      "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/wasm"
    );
    landmarker = await FaceLandmarker.createFromOptions(resolver, {
      baseOptions: {
        modelAssetPath:
          "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task",
        delegate: "GPU",
      },
      runningMode: "VIDEO",
      numFaces: 1,
      outputFaceBlendshapes: false,
      outputFacialTransformationMatrixes: false,
    });
    return landmarker;
  } catch (e) {
    console.warn("[MediaPipe] load failed, using fallback", e);
    return null;
  }
}

// Age-based face width in cm (inter-temporal)
export function faceWidthCm(ageYears) {
  if (ageYears <= 4) return 11;
  if (ageYears <= 7) return 12;
  return 14;
}

// Distance from face box width in pixels.
// distance_cm = (FACE_WIDTH_CM * IMAGE_WIDTH_PX) / (face_box_px * 2 * tan(FOV/2))
export function estimateDistanceCm({ faceBoxPx, imageWidthPx, fovDeg = 60, ageYears = 6 }) {
  if (!faceBoxPx || faceBoxPx <= 0) return null;
  const fw = faceWidthCm(ageYears);
  const rad = (fovDeg * Math.PI) / 180;
  const d = (fw * imageWidthPx) / (faceBoxPx * 2 * Math.tan(rad / 2));
  return Math.max(5, Math.min(200, d));
}

// Returns { distanceCm, faceBox, landmarks } or null if no face
export function detectFace(landmarkerInstance, video, tsMs) {
  if (!landmarkerInstance || !video || video.readyState < 2) return null;
  const result = landmarkerInstance.detectForVideo(video, tsMs);
  if (!result || !result.faceLandmarks || result.faceLandmarks.length === 0) return null;
  const lm = result.faceLandmarks[0];
  // Normalised coords → pixel coords
  const w = video.videoWidth;
  const h = video.videoHeight;
  let minX = 1, maxX = 0, minY = 1, maxY = 0;
  for (let i = 0; i < lm.length; i++) {
    const p = lm[i];
    if (p.x < minX) minX = p.x;
    if (p.x > maxX) maxX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.y > maxY) maxY = p.y;
  }
  const boxPx = (maxX - minX) * w;
  return {
    faceBoxPx: boxPx,
    imageWidthPx: w,
    imageHeightPx: h,
    bbox: { x: minX * w, y: minY * h, w: (maxX - minX) * w, h: (maxY - minY) * h },
    landmarks: lm,
  };
}

// Iris + eye landmarks (MediaPipe 468 mesh — common indices)
// Left iris: 468-472, Right iris: 473-477
// Left eye contour: 33,133 (outer, inner); Right: 362,263
export function gazeRatios(landmarks) {
  if (!landmarks || landmarks.length < 478) return null;
  const L_IRIS = 468;      // centre of left iris (subject's left)
  const R_IRIS = 473;      // centre of right iris
  const L_OUT = 33, L_IN = 133;
  const R_OUT = 362, R_IN = 263;
  const leye_x = (landmarks[L_IN].x + landmarks[L_OUT].x) / 2;
  const reye_x = (landmarks[R_IN].x + landmarks[R_OUT].x) / 2;
  const leye_w = Math.abs(landmarks[L_IN].x - landmarks[L_OUT].x);
  const reye_w = Math.abs(landmarks[R_IN].x - landmarks[R_OUT].x);
  const ldx = (landmarks[L_IRIS].x - leye_x) / (leye_w || 1e-6);
  const rdx = (landmarks[R_IRIS].x - reye_x) / (reye_w || 1e-6);
  // Vertical: between eye corners (approx)
  const leye_y = (landmarks[L_IN].y + landmarks[L_OUT].y) / 2;
  const reye_y = (landmarks[R_IN].y + landmarks[R_OUT].y) / 2;
  const ldy = landmarks[L_IRIS].y - leye_y;
  const rdy = landmarks[R_IRIS].y - reye_y;
  return {
    left: { dx: ldx, dy: ldy },
    right: { dx: rdx, dy: rdy },
    avg: { dx: (ldx + rdx) / 2, dy: (ldy + rdy) / 2 },
    // Iris positions in normalized video coords (useful for Hirschberg)
    leftIris: { x: landmarks[L_IRIS].x, y: landmarks[L_IRIS].y },
    rightIris: { x: landmarks[R_IRIS].x, y: landmarks[R_IRIS].y },
  };
}
