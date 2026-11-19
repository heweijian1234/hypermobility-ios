# -*- coding: utf-8 -*-
"""HyperLog 提审就绪度检查：版本状态/build已选/年龄分级/分类/隐私——缺啥报啥"""
import time, json, base64, sys, urllib.request
sys.stdout.reconfigure(encoding="utf-8", errors="replace")

KEY_ID = "L3UHT69Y77"
ISSUER_ID = "98812827-46d0-4c8f-9b91-35d4f783e6df"
P8_PATH = r"E:\AI-Projects\个人成长\50-Skills\密钥\苹果\AuthKey_L3UHT69Y77.p8"
APP_ID = "6830034297"

def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

from cryptography.hazmat.primitives.serialization import load_pem_private_key
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes

key = load_pem_private_key(open(P8_PATH, "rb").read(), password=None)
h = b64url(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}).encode())
p = b64url(json.dumps({"iss": ISSUER_ID, "iat": int(time.time()), "exp": int(time.time()) + 1200, "aud": "appstoreconnect-v1"}).encode())
sig = key.sign(f"{h}.{p}".encode(), ec.ECDSA(hashes.SHA256()))
def raw(s):
    i = 2
    if s[1] & 0x80: i += s[1] & 0x7f
    def ri():
        nonlocal i
        i += 1; ln = s[i]; i += 1
        if ln & 0x80:
            n = ln & 0x7f; ln = 0
            for _ in range(n): ln = (ln << 8) | s[i]; i += 1
        v = int.from_bytes(s[i:i+ln], "big"); i += ln; return v.to_bytes(32, "big")
    return ri() + ri()
jwt = f"{h}.{p}.{b64url(raw(sig))}"

def asc(url):
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {jwt}"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return resp.status, json.loads(resp.read())
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read())
        except Exception:
            if attempt == 3: return -1, {}
            time.sleep(3)

# 1. 版本状态+build 关联
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&include=builds,appStoreVersionSubmission")
for v in r.get("data", []):
    a = v["attributes"]
    print(f"[版本] {a.get('versionString')} 状态={a.get('appStoreState')}")
    rel = v.get("relationships", {})
    has_build = bool(rel.get("builds", {}).get("data"))
    print(f"  已选build: {'是' if has_build else '❌否（版本页→添加构建版本）'}")
    has_sub = bool(rel.get("appStoreVersionSubmission", {}).get("data"))
    print(f"  已提交审核: {'是' if has_sub else '否'}")
    for inc in r.get("included", []):
        if inc["type"] == "builds":
            print(f"  build {inc['attributes'].get('version')} processing={inc['attributes'].get('processingState')}")

# 2. appInfo：年龄分级+分类
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}?include=appInfos")
app_info_id = None
for inc in r.get("included", []):
    if inc["type"] == "appInfos":
        app_info_id = inc["id"]
        a = inc["attributes"]
        print(f"\n[App信息] 年龄分级={a.get('ageRatingDeclaration', {}).get('ageRating', '?')}  主分类={a.get('primaryCategory', '?')} 次分类={a.get('secondaryCategory', '无')}")

# 3. 隐私
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/appPrivacyInformations")
print(f"\n[隐私] API: {st}（个人账号可能不可读——网页 App 隐私页确认'否'即可）")
