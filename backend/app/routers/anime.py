from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional
import aiosqlite

from ..database import get_db
from ..schemas import AnimeCreate, AnimeUpdate, AnimeResponse, AnimeStatus

router = APIRouter(prefix="/api/anime", tags=["anime"])


@router.get("", response_model=list[AnimeResponse])
async def list_anime(
    status: Optional[AnimeStatus] = None,
    search: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: aiosqlite.Connection = Depends(get_db),
):
    query = "SELECT * FROM anime WHERE 1=1"
    params = []

    if status:
        query += " AND status = ?"
        params.append(status.value)
    if search:
        query += " AND title LIKE ?"
        params.append(f"%{search}%")

    query += " ORDER BY updated_at DESC LIMIT ? OFFSET ?"
    params.extend([page_size, (page - 1) * page_size])

    cursor = await db.execute(query, params)
    rows = await cursor.fetchall()
    return [AnimeResponse(**dict(row)) for row in rows]


@router.get("/{anime_id}", response_model=AnimeResponse)
async def get_anime(anime_id: int, db: aiosqlite.Connection = Depends(get_db)):
    cursor = await db.execute("SELECT * FROM anime WHERE id = ?", (anime_id,))
    row = await cursor.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Anime not found")
    return AnimeResponse(**dict(row))


@router.post("", response_model=AnimeResponse, status_code=201)
async def create_anime(anime: AnimeCreate, db: aiosqlite.Connection = Depends(get_db)):
    cursor = await db.execute(
        """INSERT INTO anime (title, cover_url, description, total_episodes, current_episode, status, score, air_date, bangumi_id)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (
            anime.title,
            anime.cover_url,
            anime.description,
            anime.total_episodes,
            anime.current_episode,
            anime.status.value,
            anime.score,
            anime.air_date,
            anime.bangumi_id,
        ),
    )
    await db.commit()
    new_id = cursor.lastrowid
    return await get_anime(new_id, db)


@router.put("/{anime_id}", response_model=AnimeResponse)
async def update_anime(anime_id: int, anime: AnimeUpdate, db: aiosqlite.Connection = Depends(get_db)):
    existing = await get_anime(anime_id, db)
    if not existing:
        raise HTTPException(status_code=404, detail="Anime not found")

    fields = anime.model_dump(exclude_unset=True)
    if not fields:
        return existing

    if "status" in fields and fields["status"]:
        fields["status"] = fields["status"].value

    set_clause = ", ".join(f"{k} = ?" for k in fields)
    set_clause += ", updated_at = datetime('now')"
    values = list(fields.values()) + [anime_id]

    await db.execute(f"UPDATE anime SET {set_clause} WHERE id = ?", values)
    await db.commit()
    return await get_anime(anime_id, db)


@router.delete("/{anime_id}", status_code=204)
async def delete_anime(anime_id: int, db: aiosqlite.Connection = Depends(get_db)):
    cursor = await db.execute("SELECT id FROM anime WHERE id = ?", (anime_id,))
    if not await cursor.fetchone():
        raise HTTPException(status_code=404, detail="Anime not found")
    await db.execute("DELETE FROM anime WHERE id = ?", (anime_id,))
    await db.commit()
