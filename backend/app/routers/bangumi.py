import os
import time
from collections import OrderedDict
from fastapi import APIRouter, Query, HTTPException
import httpx

router = APIRouter(prefix="/api/bangumi", tags=["bangumi"])

# ── 支持自定义 API 地址（用于 Cloudflare Worker / 自建反代）──
BANGUMI_BASE = os.getenv("BANGUMI_BASE_URL", "https://near-lorikeet-74.akuamt.deno.net").rstrip("/")
BANGUMI_USER_AGENT = "Akuam/AniSync-App (https://github.com/akuam/AniSync)"

# ── HTTP 代理支持（国内环境可能需要通过代理访问）──
_httpx_proxy = os.getenv("BANGUMI_HTTPS_PROXY") or os.getenv("HTTPS_PROXY") or None

# ── 简易内存缓存：避免相同关键词重复请求（TTL 60s）──
_search_cache: OrderedDict[str, tuple[float, list]] = OrderedDict()
CACHE_TTL = 60  # seconds
CACHE_MAX = 128  # max entries


def transform_anime(item: dict) -> dict | None:
    """将 Bangumi API v0 的 subject 条目转换为前端所需格式。"""
    subject_id = item.get("id")
    if subject_id is None:
        return None

    # 优先使用中文名，回退到日文名
    title = item.get("name_cn") or item.get("name", "")

    # Bangumi 图片字段：large > common > medium > small
    images = item.get("images") or {}
    cover_url = (
        images.get("large")
        or images.get("common")
        or images.get("medium")
        or images.get("small")
    )

    # air_date 直接为 "YYYY-MM-DD" 字符串
    air_date = item.get("air_date") or None

    # v0 API 中 eps 可能为 null，尝试从 total_episodes 字段取
    total_episodes = item.get("eps") or item.get("total_episodes") or 0

    return {
        "bangumi_id": subject_id,
        "title": title,
        "cover_url": cover_url,
        "description": item.get("summary", ""),
        "total_episodes": total_episodes,
        "air_date": air_date,
    }


@router.get("/search")
async def search_anime(
    keyword: str = Query(..., min_length=1),
    limit: int = Query(10, ge=1, le=25),
):
    cache_key = f"{keyword.strip().lower()}:{limit}"

    # 命中缓存且未过期则直接返回
    if cache_key in _search_cache:
        ts, data = _search_cache[cache_key]
        if time.time() - ts < CACHE_TTL:
            _search_cache.move_to_end(cache_key)
            return {"results": data}

    client_kwargs = {
        "timeout": 8.0,
        "headers": {
            "User-Agent": BANGUMI_USER_AGENT,
            "Content-Type": "application/json",
        },
    }
    if _httpx_proxy:
        client_kwargs["proxy"] = _httpx_proxy

    try:
        async with httpx.AsyncClient(**client_kwargs) as client:
            resp = await client.post(
                f"{BANGUMI_BASE}/v0/search/subjects",
                json={
                    "keyword": keyword,
                    "sort": "match",
                    "filter": {
                        "type": [2],  # 2 = 动画
                    },
                },
                params={
                    "limit": limit,
                    "offset": 0,
                },
            )
            resp.raise_for_status()
            data = resp.json()
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Bangumi API 请求超时，请稍后重试")
    except httpx.HTTPStatusError as e:
        status = e.response.status_code
        if status == 429:
            raise HTTPException(status_code=503, detail="Bangumi API 请求频率过高，请稍后重试")
        raise HTTPException(status_code=502, detail=f"Bangumi API 返回错误 ({status})")
    except httpx.RequestError:
        raise HTTPException(status_code=502, detail="无法连接 Bangumi API，请检查网络或设置 BANGUMI_BASE_URL 环境变量")

    # v0 API 响应格式：{"data": [...], "total": N, "limit": N, "offset": N}
    raw_results = data.get("data", [])
    results = [r for r in (transform_anime(item) for item in raw_results) if r is not None]

    # 写入缓存，超出上限时淘汰最旧条目
    _search_cache[cache_key] = (time.time(), results)
    if len(_search_cache) > CACHE_MAX:
        _search_cache.popitem(last=False)

    return {"results": results}
