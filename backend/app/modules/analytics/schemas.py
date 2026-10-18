"""Schemas del módulo de analytics."""
from datetime import date
from typing import Optional
from pydantic import BaseModel, Field


class StatsRequest(BaseModel):
    days: int = Field(default=7, ge=1, le=90)
    hostname: Optional[str] = None


class VisitaDia(BaseModel):
    date: date
    visits: int
    pageviews: int


class TopItem(BaseModel):
    name: str
    count: int


class StatsResponse(BaseModel):
    period_days: int
    hostname: Optional[str] = None
    total_visits: int
    total_pageviews: int
    by_day: list[VisitaDia]
    top_countries: list[TopItem]
    top_referrers: list[TopItem]
    top_pages: list[TopItem]
