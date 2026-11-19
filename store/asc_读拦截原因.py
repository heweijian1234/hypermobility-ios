# -*- coding: utf-8 -*-
"""读原提交单详情页的完整正文（含 shadow DOM），找重提按钮灰的拦截原因。"""
import asyncio
import base64
import json
import sys
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
import websockets

CDP = "http://127.0.0.1:9336"
DETAILS = ("https://appstoreconnect.apple.com/apps/6830034297/distribution/"
           "reviewsubmissions/details/98c8b6c0-dc5b-423c-8e51-4c3e8e6a1662")

# IIFE 递归抓全部 shadow root 文本
JS = r"""(() => {
  const out = [document];
  const walk = (n) => {
    for (const e of n.querySelectorAll('*')) {
      if (e.shadowRoot) { out.push(e.shadowRoot); walk(e.shadowRoot); }
    }
  };
  walk(document);
  let txt = document.body ? (document.body.innerText || '') : '';
  for (const r of out.slice(1)) txt += '\n===shadow===\n' + (r.textContent || '');
  return txt;
})()"""


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
        return (r.get("result") or {}).get("value")

    async with ws:
        await ev(f"location.href={json.dumps(DETAILS)}")
        # SPA 慢渲染：轮询到正文出现（含"重新提交"字样）再读
        txt = ""
        for i in range(30):
            await asyncio.sleep(1)
            txt = await ev(JS) or ""
            if "重新提交" in txt or "重新提交" in (txt or ""):
                break
        print("=== 页面正文（含 shadow DOM）===")
        print((txt or "")[:4500])


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
