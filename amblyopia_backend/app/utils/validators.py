"""
Amblyopia Care System — Validators
Input validation helpers for visual acuity strings, phone numbers, etc.
"""
from __future__ import annotations

import re
from typing import Optional, Tuple


# ── Visual Acuity ─────────────────────────────────────────────────────────────
SNELLEN_PATTERN = re.compile(r"^6/(\d+)$")

SNELLEN_MAP = {
    "6/6": 1.0,  "6/9": 0.85, "6/12": 0.70, "6/18": 0.55,
    "6/24": 0.40, "6/36": 0.25, "6/60": 0.10, "CF": 0.05,
    "HM": 0.03, "PL": 0.01, "NPL": 0.0,
}


def parse_snellen(acuity_string: Optional[str]) -> Optional[float]:
    """
    Convert a Snellen fraction string to a 0.0–1.0 numeric score.
    Returns None if the string is None or unrecognised.
    """
    if acuity_string is None:
        return None
    acuity_upper = acuity_string.strip().upper()
    if acuity_upper in SNELLEN_MAP:
        return SNELLEN_MAP[acuity_upper]
    match = SNELLEN_PATTERN.match(acuity_upper)
    if match:
        denominator = int(match.group(1))
        if denominator > 0:
            return min(1.0, 6.0 / denominator)
    return None


def validate_phone_number(phone: str) -> bool:
    """
    Validate an Indian mobile phone number (10 digits, starts with 6-9).
    Also accepts +91 prefix.
    """
    cleaned = re.sub(r"[+\s\-()]", "", phone)
    if cleaned.startswith("91") and len(cleaned) == 12:
        cleaned = cleaned[2:]
    return bool(re.match(r"^[6-9]\d{9}$", cleaned))


def validate_gps_coordinates(lat: float, lng: float) -> bool:
    """Validate GPS coordinates are within India's bounding box."""
    return (6.0 <= lat <= 37.0) and (68.0 <= lng <= 97.0)


def validate_snellen_string(value: str) -> bool:
    """Return True if the Snellen string is a recognised value."""
    return parse_snellen(value) is not None


def validate_age_group(age_group: str) -> bool:
    return age_group in ("infant", "child", "adult", "elderly")


def is_infant(age_group: str) -> bool:
    return age_group == "infant"
