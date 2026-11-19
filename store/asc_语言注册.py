# -*- coding: utf-8 -*-
"""ASC 语言注册（App 信息层 5 语——de/fr/es 版本本地化 409 not listed 的前置）"""
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

def asc(url, data=None, method=None):
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers={"Authorization": f"Bearer {jwt}", "Content-Type": "application/json"}, method=method or ("POST" if data else "GET"))
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return resp.status, json.loads(resp.read() or b"{}")
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read() or b"{}")
        except Exception as ex:
            if attempt == 3: return -1, {"err": str(ex)}
            time.sleep(3)

st, r = asc(f"https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}?include=appInfos")
print("apps include:", st)
app_info_id = None
for inc in r.get("included", []):
    if inc["type"] == "appInfos":
        app_info_id = inc["id"]
        break
if app_info_id:
    st, r = asc(f"https://api.appstoreconnect.apple.com/v1/appInfos/{app_info_id}/appInfoLocalizations")
    print("localizations:", st)
    existing = {l["attributes"]["locale"]: l["id"] for l in r.get("data", [])}
    print("existing:", list(existing.keys()))
    SUBTITLES = {"en-US": "Hypermobility joint journal", "ja": "関節の過伸展を記録",
                 "de-DE": "Gelenk-Hypermobilität Log", "fr-FR": "Journal articulations souples",
                 "es-ES": "Diario de articulaciones"}
    for locale, sub in SUBTITLES.items():
        attrs = {"name": "Hypermobility Log", "subtitle": sub,
                 "privacyPolicyUrl": "https://postwriter.cn/seo/hyperlog-privacy.html"}
        if locale in existing:
            st, rr = asc(f"https://api.appstoreconnect.apple.com/v1/appInfoLocalizations/{existing[locale]}",
                         {"data": {"type": "appInfoLocalizations", "id": existing[locale], "attributes": attrs}}, method="PATCH")
        else:
            st, rr = asc("https://api.appstoreconnect.apple.com/v1/appInfoLocalizations", {"data": {
                "type": "appInfoLocalizations", "attributes": {"locale": locale, **attrs},
                "relationships": {"appInfo": {"data": {"type": "appInfos", "id": app_info_id}}}}})
        errs = rr.get("errors", [])
        detail = errs[0].get("detail", "") if errs else ""
        print(f"  {locale}: {'OK' if st in (200, 201) else f'{st} {detail}'}")


