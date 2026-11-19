# -*- coding: utf-8 -*-
"""HyperLog 重提审·终版路线（2026-11-06 截图实证）：
①「重新提交至 App 审核」按钮灰=被我 12:20 误建的空草稿提交单挡住 → 先删草稿
② 弹窗确认键在 tb-modal 的 shadow DOM 里 → 走 shadowRoot 找按钮 + CDP 真实鼠标坐标点击
流程：详情页 → 点右下「草稿提交 (1)」→ 草稿页点「删除提交」→ 弹窗确认删
     → 回详情页 → 点「重新提交至 App 审核」→ 弹窗确认 → 读回状态
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

# 含 shadow DOM 的按钮查找/列举
JS_ROOTS = """
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
window.__click=t=>{for(const root of window.__roots()){
  const b=[...root.querySelectorAll('button')].find(x=>(x.textContent||'').trim()===t);
  if(b){b.click();return 'clicked';}}return 'notfound';};
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
        return json.loads(await ev("JSON.stringify(window.__btns())"))

    async def real_click(text):
        rect = json.loads(await ev(f"window.__rect({json.dumps(text)})") or "null")
        if not rect:
            print(f"    ⚠️ 找不到按钮坐标: {text}")
            return False
        x, y = rect["x"] + rect["w"] / 2, rect["y"] + rect["h"] / 2
        for t, b in (("mousePressed", 1), ("mouseReleased", 0)):
            await send("Input.dispatchMouseEvent", {"type": t, "x": x, "y": y,
                                                     "button": "left", "clickCount": 1, "buttons": b})
            await asyncio.sleep(0.12)
        print(f"     真点「{text}」@({x:.0f},{y:.0f})")
        return True

    async with ws:
        await asyncio.sleep(12)
        await ev(JS_ROOTS)

        print("① 进草稿提交单")
        print("   当前按钮:", [b["t"] for b in await btns()])
        await ev("window.__click('草稿提交 (1)')")
        await asyncio.sleep(5)
        await ev(JS_ROOTS)
        print("   草稿页按钮:", [b["t"] for b in await btns()])

        print("② 删除草稿")
        if await real_click("删除提交"):
            await asyncio.sleep(2.5)
            print("   弹窗按钮:", [b["t"] for b in await btns()])
            for cand in ("删除", "确认删除", "确认", "Delete"):
                if any(b["t"] == cand for b in await btns()):
                    await real_click(cand)
                    break
            await asyncio.sleep(4)
        print("   删后按钮:", [b["t"] for b in await btns()])

        print("③ 回详情页点重提")
        await ev(f"location.href={json.dumps(DETAILS)}")
        await asyncio.sleep(9)
        await ev(JS_ROOTS)
        lst = await btns()
        print("   详情页按钮:", lst)
        main = next((b for b in lst if b["t"] == "重新提交至 App 审核"), None)
        if not main:
            print("   ❌ 没有重提按钮")
            return
        print(f"   重提按钮 disabled={main['dis']}")
        if main["dis"]:
            print("   ❌ 仍是灰的，停手（说明还有别的挡路项）")
            return
        await ev("window.__click('重新提交至 App 审核')")
        await asyncio.sleep(3.5)
        print("   弹窗按钮:", [b["t"] for b in await btns()])
        for cand in ("重新提交", "提交", "确认", "Submit", "Resubmit"):
            if any(b["t"] == cand and not b["dis"] for b in await btns()):
                await real_click(cand)
                break
        await asyncio.sleep(6)
        print("④ 提交后页面头部:")
        print(str(await ev("(document.body.innerText||'').slice(0,420)")))


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
