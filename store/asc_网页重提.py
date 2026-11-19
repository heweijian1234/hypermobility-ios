# -*- coding: utf-8 -*-
"""HyperLog 重提审·网页路线（API 对 UNRESOLVED_ISSUES 提交单全 409，网页按钮才是正路）
开新标签 → 进提交单详情页 → 点「重新提交至 App 审核」→ 处理确认弹窗 → 读回页面状态 → 关标签
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
    async with ws:
        mid = 0

        async def ev(js, wait=0.0):
            nonlocal mid
            mid += 1
            await ws.send(json.dumps({"id": mid, "method": "Runtime.evaluate",
                                      "params": {"expression": js, "returnByValue": True}}))
            while True:
                msg = json.loads(await ws.recv())
                if msg.get("id") == mid:
                    v = msg.get("result", {}).get("result", {}).get("value")
                    if wait:
                        await asyncio.sleep(wait)
                    return v

        await asyncio.sleep(12)  # SPA 渲染

        snap = ("JSON.stringify({b:[...document.querySelectorAll('button')]"
                ".map(x=>(x.textContent||'').trim()).filter(t=>t&&t.length<24),"
                "t:(document.body.innerText||'').slice(0,2600)})")

        # 0) 点之前的按钮快照
        before = json.loads(await ev(snap))
        print(f"[点前按钮 {len(before['b'])} 个] {before['b'][:25]}")

        # 1) 找「重新提交至 App 审核」按钮并点
        js1 = """(() => {
          const els=[...document.querySelectorAll('button,a,[role="button"],span')]
            .filter(e=>(e.textContent||'').trim()==='重新提交至 App 审核');
          if(!els.length) return '未找到按钮';
          let n=els[0]; while(n && n.tagName!=='BUTTON' && n.tagName!=='A') n=n.parentElement;
          (n||els[0]).click(); return '已点击: '+(n?n.tagName:els[0].tagName);
        })()"""
        print("[点主按钮]", await ev(js1, 3.5))

        # 2) 弹窗开着时，列出全部"可见"可点元素（tag+文本），存到 window 上备用
        js2 = """(() => {
          const els=[...document.querySelectorAll('button,a,[role="button"]')]
            .filter(e=>e.getClientRects().length>0
                       && getComputedStyle(e).visibility!=='hidden');
          window.__cands=els;
          return JSON.stringify(els.map((e,i)=>({i,tag:e.tagName,
            t:(e.textContent||'').trim().slice(0,30)})));
        })()"""
        cands = json.loads(await ev(js2))
        print(f"[可见可点元素 {len(cands)} 个]")
        for c in cands:
            print(f"   #{c['i']:>2} <{c['tag']}> {c['t']}")

        # 3) 选确认按钮：文本短且含 提交/确认/Submit，排除"重新提交至 App 审核"长文本与取消
        pick_i = None
        for c in cands:
            t = c["t"]
            if len(t) <= 8 and ("提交" in t or "确认" in t or "Submit" in t or "Confirm" in t) \
               and "取消" not in t and "Cancel" not in t \
               and "草稿" not in t and "删除" not in t:
                pick_i = c["i"]
                break
        if pick_i is None:
            print("[点确认] ❌ 没识别到确认按钮，停手不瞎点")
        else:
            r3 = await ev(f"(() => {{ const e=window.__cands[{pick_i}]; e.click(); "
                          f"return '已点 #'+{pick_i}+' '+((e.textContent||'').trim()); }})()", 4.0)
            print("[点确认]", r3)

        # 4) 读回页面状态
        fin = json.loads(await ev(snap))
        print("[提交后页面头部]\n" + fin["t"][:700])
        print(f"[提交后按钮] {fin['b'][:20]}")


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
