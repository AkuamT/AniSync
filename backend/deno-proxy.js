/**
 * AniSync — Bangumi API 反向代理 (Deno Deploy)
 *
 * 用途：国内网络环境下 api.bgm.tv / lain.bgm.tv 被封锁，
 * 部署此代理到 Deno Deploy 后可中转所有 API 请求和图片加载。
 *
 * 部署步骤：
 *   1. 打开 https://dash.deno.com 用 GitHub 登录
 *   2. 点击右上角 New Playground
 *   3. 将本文件全部内容粘贴到编辑器中
 *   4. 点击右上角 Save & Deploy
 *   5. 复制得到的域名（如 https://xxx.deno.net）
 *   6. 在项目根目录 .env 中设置:
 *      BANGUMI_BASE_URL=https://xxx.deno.net
 *   7. 重启后端
 */

const BANGUMI_API = "https://api.bgm.tv";
const IMG_CDN = "https://lain.bgm.tv";

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const path = url.pathname;

  // 图片代理：/img/... → lain.bgm.tv/...
  if (path.startsWith("/img/")) {
    const imgUrl = IMG_CDN + path.replace("/img", "");
    try {
      const imgResp = await fetch(imgUrl);
      const headers = new Headers();
      const ct = imgResp.headers.get("Content-Type");
      if (ct) headers.set("Content-Type", ct);
      headers.set("Access-Control-Allow-Origin", "*");
      headers.set("Cache-Control", "public, max-age=86400");
      return new Response(imgResp.body, { status: imgResp.status, headers });
    } catch (e) {
      return new Response(null, { status: 502 });
    }
  }

  // API 代理：/v0/... → api.bgm.tv/v0/...
  const targetUrl = BANGUMI_API + path + url.search;

  try {
    const resp = await fetch(targetUrl, {
      method: req.method,
      headers: {
        "User-Agent": "Akuam/AniSync-App (https://github.com/akuam/AniSync)",
        "Content-Type": "application/json",
      },
      body: req.method === "POST" ? await req.text() : undefined,
    });

    let body = await resp.text();

    // 将响应中的 lain.bgm.tv 图片链接替换为代理链接
    body = body.replaceAll("https://lain.bgm.tv", url.origin + "/img");

    return new Response(body, {
      status: resp.status,
      headers: {
        "Content-Type": resp.headers.get("Content-Type") || "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ error: "代理请求失败", detail: String(e) }),
      { status: 502, headers: { "Content-Type": "application/json" } }
    );
  }
});
