from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional
import aiosqlite
from datetime import datetime, timezone
from enum import Enum
from pydantic import BaseModel
import httpx

from ..database import get_db
from ..schemas import AnimeCreate, AnimeUpdate, AnimeResponse, AnimeStatus


class ExportData(BaseModel):
    """导出数据的格式"""
    version: int = 1
    exported_at: str = ""
    anime_list: list[AnimeCreate]


class ImportResult(BaseModel):
    """导入结果的格式"""
    imported: int = 0
    updated: int = 0
    skipped: int = 0
    errors: list[str] = []


class ImportRequest(BaseModel):
    """导入请求的格式"""
    anime_list: list[AnimeCreate]


class LanSyncMode(str, Enum):
    preview = "preview"
    remote_overwrite = "remote_overwrite"
    local_overwrite = "local_overwrite"
    merge = "merge"


class LanSyncRequest(BaseModel):
    """局域网同步请求"""
    host: str
    port: int = 8080
    mode: LanSyncMode = LanSyncMode.preview


class LanSyncResponse(BaseModel):
    """局域网同步响应"""
    mode: str
    success: bool = False
    local_count: int = 0
    remote_count: int = 0
    local_status_counts: dict[str, int] = {}
    remote_status_counts: dict[str, int] = {}
    remote_host: str = ""
    message: str = ""
    result: ImportResult | None = None

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
    # BUG-3 修复：检查 bangumi_id 是否已存在，防止重复添加
    if anime.bangumi_id is not None:
        cursor = await db.execute(
            "SELECT id FROM anime WHERE bangumi_id = ?", (anime.bangumi_id,)
        )
        existing = await cursor.fetchone()
        if existing:
            raise HTTPException(status_code=409, detail="该番剧已存在于你的列表中")

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


@router.get("/export/all", response_model=ExportData)
async def export_anime(db: aiosqlite.Connection = Depends(get_db)):
    """导出所有番剧数据为 JSON"""
    cursor = await db.execute("SELECT * FROM anime ORDER BY updated_at DESC")
    rows = await cursor.fetchall()
    anime_list = [AnimeCreate(**dict(row)) for row in rows]
    return ExportData(
        version=1,
        exported_at=datetime.now(timezone.utc).isoformat(),
        anime_list=anime_list,
    )


@router.post("/import", response_model=ImportResult)
async def import_anime(
    payload: ImportRequest,
    db: aiosqlite.Connection = Depends(get_db),
):
    """导入番剧数据（按 bangumi_id 匹配，存在则更新，不存在则新增）"""
    result = ImportResult()

    for item in payload.anime_list:
        try:
            # 尝试按 bangumi_id 匹配已存在的记录
            if item.bangumi_id is not None:
                cursor = await db.execute(
                    "SELECT id FROM anime WHERE bangumi_id = ?", (item.bangumi_id,)
                )
                existing = await cursor.fetchone()

                if existing:
                    # 更新现有记录
                    await db.execute(
                        """UPDATE anime
                           SET title = ?, cover_url = ?, description = ?,
                               total_episodes = ?, current_episode = ?,
                               status = ?, score = ?, air_date = ?,
                               updated_at = datetime('now')
                           WHERE id = ?""",
                        (
                            item.title,
                            item.cover_url,
                            item.description,
                            item.total_episodes,
                            item.current_episode,
                            item.status.value,
                            item.score,
                            item.air_date,
                            existing["id"],
                        ),
                    )
                    result.updated += 1
                    continue

            # 不存在则新增
            await db.execute(
                """INSERT INTO anime
                   (title, cover_url, description, total_episodes, current_episode, status, score, air_date, bangumi_id)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    item.title,
                    item.cover_url,
                    item.description,
                    item.total_episodes,
                    item.current_episode,
                    item.status.value,
                    item.score,
                    item.air_date,
                    item.bangumi_id,
                ),
            )
            result.imported += 1

        except Exception as e:
            result.errors.append(f"「{item.title}」导入失败: {str(e)}")
            result.skipped += 1

    await db.commit()
    return result


# ═══════════════════════════════════════════════════════════
# 局域网同步
# ═══════════════════════════════════════════════════════════

@router.post("/lan-sync", response_model=LanSyncResponse)
async def lan_sync(payload: LanSyncRequest, db: aiosqlite.Connection = Depends(get_db)):
    """局域网同步：预览 / 远程覆盖本地 / 本地覆盖远程 / 互相合并"""
    remote_url = f"http://{payload.host}:{payload.port}/api/anime/export/all"
    remote_import_url = f"http://{payload.host}:{payload.port}/api/anime/import"

    # ── 获取远程数据 ──
    remote_data: list[dict] = []
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(remote_url)
            resp.raise_for_status()
            export = resp.json()
            remote_data = export.get("anime_list", [])
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="无法连接到远程设备：连接超时")
    except httpx.ConnectError:
        raise HTTPException(status_code=502, detail="无法连接到远程设备，请检查IP和端口是否正确")
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=502, detail=f"远程设备返回错误 ({e.response.status_code})")
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"连接远程设备失败: {str(e)}")

    remote_anime = [AnimeCreate(**item) for item in remote_data]

    # ── 统计远程数据 ──
    remote_status_counts: dict[str, int] = {}
    for a in remote_anime:
        s = a.status.value
        remote_status_counts[s] = remote_status_counts.get(s, 0) + 1

    # ── 统计本地数据 ──
    cursor = await db.execute("SELECT status, COUNT(*) as cnt FROM anime GROUP BY status")
    local_status_counts: dict[str, int] = {}
    for row in await cursor.fetchall():
        local_status_counts[row["status"]] = row["cnt"]
    local_count = sum(local_status_counts.values())

    # ── preview 模式：只返回预览信息 ──
    if payload.mode == LanSyncMode.preview:
        return LanSyncResponse(
            mode=payload.mode.value,
            success=True,
            local_count=local_count,
            remote_count=len(remote_anime),
            local_status_counts=local_status_counts,
            remote_status_counts=remote_status_counts,
            remote_host=f"{payload.host}:{payload.port}",
        )

    # ── remote_overwrite：清空本地 → 导入远程数据 ──
    if payload.mode == LanSyncMode.remote_overwrite:
        await db.execute("DELETE FROM anime")
        result = ImportResult()
        for item in remote_anime:
            try:
                await db.execute(
                    """INSERT INTO anime
                       (title, cover_url, description, total_episodes, current_episode, status, score, air_date, bangumi_id)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                    (item.title, item.cover_url, item.description, item.total_episodes,
                     item.current_episode, item.status.value, item.score, item.air_date, item.bangumi_id),
                )
                result.imported += 1
            except Exception as e:
                result.errors.append(f"「{item.title}」导入失败: {str(e)}")
                result.skipped += 1
        await db.commit()
        return LanSyncResponse(
            mode=payload.mode.value,
            success=True,
            local_count=len(remote_anime),
            remote_count=len(remote_anime),
            local_status_counts=remote_status_counts,
            remote_status_counts=remote_status_counts,
            remote_host=f"{payload.host}:{payload.port}",
            message="远程数据已覆盖本地记录",
            result=result,
        )

    # ── local_overwrite：导出本地数据 → 推送到远程 ──
    if payload.mode == LanSyncMode.local_overwrite:
        cursor = await db.execute("SELECT * FROM anime")
        rows = await cursor.fetchall()
        local_anime = [AnimeCreate(**dict(row)) for row in rows]
        local_list = [a.model_dump() for a in local_anime]

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(
                    remote_import_url,
                    json={"anime_list": local_list},
                )
                resp.raise_for_status()
                remote_result = resp.json()
        except httpx.TimeoutException:
            raise HTTPException(status_code=504, detail="推送到远程设备时连接超时")
        except httpx.ConnectError:
            raise HTTPException(status_code=502, detail="推送到远程设备失败，请检查连接")
        except httpx.HTTPStatusError as e:
            raise HTTPException(status_code=502, detail=f"远程设备返回错误 ({e.response.status_code})")

        result = ImportResult(**remote_result)
        return LanSyncResponse(
            mode=payload.mode.value,
            success=True,
            local_count=len(local_anime),
            remote_count=len(local_anime),
            local_status_counts=local_status_counts,
            remote_status_counts=local_status_counts,
            remote_host=f"{payload.host}:{payload.port}",
            message="本地记录已推送到远程设备",
            result=result,
        )

    # ── merge：远程数据导入本地 + 本地数据推送到远程 ──
    if payload.mode == LanSyncMode.merge:
        # 1. 导入远程数据到本地（按 bangumi_id 匹配，存在则更新，不存在则新增）
        result = ImportResult()
        for item in remote_anime:
            try:
                if item.bangumi_id is not None:
                    cursor = await db.execute(
                        "SELECT id FROM anime WHERE bangumi_id = ?", (item.bangumi_id,)
                    )
                    existing = await cursor.fetchone()
                    if existing:
                        await db.execute(
                            """UPDATE anime
                               SET title = ?, cover_url = ?, description = ?,
                                   total_episodes = ?, current_episode = ?,
                                   status = ?, score = ?, air_date = ?,
                                   updated_at = datetime('now')
                               WHERE id = ?""",
                            (item.title, item.cover_url, item.description,
                             item.total_episodes, item.current_episode,
                             item.status.value, item.score, item.air_date,
                             existing["id"]),
                        )
                        result.updated += 1
                        continue

                await db.execute(
                    """INSERT INTO anime
                       (title, cover_url, description, total_episodes, current_episode, status, score, air_date, bangumi_id)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                    (item.title, item.cover_url, item.description, item.total_episodes,
                     item.current_episode, item.status.value, item.score, item.air_date, item.bangumi_id),
                )
                result.imported += 1
            except Exception as e:
                result.errors.append(f"「{item.title}」导入失败: {str(e)}")
                result.skipped += 1
        await db.commit()

        # 2. 将合并后的本地数据推送到远程
        cursor = await db.execute("SELECT * FROM anime")
        merged_rows = await cursor.fetchall()
        merged_anime = [AnimeCreate(**dict(row)) for row in merged_rows]
        merged_list = [a.model_dump() for a in merged_anime]

        remote_push_msg = ""
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(
                    remote_import_url,
                    json={"anime_list": merged_list},
                )
                resp.raise_for_status()
            remote_push_msg = "，远程设备已同步"
        except Exception as e:
            remote_push_msg = f"，推送到远程设备失败: {str(e)}"

        # 重新统计本地
        cursor = await db.execute("SELECT status, COUNT(*) as cnt FROM anime GROUP BY status")
        new_local_counts: dict[str, int] = {}
        for row in await cursor.fetchall():
            new_local_counts[row["status"]] = row["cnt"]

        return LanSyncResponse(
            mode=payload.mode.value,
            success=True,
            local_count=sum(new_local_counts.values()),
            remote_count=len(remote_anime),
            local_status_counts=new_local_counts,
            remote_status_counts=remote_status_counts,
            remote_host=f"{payload.host}:{payload.port}",
            message=f"数据已合并{remote_push_msg}",
            result=result,
        )
