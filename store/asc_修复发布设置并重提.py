# -*- coding: utf-8 -*-
"""HyperLog 0.1.0 拒审重提·修病根版（2026-11-06 健哥拍板 A 案）

病根：11-05 提审时版本设了 SCHEDULEED + 最早发布日期 2026-11-05，
拒审拖过日期 → 版本进入"不可审核"状态 → 网页重提按钮灰（草稿单是冤枉的）。

修复链（本脚本一次跑完）：
  ① PATCH 版本 → releaseType=AFTER_APPROVAL（过审后手动发布）+ 清掉过期日期
  ② 给草稿提交单 76936acf 挂上版本 14fbb754（废物利用当重提通道）
  ③ PATCH 提交单 submitted=True → 正式重提
  ④ 复核：版本状态应为 WAITING_FOR_REVIEW

用法：python asc_修复发布设置并重提.py          # 全链执行
      python asc_修复发布设置并重提.py --dry    # 只读看现状
"""
import base64
import json
import sys
import time
import urllib.error
import urllib.request

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

KEY_ID = "L3UHT69Y77"
ISSUER_ID = "98812827-46d0-4c8f-9b91-35d4f783e6df"
P8_PATH = r"E:\AI-Projects\个人成长\50-Skills\密钥\苹果\AuthKey_L3UHT69Y77.p8"
BASE = "https://api.appstoreconnect.apple.com/v1"

VER_ID = "14fbb754-86a3-4aa6-88ff-1f82fe7fe7fa"          # 0.1.0 build 26
DRAFT_ID = "76936acf-b7ea-4c9c-be7f-dcd64b2af650"        # 12:20 误建的空提交单（现当重提通道用）

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.serialization import load_pem_private_key


def b64url(d):
    return base64.urlsafe_b64encode(d).rstrip(b"=").decode()


def make_jwt():
    key = load_pem_private_key(open(P8_PATH, "rb").read(), password=None)
    h = b64url(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}).encode())
    p = b64url(json.dumps({"iss": ISSUER_ID, "iat": int(time.time()),
                           "exp": int(time.time()) + 1200,
                           "aud": "appstoreconnect-v1"}).encode())
    sig = key.sign(f"{h}.{p}".encode(), ec.ECDSA(hashes.SHA256()))

    def raw(s):
        i = 2
        if s[1] & 0x80:
            i += s[1] & 0x7f

        def ri():
            nonlocal i
            i += 1
            ln = s[i]
            i += 1
            if ln & 0x80:
                n = ln & 0x7f
                ln = 0
                for _ in range(n):
                    ln = (ln << 8) | s[i]
                    i += 1
            v = int.from_bytes(s[i:i + ln], "big")
            i += ln
            return v.to_bytes(32, "big")

        return ri() + ri()

    return f"{h}.{p}.{b64url(raw(sig))}"


JWT = make_jwt()


def asc(path, method="GET", body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method, headers={
        "Authorization": f"Bearer {JWT}",
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=40) as r:
            t = r.read()
            return r.status, (json.loads(t) if t else {})
    except urllib.error.HTTPError as e:
        t = e.read()
        try:
            return e.code, json.loads(t)
        except Exception:
            return e.code, {"_raw": t.decode("utf-8", "replace")[:500]}


def err_text(r):
    if r.get("errors"):
        parts = []
        for e in r["errors"]:
            parts.append(f"{e.get('code')}: {e.get('detail')}")
            for ae in (e.get("meta", {}).get("associatedErrors", {}) or {}).values():
                for x in ae:
                    parts.append(f"└ {x.get('code')}: {x.get('detail')}")
        return " | ".join(parts)[:500]
    return r.get("_raw") or json.dumps(r, ensure_ascii=False)[:300]


def show_now():
    st, r = asc(f"/appStoreVersions/{VER_ID}")
    if st == 200:
        a = r["data"]["attributes"]
        print(f"   版本 {a.get('versionString')}: 状态={a.get('appStoreState')} "
              f"发布类型={a.get('releaseType')} 最早发布={a.get('earliestReleaseDate')}")
    st, r = asc(f"/reviewSubmissions?filter[app]=6830034297&limit=5")
    for d in r.get("data", []):
        a = d["attributes"]
        print(f"   提交单 {d['id'][:8]}: {a.get('state')}")


if __name__ == "__main__":
    dry = "--dry" in sys.argv

    print("=" * 60)
    print("当前状态：")
    show_now()
    if dry:
        sys.exit(0)
    print("=" * 60)

    print("① 修复版本：SCHEDULED+过期日期 → AFTER_APPROVAL（过审后手动发布）")
    st, r = asc(f"/appStoreVersions/{VER_ID}", "PATCH", {
        "data": {"type": "appStoreVersions", "id": VER_ID,
                 "attributes": {"releaseType": "AFTER_APPROVAL",
                                "earliestReleaseDate": None}}})
    if st not in (200, 204):
        print(f"❌ 失败 HTTP {st}: {err_text(r)}")
        sys.exit(1)
    print("   ✅ 已改为过审后手动发布，过期日期已清除")

    print("② 给提交单挂上版本 0.1.0")
    st, r = asc("/reviewSubmissionItems", "POST", {
        "data": {"type": "reviewSubmissionItems",
                 "relationships": {
                     "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": DRAFT_ID}},
                     "appStoreVersion": {"data": {"type": "appStoreVersions", "id": VER_ID}},
                 }}})
    if st not in (200, 201):
        print(f"❌ 失败 HTTP {st}: {err_text(r)}")
        sys.exit(1)
    print(f"   ✅ 已挂载（item {r['data']['id'][:16]}…）")

    print("③ 提交审核")
    st, r = asc(f"/reviewSubmissions/{DRAFT_ID}", "PATCH", {
        "data": {"type": "reviewSubmissions", "id": DRAFT_ID,
                 "attributes": {"submitted": True}}})
    if st not in (200, 204):
        print(f"❌ 失败 HTTP {st}: {err_text(r)}")
        sys.exit(1)
    print("   ✅ 已提交")

    print("=" * 60)
    print("提交后状态：")
    time.sleep(3)
    show_now()
    print("=" * 60)
    print("判定：版本状态 = WAITING_FOR_REVIEW 即重提成功")
