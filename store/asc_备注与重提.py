# -*- coding: utf-8 -*-
"""HyperLog 拒审补件工具：写「App 审核信息 → 备注」+ 重新提交审核（2026-11-06 健哥授权 API 全做）

用法：
  python asc_备注与重提.py                      # 只读：版本状态/审核详情id/当前备注/提交单状态
  python asc_备注与重提.py --write 备注.txt      # 写入备注（UTF-8 文本文件）
  python asc_备注与重提.py --resubmit            # 重新提交审核（先复用原提交单，失败则新建）
  python asc_备注与重提.py --write 备注.txt --resubmit
"""
import argparse
import base64
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

KEY_ID = "L3UHT69Y77"
ISSUER_ID = "98812827-46d0-4c8f-9b91-35d4f783e6df"
P8_PATH = r"E:\AI-Projects\个人成长\50-Skills\密钥\苹果\AuthKey_L3UHT69Y77.p8"
APP_ID = "6830034297"
BASE = "https://api.appstoreconnect.apple.com/v1"

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
    url = path if path.startswith("http") else BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {JWT}",
        "Content-Type": "application/json",
    })
    for attempt in range(3):
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
        except Exception as e:
            if attempt == 2:
                return -1, {"_err": str(e)}
            time.sleep(2)


def err_text(r):
    if r.get("errors"):
        return " | ".join(f"{e.get('code')}: {e.get('detail')}" for e in r["errors"])[:400]
    return r.get("_raw") or r.get("_err") or json.dumps(r, ensure_ascii=False)[:300]


# ---------- 只读：定位版本 / 审核详情 / 提交单 ----------
def get_version():
    st, r = asc(f"/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=3")
    if st != 200:
        print(f"❌ 取版本失败 HTTP {st}: {err_text(r)}")
        return None, None
    for v in r.get("data", []):
        a = v["attributes"]
        print(f"[版本] {a.get('versionString')} id={v['id']} 状态={a.get('appStoreState')}")
        return v["id"], a.get("appStoreState")
    return None, None


def get_review_detail(ver_id):
    st, r = asc(f"/appStoreVersions/{ver_id}/appStoreReviewDetail")
    if st != 200:
        print(f"❌ 取审核详情失败 HTTP {st}: {err_text(r)}")
        return None, None
    data = r.get("data")
    items = data if isinstance(data, list) else ([data] if isinstance(data, dict) else [])
    for d in items:
        a = d.get("attributes", {})
        notes = a.get("notes") or ""
        print(f"[审核详情] id={d['id']}")
        print(f"  全部字段: {json.dumps({k: v for k, v in a.items() if k != 'notes'}, ensure_ascii=False)}")
        print(f"  联系: {a.get('contactFirstName')} {a.get('contactLastName')} / "
              f"{a.get('contactEmail')} / {a.get('contactPhone')}")
        print(f"  需要登录: {a.get('loginRequired')}")
        print(f"  当前备注长度: {len(notes)}")
        if notes:
            print("  备注前 300 字:", notes[:300].replace("\n", " / "))
        return d["id"], notes
    return None, None


def get_submissions():
    st, r = asc(f"/reviewSubmissions?filter[app]={APP_ID}&include=items&limit=3")
    if st != 200:
        print(f"❌ 取提交单失败 HTTP {st}: {err_text(r)}")
        return None, None
    for d in r.get("data", []):
        a = d["attributes"]
        print(f"[提交单] id={d['id']} 状态={a.get('state')} 提交={str(a.get('submittedDate'))[:19]}")
        return d["id"], a.get("state")
    return None, None


# ---------- 写：备注 ----------
def write_notes(detail_id, text):
    st, r = asc(f"/appStoreReviewDetails/{detail_id}", "PATCH", {
        "data": {"type": "appStoreReviewDetails", "id": detail_id,
                 "attributes": {"notes": text}}})
    if st in (200, 204):
        print(f"✅ 备注已写入（{len(text)} 字）HTTP {st}")
        return True
    print(f"❌ 写备注失败 HTTP {st}: {err_text(r)}")
    return False


# ---------- 写：重新提交 ----------
def resubmit(ver_id, sub_id):
    # 路线一：复用原提交单，直接把 submitted 置真
    if sub_id:
        st, r = asc(f"/reviewSubmissions/{sub_id}", "PATCH", {
            "data": {"type": "reviewSubmissions", "id": sub_id,
                     "attributes": {"submitted": True}}})
        if st in (200, 204):
            print(f"✅ 已重新提交（复用原提交单 {sub_id}）")
            return True
        print(f"⚠️ 复用原提交单失败 HTTP {st}: {err_text(r)} → 走新建路线")

    # 路线二：新建提交单 + 挂版本 + 提交
    st, r = asc("/reviewSubmissions", "POST", {
        "data": {"type": "reviewSubmissions",
                 "relationships": {
                     "app": {"data": {"type": "apps", "id": APP_ID}},
                 },
                 "attributes": {"platform": "IOS"}}})
    if st not in (200, 201):
        print(f"❌ 新建提交单失败 HTTP {st}: {err_text(r)}")
        return False
    new_id = r["data"]["id"]
    print(f"  新提交单 id={new_id} 状态={r['data']['attributes'].get('state')}")

    st, r = asc("/reviewSubmissionItems", "POST", {
        "data": {"type": "reviewSubmissionItems",
                 "relationships": {
                     "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": new_id}},
                     "appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver_id}},
                 }}})
    if st not in (200, 201):
        print(f"❌ 挂版本失败 HTTP {st}: {err_text(r)}")
        return False
    print("  版本已挂进提交单")

    st, r = asc(f"/reviewSubmissions/{new_id}", "PATCH", {
        "data": {"type": "reviewSubmissions", "id": new_id,
                 "attributes": {"submitted": True}}})
    if st in (200, 204):
        print(f"✅ 已重新提交（新提交单 {new_id}）")
        return True
    print(f"❌ 提交失败 HTTP {st}: {err_text(r)}")
    return False


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", help="备注文本文件（UTF-8）")
    ap.add_argument("--resubmit", action="store_true", help="重新提交审核")
    args = ap.parse_args()

    print("=" * 66)
    ver_id, ver_state = get_version()
    detail_id, _ = get_review_detail(ver_id) if ver_id else (None, None)
    sub_id, sub_state = get_submissions()
    print("=" * 66)

    if args.write:
        if not detail_id:
            print("❌ 没有审核详情 id，无法写备注")
            sys.exit(1)
        txt = Path(args.write).read_text(encoding="utf-8")
        if not write_notes(detail_id, txt):
            sys.exit(1)
        if "<录屏链接待填>" in txt:
            print("⚠️ 备注里还留着占位符「<录屏链接待填>」——不要这样提交！")

    if args.resubmit:
        if not ver_id:
            print("❌ 没有版本 id，无法提交")
            sys.exit(1)
        if not resubmit(ver_id, sub_id):
            sys.exit(1)

    print("-" * 66)
    get_version()
    get_submissions()
