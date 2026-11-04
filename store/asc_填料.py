# -*- coding: utf-8 -*-
"""HyperLog ASC 上架填料：创建 0.1.0 版本 + 5 语本地化 + 3 张截图上传"""
import time, json, base64, sys, hashlib, urllib.request

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

KEY_ID = "L3UHT69Y77"
ISSUER_ID = "98812827-46d0-4c8f-9b91-35d4f783e6df"
P8_PATH = r"E:\AI-Projects\个人成长\50-Skills\密钥\苹果\AuthKey_L3UHT69Y77.p8"
APP_ID = "6830034297"   # Hypermobility Log
VER = "0.1.0"
STORE = r"E:\AI-Projects\个人成长\10-项目\SaaS项目\hypermobility-ios\store"

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

def asc(url, data=None, method=None, headers=None):
    body = json.dumps(data).encode() if data else None
    all_headers = {"Authorization": f"Bearer {jwt}", "Content-Type": "application/json"}
    if headers: all_headers.update(headers)
    req = urllib.request.Request(url, data=body, headers=all_headers, method=method or ("POST" if data else "GET"))
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return resp.status, json.loads(resp.read() or b"{}")
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read() or b"{}")
        except Exception as ex:
            if attempt == 3: return -1, {"err": str(ex)}
            time.sleep(3)

EN_DESC = """A simple journal for hypermobile joints.

If your joints bend further than most — hypermobility, HSD, or EDS — HyperLog helps you show what's actually happening:

• Log each episode in seconds: which joint, how bad, how long the pain lasted, what you did about it, and what you were doing before
• Attach photos — see swelling and changes over time, side by side
• Beighton self-assessment built in (9-point scale), scored and saved with each entry
• Entries group themselves by joint, so patterns jump out
• Export a PDF report for your physio or rheumatologist: summary statistics, per-joint charts, daily trend, photos, and the full list
• Quick log: one tap during a flare, fill in the details later when it hurts less

PRIVATE BY DESIGN
No account. No cloud. No ads. No analytics. Your entries and photos never leave your phone. Share only what you choose.

NOT A MEDICAL DEVICE
HyperLog records what you experience. It does not diagnose any condition. For medical concerns, consult a healthcare professional."""

LOCALES = {
    "en-US": {"subtitle": "Hypermobility joint journal",
              "keywords": "hypermobility,joint pain,eds,subluxation,dislocation,journal,zebra,bendy",
              "description": EN_DESC},
    "ja": {"subtitle": "関節の過伸展を記録",
           "keywords": "関節,過伸展,エーラス・ダンロス,亜脱臼,記録",
           "description": "関節がよく曲がる人（過伸展・HSD・EDS）のためのシンプルな記録アプリ。どの関節が、どれくらい、いつ、何をしていたときに起きたかを数秒で記録。写真を添付、経過を並べて比較。Beightonセルフ評価（9点法）内蔵。関節ごとに自動グループ化。理学療法士や医師のためのPDFレポート出力。アカウント不要・クラウドなし・広告なし。あなたのデータは端末から出ません。医療機器ではありません。"},
    "de": {"subtitle": "Gelenk-Hypermobilität Log",
           "keywords": "Hypermobilität,Gelenk,Subluxation,EDS,Tagebuch",
           "description": "Ein einfaches Tagebuch für hypermobile Gelenke. Protokolliere in Sekunden: welches Gelenk, wie stark, wie lange die Schmerzen dauerten, was du dagegen getan hast und was du vorher gemacht hast. Fotos anhängen und Veränderungen im Vergleich sehen. Beighton-Selbsteinschätzung (9-Punkte) integriert. Einträge werden automatisch pro Gelenk gruppiert. PDF-Bericht für Physiotherapeut:in oder Rheumatolog:in exportieren. Kein Konto, keine Cloud, keine Werbung — deine Daten verlassen dein Gerät nie. Kein Medizinprodukt."},
    "fr": {"subtitle": "Journal articulations hypermobiles",
           "keywords": "hyperlaxité,articulation,subluxation,EDS,journal",
           "description": "Un journal simple pour les articulations hypermobiles. Notez en quelques secondes : quelle articulation, quelle intensité, combien de temps la douleur a duré, ce que vous avez fait, et ce que vous faisiez avant. Ajoutez des photos et comparez l'évolution. Auto-évaluation de Beighton (9 points) intégrée. Regroupement automatique par articulation. Exportez un rapport PDF pour votre kiné ou rhumatologue. Sans compte, sans cloud, sans pub — vos données ne quittent jamais votre téléphone. Pas un dispositif médical."},
    "es": {"subtitle": "Diario de articulaciones",
           "keywords": "hipermovilidad,articulaciones,subluxación,EDS,diario",
           "description": "Un diario simple para articulaciones hipermóviles. Registra en segundos: qué articulación, cuánta intensidad, cuánto duró el dolor, qué hiciste y qué estabas haciendo antes. Añade fotos y compara la evolución. Autoevaluación de Beighton (9 puntos) incluida. Agrupación automática por articulación. Exporta un informe PDF para tu fisioterapeuta o reumatólogo. Sin cuenta, sin nube, sin anuncios — tus datos nunca salen de tu teléfono. No es un dispositivo médico."},
}

# 1. 版本：新 App 自带 PREPARE 状态版本——用它，versionString 改成 0.1.0
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=5")
vers = r.get("data", [])
if not vers:
    print("[1/4] 无版本记录（异常）"); sys.exit(1)
ver_id = vers[0]["id"]
cur = vers[0]["attributes"].get("versionString")
print(f"[1/4] 使用现有版本 id={ver_id} 当前={cur} 状态={vers[0]['attributes'].get('appStoreState')}")
if cur != VER:
    st, r = asc(f"https://api.appstoreconnect.apple.com/v1/appStoreVersions/{ver_id}",
                {"data": {"type": "appStoreVersions", "id": ver_id, "attributes": {"versionString": VER}}}, method="PATCH")
    print(f"      改版本号→{VER}: {'OK' if st in (200, 201) else f'{st} ' + json.dumps(r)[:200]}")

# 2. 版本本地化（5 语）——🔴前置：先在 App 信息层把语言注册了（de/fr/es 否则 409 not listed）
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/appInfos?filter[app]={APP_ID}")
app_info_id = r["data"][0]["id"] if r.get("data") else None
if app_info_id:
    st, r = asc(f"https://api.appstoreconnect.apple.com/v1/appInfos/{app_info_id}/appInfoLocalizations")
    info_existing = {l["attributes"]["locale"]: l["id"] for l in r.get("data", [])}
    for locale, info in LOCALES.items():
        if locale in info_existing:
            ipatch = {k: v for k, v in {
                "name": "Hypermobility Log",
                "subtitle": info["subtitle"],
                "privacyPolicyUrl": "https://postwriter.cn/seo/hyperlog-privacy.html",
            }.items()}
            st, rr = asc(f"https://api.appstoreconnect.apple.com/v1/appInfoLocalizations/{info_existing[locale]}",
                         {"data": {"type": "appInfoLocalizations", "id": info_existing[locale], "attributes": ipatch}}, method="PATCH")
        else:
            ipayload = {"type": "appInfoLocalizations", "attributes": {
                "locale": locale,
                "name": "Hypermobility Log",
                "subtitle": info["subtitle"],
                "privacyPolicyUrl": "https://postwriter.cn/seo/hyperlog-privacy.html",
            }, "relationships": {"appInfo": {"data": {"type": "appInfos", "id": app_info_id}}}}
            st, rr = asc("https://api.appstoreconnect.apple.com/v1/appInfoLocalizations", {"data": ipayload})
        print(f"[2] App信息 {locale}: {'OK' if st in (200, 201) else f'{st} ' + json.dumps(rr)[:250]}")

st, r = asc(f"https://api.appstoreconnect.apple.com/v1/appStoreVersions/{ver_id}/appStoreVersionLocalizations")
existing = {l["attributes"]["locale"]: l["id"] for l in r.get("data", [])}
for locale, info in LOCALES.items():
    payload = {"type": "appStoreVersionLocalizations", "attributes": {
        "locale": locale,
        "keywords": info["keywords"],
        "description": info["description"],
        "supportUrl": "https://postwriter.cn",
    }}
    if locale in existing:
        patch_attrs = {k: v for k, v in payload["attributes"].items() if k != "locale"}
        st, rr = asc(f"https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations/{existing[locale]}",
                     {"data": {"type": "appStoreVersionLocalizations", "id": existing[locale], "attributes": patch_attrs}}, method="PATCH")
    else:
        payload["relationships"] = {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver_id}}}
        st, rr = asc("https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations", {"data": payload})
    if st in (200, 201):
        print(f"[2/4] 版本文案 {locale}: OK")
    else:
        errs = rr.get("errors", [])
        detail = errs[0].get("detail", "") if errs else ""
        print(f"[2/4] 版本文案 {locale}: {st} {detail} | raw={json.dumps(rr)[:400]}")

# 3. 截图上传（en-US 的 IPHONE_67 set）
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations?filter[appStoreVersion]={ver_id}&filter[locale]=en-US")
en_loc = r["data"][0]["id"]
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/appScreenshotSets?filter[appStoreVersionLocalization]={en_loc}&filter[screenshotDisplayType]=APP_IPHONE_67")
if not r.get("data"):
    print("[3/4] 无 IPHONE_67 set（需网页先建或 displayType 不符）", json.dumps(r)[:200]); sys.exit(1)
set_id = r["data"][0]["id"]
print(f"[3/4] 截图集 id={set_id}")

import os
for i in range(1, 4):
    path = os.path.join(STORE, f"shot{i}.png")
    data = open(path, "rb").read()
    md5 = base64.b64encode(hashlib.md5(data).digest()).decode()
    st, r = asc("https://api.appstoreconnect.apple.com/v1/appScreenshots", {
        "data": {"type": "appScreenshots",
                 "attributes": {"fileName": f"shot{i}.png", "fileSize": len(data)},
                 "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}
    })
    if st not in (200, 201):
        print(f"  shot{i} reserve FAIL {st} {json.dumps(r)[:200]}"); continue
    attrs = r["data"]["attributes"]
    upload = attrs["uploadOperations"][0]
    url = upload["url"]
    method = upload["method"]
    headers = {h["name"]: h["value"] for h in upload.get("requestHeaders", [])}
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            up_ok = resp.status in (200, 201)
    except Exception as ex:
        up_ok = False; print(f"  shot{i} upload err {ex}")
    if up_ok:
        st2, r2 = asc(f"https://api.appstoreconnect.apple.com/v1/appScreenshots/{r['data']['id']}",
                      {"data": {"type": "appScreenshots", "id": r["data"]["id"],
                                "attributes": {"uploaded": True, "sourceFileChecksum": md5}}}, method="PATCH")
        print(f"  shot{i}: {'OK 上传完成' if st2 in (200, 201) else f'confirm {st2} ' + json.dumps(r2)[:150]}")
    time.sleep(2)

print("[4/4] 完成——年龄分级/隐私问答/审核信息=网页（健哥提审前 3 分钟）")
