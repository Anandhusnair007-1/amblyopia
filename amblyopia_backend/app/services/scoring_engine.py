"""
Amblyopia Care System — Scoring Engine Service
Calculates gaze, red-green, snellen, and combined risk scores.
Assigns severity grades and referral recommendations.
Handles all edge cases: infant mode, missing tests, partial completion.

Phase 4: Thresholds driven from settings.config (score_low_max, score_medium_max,
score_high_max). Strabismus flag now factored into combined score.
"""
from __future__ import annotations

from typing import Optional

from app.utils.validators import parse_snellen


# ── Individual Scoring ────────────────────────────────────────────────────────

def calculate_gaze_score(
    gaze_asymmetry_score: Optional[float],
    left_fixation_stability: Optional[float],
    right_fixation_stability: Optional[float],
    blink_asymmetry: Optional[float],
    confidence_score: Optional[float],
) -> float:
    """
    Calculate a 0–100 gaze risk score.
    Higher = more concerning.

    Weights:
      asymmetry   : 50 pts
      fixation_sd : 30 pts
      blink_asym  : 20 pts
    """
    if gaze_asymmetry_score is None and left_fixation_stability is None:
        return 50.0   # Unknown — middle score, will trigger doctor review

    score = 0.0

    # Asymmetry component (threshold 0.15)
    if gaze_asymmetry_score is not None:
        asym_pts = min(1.0, gaze_asymmetry_score / 0.30) * 50
        score += asym_pts

    # Fixation stability difference (threshold 0.10)
    if left_fixation_stability is not None and right_fixation_stability is not None:
        fixation_diff = abs(left_fixation_stability - right_fixation_stability)
        fix_pts = min(1.0, fixation_diff / 0.20) * 30
        score += fix_pts
    else:
        score += 15.0  # Unknown → add partial penalty

    # Blink asymmetry (threshold 0.20)
    if blink_asymmetry is not None:
        blink_pts = min(1.0, blink_asymmetry / 0.40) * 20
        score += blink_pts
    else:
        score += 10.0  # Unknown → partial

    # Low confidence penalty
    if confidence_score is not None and confidence_score < 0.90:
        penalty = (1.0 - confidence_score) * 10
        score = min(100.0, score + penalty)

    return round(min(100.0, score), 2)


def calculate_redgreen_score(
    asymmetry_ratio: Optional[float],
    binocular_score: Optional[int],
    suppression_flag: bool,
    constriction_amount_left: Optional[float],
    constriction_amount_right: Optional[float],
    confidence_score: Optional[float],
) -> float:
    """
    Calculate a 0–100 red-green risk score.

    Weights:
      binocular_score : 40 pts  (inverted: 1=bad, 3=good)
      asymmetry_ratio : 35 pts
      constriction    : 25 pts
    Suppression flag adds 20-point bonus.
    """
    if asymmetry_ratio is None and binocular_score is None:
        return 50.0  # Unknown

    score = 0.0

    # Binocular score (1=suppressed, 2=normal, 3=excellent)
    if binocular_score is not None:
        binocular_risk = {1: 40.0, 2: 15.0, 3: 0.0}.get(binocular_score, 20.0)
        score += binocular_risk
    else:
        score += 20.0

    # Pupil asymmetry ratio
    if asymmetry_ratio is not None:
        asym_pts = min(1.0, asymmetry_ratio / 0.30) * 35
        score += asym_pts
    else:
        score += 17.5

    # Constriction symmetry
    if constriction_amount_left is not None and constriction_amount_right is not None:
        constriction_diff = abs(constriction_amount_left - constriction_amount_right)
        con_pts = min(1.0, constriction_diff / 0.50) * 25
        score += con_pts
    else:
        score += 12.5

    # Suppression flag hard boost
    if suppression_flag:
        score = min(100.0, score + 20.0)

    # Low confidence penalty
    if confidence_score is not None and confidence_score < 0.90:
        penalty = (1.0 - confidence_score) * 10
        score = min(100.0, score + penalty)

    return round(min(100.0, score), 2)


def calculate_snellen_score(
    visual_acuity_right: Optional[str],
    visual_acuity_left: Optional[str],
    hesitation_score: Optional[float],
    confidence_score: Optional[float],
    age_group: str = "adult",
) -> float:
    """
    Calculate a 0–100 snellen risk score.

    Infants skip Snellen — returns 0.0 (not applicable).
    Normal vision = 6/6. Each step worse adds risk.

    Weights:
      acuity gap (L vs R) : 50 pts
      absolute acuity      : 30 pts
      hesitation           : 20 pts
    """
    if age_group == "infant":
        return 0.0  # Snellen not administered to infants

    right_num = parse_snellen(visual_acuity_right)
    left_num = parse_snellen(visual_acuity_left)

    if right_num is None and left_num is None:
        return 50.0  # Unknown

    score = 0.0

    # Inter-eye acuity difference
    if right_num is not None and left_num is not None:
        acuity_gap = abs(right_num - left_num)
        gap_pts = min(1.0, acuity_gap / 0.50) * 50
        score += gap_pts
    else:
        score += 25.0  # One eye unknown

    # Poorest eye absolute acuity
    acuities = [a for a in [right_num, left_num] if a is not None]
    if acuities:
        worst = min(acuities)
        # 1.0 => normal (6/6), 0.0 => no light perception
        absolute_pts = (1.0 - worst) * 30
        score += absolute_pts
    else:
        score += 15.0

    # Hesitation penalty (0.0 to 1.0)
    if hesitation_score is not None:
        score += hesitation_score * 20
    else:
        score += 5.0

    # Low confidence penalty
    if confidence_score is not None and confidence_score < 0.90:
        penalty = (1.0 - confidence_score) * 10
        score = min(100.0, score + penalty)

    return round(min(100.0, score), 2)


# ── Combined Scoring ──────────────────────────────────────────────────────────

def calculate_combined_score(
    gaze_score: Optional[float],
    redgreen_score: Optional[float],
    snellen_score: Optional[float],
    age_group: str = "adult",
    strabismus_flag: bool = False,
) -> float:
    """
    Weighted combined risk score:
      gaze     × 0.40
      redgreen × 0.30
      snellen  × 0.30

    For infants (no Snellen), redistribute snellen weight to gaze:
      gaze × 0.55, redgreen × 0.45

    Strabismus flag adds a fixed 10-point clinical penalty (hard signal).
    """
    if age_group == "infant":
        g = gaze_score or 50.0
        r = redgreen_score or 50.0
        combined = round(g * 0.55 + r * 0.45, 2)
    else:
        g = gaze_score or 50.0
        r = redgreen_score or 50.0
        s = snellen_score or 50.0
        combined = round(g * 0.40 + r * 0.30 + s * 0.30, 2)

    if strabismus_flag:
        combined = min(100.0, combined + 10.0)

    return round(combined, 2)


# ── Severity Grading ──────────────────────────────────────────────────────────

def assign_severity_grade(overall_risk_score: float) -> dict:
    """
    Map overall combined risk score to severity grade and risk level.
    Thresholds are configurable via settings (score_low_max, score_medium_max, score_high_max).

      0–30  : Grade 0 — Normal        — green
      30–60 : Grade 1 — Mild          — yellow  — monitor
      60–85 : Grade 2 — Moderate      — orange  — therapy
      85+   : Grade 3 — Severe/Urgent — red     — urgent referral
    """
    from app.config import settings

    low_max    = settings.score_low_max     # 30.0 default
    medium_max = settings.score_medium_max  # 60.0 default
    high_max   = settings.score_high_max    # 85.0 default

    score = round(float(overall_risk_score), 2)

    if score < low_max:
        return {
            "risk_score": score,
            "severity_grade": 0,
            "risk_level": "low",
            "recommendation": (
                "No signs of amblyopia detected. Continue routine annual screening."
            ),
            "explanation": (
                f"Combined risk score {score}/100 is within the normal range (0–{low_max:.0f}). "
                "All three tests returned results within expected limits."
            ),
            "referral_needed": False,
        }
    elif score < medium_max:
        return {
            "risk_score": score,
            "severity_grade": 1,
            "risk_level": "medium",
            "recommendation": (
                "Mild amblyopia indicators detected. "
                "Schedule follow-up screening in 3 months. "
                "Home exercises recommended."
            ),
            "explanation": (
                f"Combined risk score {score}/100 indicates mild risk ({low_max:.0f}–{medium_max:.0f} range). "
                "One or more tests showed borderline results that warrant monitoring."
            ),
            "referral_needed": False,
        }
    elif score < high_max:
        return {
            "risk_score": score,
            "severity_grade": 2,
            "risk_level": "high",
            "recommendation": (
                "Moderate amblyopia detected. "
                "Refer to ophthalmologist for patching therapy evaluation. "
                "Follow-up within 4 weeks."
            ),
            "explanation": (
                f"Combined risk score {score}/100 indicates moderate-to-high risk "
                f"({medium_max:.0f}–{high_max:.0f} range). "
                "Gaze, visual acuity, or binocular vision anomalies detected."
            ),
            "referral_needed": True,
        }
    else:
        return {
            "risk_score": score,
            "severity_grade": 3,
            "risk_level": "critical",
            "recommendation": (
                "Severe amblyopia detected. URGENT referral to Aravind Eye Hospital required. "
                "Do not delay — risk of permanent vision loss. "
                "Bring referral letter and QR code to appointment."
            ),
            "explanation": (
                f"Combined risk score {score}/100 is in the critical range (>{high_max:.0f}). "
                "Multiple tests indicate severe binocular suppression or fixation failure. "
                "Immediate specialist review is essential."
            ),
            "referral_needed": True,
        }


# ── Doctor Review Flag ─────────────────────────────────────────────────────────

def needs_doctor_review(
    gaze_confidence: Optional[float],
    redgreen_confidence: Optional[float],
    snellen_confidence: Optional[float],
    suppression_flag: bool,
    combined_score: float,
    age_group: str,
) -> bool:
    """
    Return True if a doctor should manually review this screening.
    Triggering conditions:
      1. Any individual test confidence < 90%
      2. Combined score > 60%
      3. Suppression flag is True
      4. Patient is an infant (always reviewed)
    """
    if age_group == "infant":
        return True
    if suppression_flag:
        return True
    if combined_score > 60.0:
        return True
    for conf in [gaze_confidence, redgreen_confidence, snellen_confidence]:
        if conf is not None and conf < 0.90:
            return True
    return False


# ── Edge Case: Partial Completion ─────────────────────────────────────────────

def handle_partial_completion(
    gaze_score: Optional[float],
    redgreen_score: Optional[float],
    snellen_score: Optional[float],
    battery_died: bool = False,
) -> dict:
    """
    If the session was incomplete (e.g. battery died mid-test),
    note which tests completed and assign conservative scores.
    Any missing test defaults to penalised neutral (55.0) to reflect uncertainty.
    """
    completed = []
    if gaze_score is not None:
        completed.append("gaze")
    if redgreen_score is not None:
        completed.append("redgreen")
    if snellen_score is not None:
        completed.append("snellen")

    partial_gaze = gaze_score if gaze_score is not None else 55.0
    partial_rg = redgreen_score if redgreen_score is not None else 55.0
    partial_sn = snellen_score if snellen_score is not None else 55.0

    note = ""
    if battery_died:
        note = "Session ended early due to low battery. Missing tests flagged for re-screening."
    elif len(completed) < 3:
        missing = [t for t in ["gaze", "redgreen", "snellen"] if t not in completed]
        note = f"Incomplete session. Missing tests: {', '.join(missing)}. Re-screening recommended."

    return {
        "gaze_score": partial_gaze,
        "redgreen_score": partial_rg,
        "snellen_score": partial_sn,
        "completed_tests": completed,
        "partial_completion_note": note,
    }
