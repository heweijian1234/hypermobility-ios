# -*- coding: utf-8 -*-
"""删掉 12:20 误建的空草稿提交单（76936acf），然后回详情页看重提按钮是否解禁。
轮询等 SPA 按钮渲染，shadow DOM 查找 + CDP 真实鼠标点击。
"""
import asyncio
import json
import sys
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
import websockets

CDP = "http://127.0.0.1:9336"
DRAFT = ("https://appstoreconnect.apple.com/apps/6830034297/distribution/"
         "reviewsubmissions/details/76936acf-b7ea-4c9c-be7f-dcd64b2af650")
DETAILS = ("https://appstoreconnect.apple.com/apps/6830034297/distribution/"
           "reviewsubmissions/details/98c8b6c0-dc5b-423c-8e51-4c3e8e6a1662")

JS_LIB = """
window.__roots=()=>{const out=[document];const walk=n=>{for(const e of n.querySelectorAll('*')){
  if(e.shadowRoot){out.push(e.shadowRoot);walk(e.shadowRoot);}}};walk(document);return out;};
window.__btns=()=>{const r=[];for(const root of window.__roots()){
  for(const b of root.querySelectorAll('button')){const t=(b.textContent||'').trim();
    if(t&&t.length<26&&b.getClientRects().length>0)r.push({t,dis:!!b.disabled});}}return r;};
window.__rect=t=>{for(const root of window.__roots()){
  const b=[...root.querySelectorAll('button')].find(x=>(x.textContent||'').trim()===t
    &&x.getClientRects().length>0);
  if(b){const r=b.getBoundingClientRect();return JSON.stringify({x:r.x,y:r.y,w:r.width,h:r.height});}}
  return null;};
true"""


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
        ws = await websockets.connect(ws_url, max_size=30 * 1024 * 1024, **kw)
    except TypeError:
        ws = await websockets.connect(ws_url, max_size=30 * 1024 * 1024)
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

    async def btns():
        return json.loads(await ev("JSON.stringify(window.__btns())") or "[]")

    async def wait_btns(timeout=30):
        for _ in range(timeout):
            lst = await btns()
            if lst:
                return lst
            await asyncio.sleep(1)
        return await btns()

    async def real_click(text):
        rect = json.loads(await ev(f"window.__rect({json.dumps(text)})") or "null")
        if not rect:
            print(f"    ⚠️ 无坐标: {text}")
            return False
        x, y = rect["x"] + rect["w"] / 2, rect["y"] + rect["h"] / 2
        for t, b in (("mousePressed", 1), ("mouseReleased", 0)):
            await send("Input.dispatchMouseEvent", {"type": t, "x": x, "y": y, "button": "left",
                                                     "clickCount": 1, "buttons": b})
            await asyncio.sleep(0.12)
        print(f"    真点「{text}」")
        return True

    async with ws:
        await ev(JS_LIB)

        print("① 直进草稿单页面")
        await ev(f"location.href={json.dumps(DRAFT)}")
        await asyncio.sleep(6)
        await ev(JS_LIB)
        lst = await wait_btns()
        print("   按钮:", [b["t"] for b in lst])

        print("② 删除草稿")
        if await real_click("删除提交"):
            await asyncio.sleep(2.5)
            lst2 = await wait_btns(8)
            print("   弹窗按钮:", [b["t"] for b in lst2])
            for cand in ("删除", "确认删除", "确认", "Delete", "移除"):
                if any(b["t"] == cand and not b["dis"] for b in lst2):
                    await real_click(cand)
                    break
            await asyncio.sleep(4)
            print("   删后按钮:", [b["t"] for b in await wait_btns(8)])
            print("   页面头部:", str(await ev("(document.body.innerText||'').slice(0,260)")))

        print("③ 回详情页看重提按钮")
        await ev(f"location.href={json.dumps(DETAILS)}")
        await asyncio.sleep(6)
        await ev(JS_LIB)
        lst3 = await wait_btns()
        main = next((b for b in lst3 if b["t"] == "重新提交至 App 审核"), None)
        print("   按钮:", [b["t"] for b in lst3])
        print(f"   重提 disabled = {main['dis'] if main else '按钮没了'}")


if __name__ == "__main__":
    tab = open_tab(DETAILS)
    ws_url = (tab.get("webSocketDebuggerUrl") or "").replace("localhost", "127.0.0.1")
    if ":9336" not in ws_url:
        ws_url = ws_url.replace("ws://127.0.0.1/", "ws://127.0.0.1:9336/")
    print("[开标签]")
    try:
        asyncio.run(run(ws_url))
    finally:
        try:
            http(f"/json/close/{tab.get('id')}")
            print("[已关标签]")
        except Exception:
            pass
