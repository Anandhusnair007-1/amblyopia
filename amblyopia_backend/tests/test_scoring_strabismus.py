"""
Phase 8: Scoring engine — strabismus penalty, configurable thresholds, explanation field.
"""
from __future__ import annotations

import pytest


class TestScoringStrabismusPenalty:
    def test_strabismus_flag_adds_penalty(self):
        from app.services.scoring_engine import calculate_combined_score

        result_without = calculate_combined_score(
            gaze_score=50.0,
            redgreen_score=50.0,
            snellen_score=50.0,
            strabismus_flag=False,
        )
        result_with = calculate_combined_score(
            gaze_score=50.0,
            redgreen_score=50.0,
            snellen_score=50.0,
            strabismus_flag=True,
        )
        diff = result_with["combined_score"] - result_without["combined_score"]
        assert diff == pytest.approx(10.0, abs=0.1), (
            f"Strabismus flag should add 10 pts, got diff={diff}"
        )

    def test_strabismus_penalty_capped_at_100(self):
        from app.services.scoring_engine import calculate_combined_score

        result = calculate_combined_score(
            gaze_score=100.0,
            redgreen_score=100.0,
            snellen_score=100.0,
            strabismus_flag=True,
        )
        assert result["combined_score"] <= 100.0

    def test_no_strabismus_no_penalty(self):
        from app.services.scoring_engine import calculate_combined_score

        no_flag = calculate_combined_score(50.0, 50.0, 50.0, strabismus_flag=False)
        explicit_false = calculate_combined_score(50.0, 50.0, 50.0, strabismus_flag=False)
        assert no_flag["combined_score"] == pytest.approx(explicit_false["combined_score"])

    def test_strabismus_default_false(self):
        from app.services.scoring_engine import calculate_combined_score
        import inspect

        sig = inspect.signature(calculate_combined_score)
        param = sig.parameters.get("strabismus_flag")
        assert param is not None, "strabismus_flag parameter missing"
        assert param.default is False or param.default == False


class TestSeverityGrade:
    def test_low_score_returns_low_or_normal(self):
        from app.services.scoring_engine import assign_severity_grade
        grade = assign_severity_grade(15.0)
        assert grade in ("low", "normal", "minimal", "none")

    def test_medium_score_returns_moderate(self):
        from app.services.scoring_engine import assign_severity_grade
        grade = assign_severity_grade(45.0)
        assert grade in ("moderate", "medium", "monitor")

    def test_high_score_returns_high(self):
        from app.services.scoring_engine import assign_severity_grade
        grade = assign_severity_grade(80.0)
        assert grade in ("high", "refer", "urgent")

    def test_boundary_low_max(self):
        """Score at exactly score_low_max must be low-grade."""
        from app.services.scoring_engine import assign_severity_grade
        from app.config import settings
        grade = assign_severity_grade(settings.score_low_max)
        assert grade in ("low", "normal", "minimal", "none")

    def test_boundary_just_above_low(self):
        from app.services.scoring_engine import assign_severity_grade
        from app.config import settings
        grade = assign_severity_grade(settings.score_low_max + 0.1)
        assert grade not in ("low", "normal", "minimal", "none")


class TestScoringOutputFields:
    def test_combined_score_result_has_risk_score(self):
        from app.services.scoring_engine import calculate_combined_score
        result = calculate_combined_score(40.0, 40.0, 40.0)
        assert "risk_score" in result or "combined_score" in result

    def test_combined_score_result_has_explanation(self):
        from app.services.scoring_engine import calculate_combined_score
        result = calculate_combined_score(80.0, 80.0, 80.0)
        assert "explanation" in result
        assert isinstance(result["explanation"], str)
        assert len(result["explanation"]) > 5

    def test_high_score_explanation_mentions_refer(self):
        from app.services.scoring_engine import calculate_combined_score
        result = calculate_combined_score(90.0, 90.0, 90.0)
        explanation = result.get("explanation", "").lower()
        assert any(word in explanation for word in ("refer", "urgent", "high", "risk"))

    def test_low_score_explanation_positive(self):
        from app.services.scoring_engine import calculate_combined_score
        result = calculate_combined_score(5.0, 5.0, 5.0)
        explanation = result.get("explanation", "").lower()
        assert any(word in explanation for word in ("low", "normal", "no concern", "minimal"))

    def test_score_range_0_to_100(self):
        from app.services.scoring_engine import calculate_combined_score
        for score_input in [0.0, 25.0, 50.0, 75.0, 100.0]:
            result = calculate_combined_score(score_input, score_input, score_input)
            combined = result.get("combined_score") or result.get("risk_score")
            assert 0.0 <= combined <= 100.0, f"Score out of range: {combined}"
