from fastapi import APIRouter, Query
import httpx

router = APIRouter(prefix="/api/bangumi", tags=["bangumi"])

JIKAN_BASE = "https://api.jikan.moe/v4"


def transform_anime(item: dict) -> dict:
    images = item.get("images", {})
    jpg = images.get("jpg", {})
    return {
        "bangumi_id": item.get("mal_id"),
        "title": item.get("title", ""),
        "cover_url": jpg.get("large_image_url") or jpg.get("image_url"),
        "description": item.get("synopsis", ""),
        "total_episodes": item.get("episodes") or 0,
        "air_date": (item.get("aired") or {}).get("from", ""),
    }


@router.get("/search")
async def search_anime(
    keyword: str = Query(..., min_length=1),
    limit: int = Query(10, ge=1, le=25),
):
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(
            f"{JIKAN_BASE}/anime",
            params={"q": keyword, "type": "tv", "sfw": True, "limit": limit},
        )
        resp.raise_for_status()
        data = resp.json()

    results = [transform_anime(item) for item in data.get("data", [])]
    return {"results": results}
