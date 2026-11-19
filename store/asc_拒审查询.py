# -*- coding: utf-8 -*-
"""HyperLog 拒审排查：版本状态/审核提交单/构建/审核详情——一次拉全，原始 JSON 关键字段全打"""
import base64
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

KEY_ID = "L3UHT69Y77"
ISSUER_ID = "98812827-46d0-4c8f-9b91-35d4f783e6df"
P8_PATH = r"E:\AI-Projects\个人成长\50-Skills\密钥\苹果\AuthKey_L3UHT69Y77.p8"
APP_ID = "6830034297"

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.serialization import load_pem_private_key


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


key = load_pem_private_key(open(P8_PATH, "rb").read(), password=None)
h = b64url(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}).encode())
p = b64url(json.dumps({"iss": ISSUER_ID, "iat": int(time.time()),
                       "exp": int(time.time()) + 1200, "aud": "appstoreconnect-v1"}).encode())
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


jwt = f"{h}.{p}.{b64url(raw(sig))}"


def asc(url):
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {jwt}"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return resp.status, json.loads(resp.read())
        except urllib.error.HTTPError as e:
            try:
                return e.code, json.loads(e.read())
            except Exception:
                return e.code, {"_raw": "非 JSON 错误体"}
        except Exception as e:
            if attempt == 2:
                return -1, {"_err": str(e)}
            time.sleep(2)


print("=" * 70)
print("① App Store 版本状态（含 build / 提交关联）")
print("=" * 70)
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/appStoreVersions"
            f"?filter[platform]=IOS&include=builds,appStoreVersionSubmission")
print(f"HTTP {st}")
ver_id = None
for v in r.get("data", []):
    a = v["attributes"]
    ver_id = v["id"]
    print(f"  版本 {a.get('versionString')} | id={v['id']}")
    print(f"    appStoreState = {a.get('appStoreState')}")
    print(f"    releaseType   = {a.get('releaseType')}")
    print(f"    最早发布日期  = {a.get('earliestReleaseDate')}")
    print(f"    下载/版权    = downloadable={a.get('downloadable')}")
    rel = v.get("relationships", {})
    print(f"    已选 build   = {bool(rel.get('builds', {}).get('data'))}")
    print(f"    提交单关联   = {rel.get('appStoreVersionSubmission', {}).get('data')}")
if r.get("errors"):
    print("  错误:", json.dumps(r["errors"], ensure_ascii=False)[:500])
for inc in r.get("included", []):
    if inc["type"] == "builds":
        a = inc["attributes"]
        print(f"  [build] 版本号={a.get('version')} 处理状态={a.get('processingState')} "
              f"上传时间={str(a.get('uploadedDate'))[:19]} 过期={a.get('expired')} "
              f"可用={a.get('usesNonExemptEncryption')}")

print()
print("=" * 70)
print("② 审核提交单 reviewSubmissions（拒审状态在这里）")
print("=" * 70)
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/reviewSubmissions"
            f"?filter[app]={APP_ID}&include=items&limit=5")
print(f"HTTP {st}")
for d in r.get("data", []):
    a = d["attributes"]
    print(f"  提交单 id={d['id']} | 状态={a.get('state')} | 平台={a.get('platform')} | "
          f"提交={str(a.get('submittedDate'))[:19]}")
for inc in r.get("included", []):
    a = inc.get("attributes", {})
    print(f"    [item] {inc['type']} id={inc['id']} 状态={a.get('state')}")
if r.get("errors"):
    print("  错误:", json.dumps(r["errors"], ensure_ascii=False)[:800])

print()
print("=" * 70)
print("③ 审核详情 appStoreReviewDetail（联系信息/备注）")
print("=" * 70)
if ver_id:
    st, r = asc(f"https://api.appstoreconnect.apple.com/v1/appStoreVersions/{ver_id}/appStoreReviewDetail")
    print(f"HTTP {st}")
    for d in r.get("data", []):
        print("  ", json.dumps(d.get("attributes", {}), ensure_ascii=False)[:600])
    if r.get("errors"):
        print("  错误:", json.dumps(r["errors"], ensure_ascii=False)[:400])

print()
print("=" * 70)
print("④ App 信息层（分类/年龄分级/版权）——拒审常见缺口")
print("=" * 70)
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}?include=appInfos")
print(f"HTTP {st}")
for inc in r.get("included", []):
    if inc["type"] == "appInfos":
        a = inc["attributes"]
        print(f"  状态={a.get('appStoreState')} 主分类={a.get('primaryCategory')} "
              f"次分类={a.get('secondaryCategory')}")
        print(f"  年龄分级={json.dumps(a.get('ageRatingDeclaration', {}), ensure_ascii=False)[:300]}")
        print(f"  版权={a.get('privacyPolicyUrl') and '隐私URL已填'} -> {a.get('privacyPolicyUrl')}")

print()
print("=" * 70)
print("⑤ 本地化文案（版本层）——4.2/元数据类拒审要核对")
print("=" * 70)
if ver_id:
    st, r = asc(f"https://api.appstoreconnect.apple.com/v1/appStoreVersions/{ver_id}/appStoreVersionLocalizations")
    print(f"HTTP {st}")
    for d in r.get("data", []):
        a = d["attributes"]
        desc = (a.get("description") or "")
        print(f"  [{a.get('locale')}] 关键词='{a.get('keywords')}' 营销='{a.get('marketingUrl')}' "
              f"支持='{a.get('supportUrl')}' 描述长度={len(desc)}")
        print(f"      描述首行: {desc.splitlines()[0] if desc else '(空)'}")
