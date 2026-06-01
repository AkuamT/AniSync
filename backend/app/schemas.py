from pydantic import BaseModel
from typing import Optional
from enum import Enum


class AnimeStatus(str, Enum):
    watching = "watching"
    plan = "plan"
    completed = "completed"


class AnimeCreate(BaseModel):
    title: str
    cover_url: Optional[str] = None
    description: Optional[str] = None
    total_episodes: int = 0
    current_episode: int = 0
    status: AnimeStatus = AnimeStatus.plan
    score: Optional[int] = None
    air_date: Optional[str] = None
    bangumi_id: Optional[int] = None


class AnimeUpdate(BaseModel):
    title: Optional[str] = None
    cover_url: Optional[str] = None
    description: Optional[str] = None
    total_episodes: Optional[int] = None
    current_episode: Optional[int] = None
    status: Optional[AnimeStatus] = None
    score: Optional[int] = None
    air_date: Optional[str] = None
    bangumi_id: Optional[int] = None


class AnimeResponse(BaseModel):
    id: int
    title: str
    cover_url: Optional[str] = None
    description: Optional[str] = None
    total_episodes: int = 0
    current_episode: int = 0
    status: AnimeStatus = AnimeStatus.plan
    score: Optional[int] = None
    air_date: Optional[str] = None
    bangumi_id: Optional[int] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None
