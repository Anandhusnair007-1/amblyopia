const STORAGE_KEY = "ambyoai_screen_calibration_v1";

export const STANDARD_CARD_WIDTH_MM = 85.6;

export function getDeviceInfo() {
  if (typeof window === "undefined") return {};
  return {
    user_agent: window.navigator?.userAgent || "",
    platform: window.navigator?.platform || "",
    screen_width_px: window.screen?.width || null,
    screen_height_px: window.screen?.height || null,
    viewport_width_px: window.innerWidth || null,
    viewport_height_px: window.innerHeight || null,
    device_pixel_ratio: window.devicePixelRatio || 1,
  };
}

export function loadScreenCalibration() {
  if (typeof window === "undefined") return null;
  try {
    const parsed = JSON.parse(window.localStorage.getItem(STORAGE_KEY) || "null");
    if (!parsed || !parsed.px_per_mm || parsed.px_per_mm <= 0) return null;
    return parsed;
  } catch {
    return null;
  }
}

export function saveScreenCalibration({ method, referenceWidthMm, referenceWidthPx }) {
  if (typeof window === "undefined") return null;
  const mm = Number(referenceWidthMm);
  const px = Number(referenceWidthPx);
  if (!Number.isFinite(mm) || !Number.isFinite(px) || mm <= 0 || px <= 0) return null;
  const device = getDeviceInfo();
  const calibration = {
    method: method || "standard_card",
    reference_width_mm: mm,
    reference_width_px: Math.round(px),
    px_per_mm: px / mm,
    ppi: (px / mm) * 25.4,
    device_pixel_ratio: device.device_pixel_ratio,
    screen_width_px: device.screen_width_px,
    screen_height_px: device.screen_height_px,
    viewport_width_px: device.viewport_width_px,
    viewport_height_px: device.viewport_height_px,
    device_info: device,
    calibrated_at: new Date().toISOString(),
  };
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(calibration));
  return calibration;
}

export function clearScreenCalibration() {
  if (typeof window !== "undefined") window.localStorage.removeItem(STORAGE_KEY);
}

