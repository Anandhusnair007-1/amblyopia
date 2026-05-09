"""
Sliding-window rate limiting keyed by client IP (or X-Forwarded-For).
Parses limits like "30/minute", "15/minute", "5/second" from environment strings.
"""
from __future__ import annotations

import re
import time
from collections import defaultdict
from typing import Dict, List, Tuple

_window_buckets: Dict[str, List[float]] = defaultdict(list)


def reset_rate_limit_store() -> None:
    """Clear counters — for tests only."""
    _window_buckets.clear()


def parse_limit(spec: str) -> Tuple[int, int]:
    """
    Parse "N/unit" → (max_hits, window_seconds).
    Supported units: second, minute, hour (singular or plural).
    """
    s = (spec or "").strip().lower()
    m = re.match(r"^(\d+)\s*/\s*(second|seconds|minute|minutes|hour|hours)$", s)
    if not m:
        return 30, 60
    n = int(m.group(1))
    unit = m.group(2)
    if unit.startswith("second"):
        return n, 1
    if unit.startswith("minute"):
        return n, 60
    if unit.startswith("hour"):
        return n, 3600
    return n, 60


def allow_request(bucket_key: str, max_hits: int, window_sec: int) -> bool:
    now = time.monotonic()
    window_start = now - window_sec
    hits = _window_buckets[bucket_key]
    while hits and hits[0] < window_start:
        hits.pop(0)
    if len(hits) >= max_hits:
        return False
    hits.append(now)
    return True


def client_key_from_request(request) -> str:
    """Stable client identifier for rate limiting."""
    xf = request.headers.get("X-Forwarded-For") if request else None
    if xf:
        return xf.split(",")[0].strip()
    if request and request.client:
        return request.client.host or "unknown"
    return "unknown"
