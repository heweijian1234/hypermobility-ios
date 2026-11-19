# -*- coding: utf-8 -*-
"""HyperLog 拒审重提修复（2026-11-06）：
苹果对 UNRESOLVED_ISSUES 提交单的要求＝先把被拒的提交项移除，再重新挂版本，最后把提交单 submitted 置真。
另：清掉 12:20 误建的空提交单。
"""
import importlib.util
import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

mod_path = Path(r"E:\AI-Projects\个人成长\10-项目\SaaS项目\hypermobility-ios\store\asc_备注与重提.py")
spec = importlib.util.spec_from_file_location("ascmod", mod_path)
ascmod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ascmod)
asc, err_text = ascmod.asc, ascmod.err_text

SUB_OLD = "98c8b6c0-dc5b-423c-8e51-4c3e8e6a1662"
SUB_NEW = "76936acf-b7ea-4c9c-be7f-dcd64b2af650"   # 12:20 误建的空单
VER = "14fbb754-86a3-4aa6-88ff-1f82fe7fe7fa"

print("=" * 66)
print("① 老提交单的现有项")
st, r = asc(f"/reviewSubmissions/{SUB_OLD}/items")
print(f"HTTP {st}")
old_items = []
for it in r.get("data", []):
    a = it["attributes"]
    old_items.append((it["id"], a.get("state")))
    print(f"  item {it['id'][:28]}… 状态={a.get('state')}")
if r.get("errors"):
    print("  错误:", err_text(r))

print("=" * 66)
print("② 移除被拒项")
for iid, state in old_items:
    st, r = asc(f"/reviewSubmissionItems/{iid}", "DELETE")
    print(f"  删 {iid[:28]}…({state}) → HTTP {st}" + ("" if st in (200, 204) else f": {err_text(r)}"))

print("=" * 66)
print("③ 清掉误建的空提交单")
st, r = asc(f"/reviewSubmissions/{SUB_NEW}/items")
n = len(r.get("data", []))
print(f"  空单里现有 {n} 项")
if n == 0:
    st, r = asc(f"/reviewSubmissions/{SUB_NEW}", "DELETE")
    print(f"  删除空单 → HTTP {st}" + ("" if st in (200, 204) else f": {err_text(r)}"))

print("=" * 66)
print("④ 把版本重新挂回老提交单")
st, r = asc("/reviewSubmissionItems", "POST", {
    "data": {"type": "reviewSubmissionItems",
             "relationships": {
                 "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": SUB_OLD}},
                 "appStoreVersion": {"data": {"type": "appStoreVersions", "id": VER}}}}})
if st in (200, 201):
    print(f"  ✅ 已挂回 item={r['data']['id'][:28]}… 状态={r['data']['attributes'].get('state')}")
else:
    print(f"  ❌ HTTP {st}: {err_text(r)}")
    sys.exit(1)

print("=" * 66)
print("⑤ 提交单 submitted 置真")
st, r = asc(f"/reviewSubmissions/{SUB_OLD}", "PATCH", {
    "data": {"type": "reviewSubmissions", "id": SUB_OLD,
             "attributes": {"submitted": True}}})
if st in (200, 204):
    print("  ✅ 已重新提交")
else:
    print(f"  ❌ HTTP {st}: {err_text(r)}")
    sys.exit(1)

print("=" * 66)
print("⑥ 终态核对")
st, r = asc(f"/apps/{ascmod.APP_ID}/appStoreVersions?filter[platform]=IOS&limit=2")
for v in r.get("data", []):
    print(f"  版本 {v['attributes'].get('versionString')} 状态={v['attributes'].get('appStoreState')}")
st, r = asc(f"/reviewSubmissions?filter[app]={ascmod.APP_ID}&limit=3")
for d in r.get("data", []):
    print(f"  提交单 {d['id'][:18]}… 状态={d['attributes'].get('state')}")
