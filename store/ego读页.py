# -*- coding: utf-8 -*-
"""ego-出海（CDP 9336）读 ASC 页面文本——找含关键词的标签页或指定 URL 前缀"""
import asyncio, json, sys, urllib.request
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
import websockets

def get_ws_url(match):
    req = urllib.request.Request("http://127.0.0.1:9336/json", headers={"Host": "localhost"})
    tabs = json.loads(urllib.request.urlopen(req, timeout=10).read())
    for t in tabs:
        if match in t["url"] and t["type"] == "page":
            u = t["webSocketDebuggerUrl"]
            if "127.0.0.1:9336" not in u and "localhost:9336" not in u:
                u = u.replace("ws://localhost", "ws://127.0.0.1:9336").replace("ws://127.0.0.1/", "ws://127.0.0.1:9336/")
            return u.replace("localhost", "127.0.0.1")
    return None

async def read(url_match, scroll_full=False):
    ws_url = get_ws_url(url_match)
    if not ws_url:
        print(f"未找到含 {url_match} 的标签页")
        return
    async with websockets.connect(ws_url, max_size=10 * 1024 * 1024) as ws:
        # 等 SPA 渲染
        await asyncio.sleep(2)
        js = "document.body.innerText"
        mid = 1
        await ws.send(json.dumps({"id": mid, "method": "Runtime.evaluate",
                                  "params": {"expression": js, "returnByValue": True}}))
        while True:
            msg = json.loads(await asyncio.sleep(30, ws.recv()) if False else await ws.recv())
            if msg.get("id") == mid:
                val = msg.get("result", {}).get("result", {}).get("value", "")
                print(val[:6000])
                return

if __name__ == "__main__":
    match = sys.argv[1] if len(sys.argv) > 1 else "appstoreconnect.apple.com/apps"
    asyncio.run(read(match))
