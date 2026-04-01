from typing import Any


def api_success(data: Any = None, *, message: str = "ok", meta: dict[str, Any] | None = None) -> dict[str, Any]:
    return {
        "success": True,
        "message": message,
        "data": data,
        "meta": meta or {},
    }


def api_error(*, message: str, code: str, details: dict[str, Any] | None = None) -> dict[str, Any]:
    return {
        "success": False,
        "message": message,
        "error": {
            "code": code,
            "details": details or {},
        },
    }
