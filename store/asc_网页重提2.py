# -*- coding: utf-8 -*-
"""HyperLog 重提审·真实鼠标事件版（合成 .click() 打不开苹果弹窗，改 CDP Input 真实点击）
流程：开详情页 → 真点「重新提交至 App 审核」→ 弹窗出来 → 真点确认 → 读回状态 → 关标签
"""
import asyncio
import json
import sys
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
import websockets

CDP = "http://127.0.0.1:9336"
DETAILS = ("https://appstoreconnect.apple.com/apps/6830034297/distribution/"
           "reviewsubmissions/details/98c8b6c0-dc5b-423c-8e51-4c3e8e6a1662")


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
        ws = await websockets.connect(ws_url, max_size=20 * 1024 * 1024, **kw)
    except TypeError:
        ws = await websockets.connect(ws_url, max_size=20 * 1024 * 1024)
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

    async def real_click(js_rect):
        rect = json.loads(await ev(js_rect) or "null")
        if not rect:
            return None
        x, y = rect["x"] + rect["w"] / 2, rect["y"] + rect["h"] / 2
        for t in ("mousePressed", "mouseReleased"):
            await send("Input.dispatchMouseEvent", {
                "type": t, "x": x, "y": y, "button": "left",
                "clickCount": 1, "buttons": 1 if t == "mousePressed" else 0})
            await asyncio.sleep(0.12)
        return rect

    async with ws:
        await asyncio.sleep(12)

        dump = ("JSON.stringify([...document.querySelectorAll('button,a,[role=\"button\"]')]"
                ".filter(e=>e.getClientRects().length>0&&getComputedStyle(e).visibility!=='hidden')"
                ".map((e,i)=>({i,t:(e.textContent||'').trim().slice(0,30),tag:e.tagName})))")

        def rect_of(text, exact=True, maxlen=99):
            op = "===" if exact else ".includes"
            return (f"JSON.stringify((()=>{{const e=[...document.querySelectorAll("
                    f"'button,a,[role=\"button\"]')].find(e=>(e.textContent||'').trim(){op}"
                    f"{json.dumps(text)}&&(e.textContent||'').trim().length<={maxlen}"
                    f"&&e.getClientRects().length>0);if(!e)return null;"
                    f"const r=e.getBoundingClientRect();"
                    f"return {{x:r.x,y:r.y,w:r.width,h:r.height}};}})())")

        print("[点前按钮]", json.loads(await ev(dump) and await ev(dump))[:0] or "", end="")
        before = json.loads(await ev(dump))
        print([c["t"] for c in before if c["tag"] == "BUTTON"])

        r1 = await real_click(rect_of("重新提交至 App 审核"))
        print("[真点主按钮]", r1)
        await asyncio.sleep(3.5)

        cands = json.loads(await ev(dump))
        new = [c for c in cands if c not in before]
        print(f"[弹窗新增可点元素] {new}")

        pick = None
        for c in cands:
            t = c["t"]
            if t and len(t) <= 8 and ("提交" in t or "确认" in t or "Submit" in t) \
               and not any(k in t for k in ("取消", "Cancel", "草稿", "删除", "回复")):
                pick = c
                break
        if not pick:
            print("[点确认] ❌ 没识别到确认按钮，停手")
            print("[当前页面头部]\n" + str(await ev("(document.body.innerText||'').slice(0,500)")))
            return
        print(f"[要点的确认按钮] #{pick['i']} {pick['t']}")
        r2 = await real_click(rect_of(pick["t"]))
        print("[真点确认]", r2)
        await asyncio.sleep(5)

        fin = await ev("(document.body.innerText||'').slice(0,600)")
        print("[提交后页面头部]\n" + fin)


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
