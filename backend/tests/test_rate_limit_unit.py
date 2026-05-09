"""Unit tests for rate_limit.py (no server import)."""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from rate_limit import allow_request, parse_limit, reset_rate_limit_store


def test_parse_limit_minute():
    n, w = parse_limit("30/minute")
    assert n == 30 and w == 60


def test_parse_limit_second():
    n, w = parse_limit("5/second")
    assert n == 5 and w == 1


def test_allow_request_sliding_window():
    reset_rate_limit_store()
    assert allow_request("k", 2, 60) is True
    assert allow_request("k", 2, 60) is True
    assert allow_request("k", 2, 60) is False
