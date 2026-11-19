# -*- coding: utf-8 -*-
"""点「重新提交至 App 审核」后截图+探针，看弹窗到底出没出来、长什么样"""
import asyncio
import base64
import json
import sys
import urllib.parse
import urllib.request
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
import websockets

CDP = "http://127.0.0.1:9336"
DETAILS = ("https://appstoreconnect.apple.com/apps/6830034297/distribution/"
           "reviewsubmissions/details/98c8b6c0-dc5b-423c-8e51-4c3e8e6a1662")
SHOT = Path(r"E:\AI-Projects\个人成长\10-项目\SaaS项目\hypermobility-ios\store\review_media\_弹窗截图.png")


def http(path, method="GET"):
    req = urllib.request.Request(CDP + path, method=method, headers={"Host": "localhost"})
    with urllib.request.urlopen(req, timeout=15) as r:
        return r.read().decode("utf-8", "replace")


def open_tab(url):
    for m in ("PUT", "GET"):
        try:
            return json.loads(http("/json/new?" + urllib.parse.quote(url, safe=":/?&=%"), m))
        except Exception:
            continue
    raise RuntimeError("开新标签失败")


async def run(ws_url):
    kw = {}
    try:
        kw["suppress_origin"] = True
        ws = await websockets.connect(ws_url, max_size=40 * 1024 * 1024, **kw)
    except TypeError:
        ws = await websockets.connect(ws_url, max_size=40 * 1024 * 1024)
    mid = 0

    async def send(method, params=None):
        nonlocal mid
        mid += 1
        await ws.send(json.dumps({"id": mid, "method": method, "params": params or {}}))
        while True:
            msg = json.loads(await ws.recv())
            if msg.get("id") == mid:
                return msg.get("result", {})

    async def ev(js):
        r = await send("Runtime.evaluate", {"expression": js, "returnByValue": True})
        return r.get("result", {}).get("value")

    async with ws:
        await asyncio.sleep(12)
        await ev("""(() => {
          const e=[...document.querySelectorAll('button')]
            .find(b=>(b.textContent||'').trim()==='重新提交至 App 审核');
          if(e) e.click(); return !!e; })()""")
        await asyncio.sleep(4)

        probe = await ev("""JSON.stringify({
          dialogs:[...document.querySelectorAll('[role="dialog"],[aria-modal="true"]')]
            .map(d=>({tag:d.tagName, cls:String(d.className).slice(0,50),
                      txt:(d.innerText||'').slice(0,400)})),
          modal_cls:[...document.querySelectorAll('div,section')]
            .filter(e=>/modal|Modal|dialog|Dialog|overlay|Overlay/.test(String(e.className)))
            .slice(0,6).map(e=>({cls:String(e.className).slice(0,60),
                                 vis:e.getClientRects().length>0,
                                 txt:(e.innerText||'').slice(0,200)})),
          fixed:[...document.querySelectorAll('*')]
            .filter(e=>{const s=getComputedStyle(e);return s.position==='fixed'
                        &&e.getClientRects().length>0&&(e.innerText||'').length>5;})
            .slice(0,6).map(e=>({tag:e.tagName, cls:String(e.className).slice(0,50),
                                 txt:(e.innerText||'').slice(0,250)}))
        })""")
        d = json.loads(probe)
        print("[role=dialog 数量]", len(d["dialogs"]))
        for x in d["dialogs"]:
            print("   ", x["tag"], x["cls"], "\n     文本:", x["txt"][:300].replace("\n", " / "))
        print("[class 含 modal/dialog/overlay]", len(d["modal_cls"]))
        for x in d["modal_cls"]:
            print(f"    vis={x['vis']} {x['cls']} :: {x['txt'][:120].replace(chr(10),' / ')}")
        print("[position:fixed 且有点内容的]", len(d["fixed"]))
        for x in d["fixed"]:
            print(f"    <{x['tag']}> {x['cls']} :: {x['txt'][:200].replace(chr(10),' / ')}")

        shot = await send("Page.captureScreenshot", {"format": "png"})
        data = shot.get("data")
        if data:
            SHOT.write_bytes(base64.b64decode(data))
            print(f"[截图] {SHOT} ({SHOT.stat().st_size//1024}KB)")
        else:
            print("[截图失败]", shot)


if __name__ == "__main__":
    tab = open_tab(DETAILS)
    ws_url = (tab.get("webSocketDebuggerUrl") or "").replace("localhost", "127.0.0.1")
    if ":9336" not in ws_url:
        ws_url = ws_url.replace("ws://127.0.0.1/", "ws://127.0.0.1:9336/")
    print(f"[开标签] {DETAILS}")
    try:
        asyncio.run(run(ws_url))
    finally:
        try:
            http(f"/json/close/{tab.get('id')}")
            print("[已关标签]")
        except Exception:
            pass
