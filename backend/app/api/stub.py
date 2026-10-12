"""Placeholder for endpoints whose path is fixed but whose logic is not written yet."""

from typing import NoReturn

from fastapi import HTTPException, status


def not_implemented() -> NoReturn:
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED, detail="아직 구현되지 않았습니다."
    )
