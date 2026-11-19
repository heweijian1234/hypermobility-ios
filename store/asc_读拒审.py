# -*- coding: utf-8 -*-
"""用 ego-出海（CDP 9336）开新标签读 ASC 指定页面文本，读完关标签（只读纪律）。
用法：python asc_读拒审.py <URL> [等待秒]
"""
import asyncio
import json
import sys
import time
import urllib.request

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
import websockets

CDP = "http://127.0.0.1:9336"


def http(path, method="GET"):
    req = urllib.request.Request(CDP + path, method=method, headers={"Host": "localhost"})
    with urllib.request.urlopen(req, timeout=15) as r:
        return r.read().decode("utf-8", "replace")


def open_tab(url):
    # 新版 Chrome 要求 PUT
    for m in ("PUT", "GET"):
        try:
            body = http("/json/new?" + urllib.parse.quote(url, safe=":/?&=%"), m)
            return json.loads(body)
        except Exception:
            continue
    raise RuntimeError("开新标签失败")


def close_tab(tid):
    try:
        http(f"/json/close/{tid}")
    except Exception as e:
        print(f"[关标签失败 {e}]")


async def read_text(ws_url, wait, expr=None):
    kw = {}
    try:
        kw["suppress_origin"] = True  # ws 握手 403 修法
        ws = await websockets.connect(ws_url, max_size=20 * 1024 * 1024, **kw)
    except TypeError:
        kw.pop("suppress_origin", None)
        ws = await websockets.connect(ws_url, max_size=20 * 1024 * 1024)
    async with ws:
        await asyncio.sleep(wait)
        mid = 1
        expr = ("JSON.stringify({url:location.href,title:document.title,"
                "text:(document.body.innerText||'').slice(0,9000),"
                "links:Array.from(document.querySelectorAll('a[href]')).slice(0,120)"
                ".map(a=>(a.textContent||'').trim().slice(0,28)+' => '+a.href)"
                ".filter(s=>s.length>6).slice(0,60)})")
        await ws.send(json.dumps({"id": mid, "method": "Runtime.evaluate",
                                  "params": {"expression": expr, "returnByValue": True}}))
        while True:
            msg = json.loads(await ws.recv())
            if msg.get("id") == mid:
                v = msg.get("result", {}).get("result", {}).get("value", "") or ""
                try:
                    d = json.loads(v)
                    lk = "\n".join(d.get("links", []) or [])
                    return (f"[最终URL] {d.get('url')}\n[标题] {d.get('title')}\n\n"
                            f"{d.get('text','')}\n\n----- 页面链接 -----\n{lk}")
                except Exception:
                    return v


if __name__ == "__main__":
    import urllib.parse
    target = sys.argv[1]
    wait = int(sys.argv[2]) if len(sys.argv) > 2 else 9
    t0 = time.time()
    tab = open_tab(target)
    tid = tab.get("id")
    ws_url = (tab.get("webSocketDebuggerUrl") or "").replace("localhost", "127.0.0.1")
    if ":9336" not in ws_url:
        ws_url = ws_url.replace("ws://127.0.0.1/", "ws://127.0.0.1:9336/")
    print(f"[开标签] {target}\n[ws] {ws_url}\n等待渲染 {wait}s ...")
    try:
        txt = asyncio.run(read_text(ws_url, wait))
        print("=" * 70)
        print(txt[:9000])
        print("=" * 70)
        print(f"[字数 {len(txt)} | 耗时 {time.time() - t0:.0f}s]")
    finally:
        close_tab(tid)
        print("[已关标签]")
