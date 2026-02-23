"""Tests for scoring_engine.py — the most critical business logic module."""
from __future__ import annotations

import pytest
from app.services.scoring_engine import (
    assign_severity_grade,
    calculate_combined_score,
    calculate_gaze_score,
    calculate_redgreen_score,
    calculate_snellen_score,
    needs_doctor_review,
)


class TestGazeScore:
    def test_normal_gaze(self):
        """Symmetric gaze → low score."""
        score = calculate_gaze_score(0.05, 0.80, 0.82, 0.05, 0.98)
        assert score < 30, f"Expected low score for normal gaze, got {score}"

    def test_high_asymmetry(self):
        """High asymmetry → high score."""
        score = calculate_gaze_score(0.30, 0.50, 0.85, 0.30, 0.95)
        assert score > 50, f"Expected high score for asymmetric gaze, got {score}"

    def test_all_none_returns_50(self):
        """No data → neutral 50.0."""
        score = calculate_gaze_score(None, None, None, None, None)
        assert score == 50.0

    def test_low_confidence_penalty(self):
        """Low confidence should raise score."""
        score_high_conf = calculate_gaze_score(0.05, 0.80, 0.82, 0.05, 0.98)
        score_low_conf = calculate_gaze_score(0.05, 0.80, 0.82, 0.05, 0.70)
        assert score_low_conf > score_high_conf

    def test_score_bounded_0_100(self):
        """Score must always be within [0, 100]."""
        score = calculate_gaze_score(1.0, 0.0, 1.0, 1.0, 0.0)
        assert 0 <= score <= 100


class TestRedGreenScore:
    def test_normal_binocular(self):
        """Good binocular score, symmetric → low risk score."""
        score = calculate_redgreen_score(0.05, 3, False, 0.40, 0.42, 0.96)
        assert score < 25

    def test_suppression_adds_penalty(self):
        """Suppression flag should significantly increase score."""
        without = calculate_redgreen_score(0.10, 2, False, 0.40, 0.42, 0.95)
        with_suppression = calculate_redgreen_score(0.10, 2, True, 0.40, 0.42, 0.95)
        assert with_suppression > without + 15

    def test_score_1_binocular_is_worse_than_3(self):
        score_1 = calculate_redgreen_score(0.10, 1, False, 0.40, 0.42, 0.95)
        score_3 = calculate_redgreen_score(0.10, 3, False, 0.40, 0.42, 0.95)
        assert score_1 > score_3


class TestSnellenScore:
    def test_infant_returns_zero(self):
        """Infants skip Snellen — must return 0.0."""
        score = calculate_snellen_score("6/6", "6/6", 0.1, 0.95, "infant")
        assert score == 0.0

    def test_perfect_vision_both_eyes(self):
        """6/6 both eyes → low risk score."""
        score = calculate_snellen_score("6/6", "6/6", 0.1, 0.95, "adult")
        assert score < 20

    def test_large_acuity_gap_increases_score(self):
        """Large inter-eye gap should raise score."""
        score = calculate_snellen_score("6/6", "6/60", 0.2, 0.95, "adult")
        assert score > 40

    def test_high_hesitation_increases_score(self):
        score_normal = calculate_snellen_score("6/12", "6/12", 0.1, 0.95, "adult")
        score_hesitant = calculate_snellen_score("6/12", "6/12", 0.9, 0.95, "adult")
        assert score_hesitant > score_normal


class TestCombinedScore:
    def test_combined_adult_weighted_correctly(self):
        """Verify 40/30/30 weight formula for adults.
        gaze=100, redgreen=None→50, snellen=None→50
        → 100*0.40 + 50*0.30 + 50*0.30 = 40 + 15 + 15 = 70.0
        """
        combined = calculate_combined_score(100, None, None, "adult")
        assert abs(combined - 70.0) < 0.1, f"Expected ~70, got {combined}"

    def test_infant_no_snellen(self):
        """Infants: 55/45 weight, snellen not used.
        gaze=100, redgreen=None→50
        → 100*0.55 + 50*0.45 = 55 + 22.5 = 77.5
        """
        combined = calculate_combined_score(100, None, None, "infant")
        assert abs(combined - 77.5) < 0.1, f"Expected ~77.5, got {combined}"

    def test_all_none_returns_neutral_50(self):
        """No data → all defaults to 50.0 neutral baseline → 50.0 combined."""
        assert calculate_combined_score(None, None, None, "adult") == 50.0

    def test_all_hundred_returns_hundred(self):
        assert calculate_combined_score(100, 100, 100, "adult") == 100.0


class TestSeverityGrade:
    def test_grade_0_normal(self):
        result = assign_severity_grade(15.0)
        assert result["severity_grade"] == 0
        assert result["risk_level"] == "low"
        assert result["referral_needed"] is False

    def test_grade_1_mild(self):
        result = assign_severity_grade(45.0)
        assert result["severity_grade"] == 1
        assert result["risk_level"] == "medium"
        assert result["referral_needed"] is False

    def test_grade_2_moderate(self):
        result = assign_severity_grade(72.0)
        assert result["severity_grade"] == 2
        assert result["risk_level"] == "high"
        assert result["referral_needed"] is True

    def test_grade_3_severe(self):
        result = assign_severity_grade(90.0)
        assert result["severity_grade"] == 3
        assert result["risk_level"] == "critical"
        assert result["referral_needed"] is True

    def test_boundary_30(self):
        """Score exactly at 30 → grade 1 (mild)."""
        result = assign_severity_grade(30.0)
        assert result["severity_grade"] == 1

    def test_boundary_60(self):
        result = assign_severity_grade(60.0)
        assert result["severity_grade"] == 2

    def test_boundary_85(self):
        result = assign_severity_grade(85.0)
        assert result["severity_grade"] == 3


class TestDoctorReviewFlag:
    def test_infant_always_reviewed(self):
        flag = needs_doctor_review(0.99, 0.99, None, False, 10.0, "infant")
        assert flag is True

    def test_suppression_triggers_review(self):
        flag = needs_doctor_review(0.98, 0.98, 0.98, True, 20.0, "adult")
        assert flag is True

    def test_high_score_triggers_review(self):
        flag = needs_doctor_review(0.95, 0.95, 0.95, False, 75.0, "adult")
        assert flag is True

    def test_low_confidence_triggers_review(self):
        flag = needs_doctor_review(0.80, 0.99, 0.99, False, 25.0, "adult")
        assert flag is True

    def test_normal_case_no_review(self):
        flag = needs_doctor_review(0.95, 0.97, 0.96, False, 15.0, "adult")
        assert flag is False
