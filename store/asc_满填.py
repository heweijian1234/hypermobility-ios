# -*- coding: utf-8 -*-
"""H 0.1.0 元数据满填：副标题+关键词全语言填满100字符，新增简繁中locale（2026-11-07健哥令：能满则满不浪费）"""
import importlib.util, sys, json
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

spec = importlib.util.spec_from_file_location('m', r'E:\AI-Projects\个人成长\10-项目\SaaS项目\hypermobility-ios\store\asc_备注与重提.py')
m = importlib.util.module_from_spec(spec)
class B:
    def reconfigure(self, **k): pass
    def write(self, *a): pass
    def flush(self): pass
old = sys.stdout; sys.stdout = B()
try: spec.loader.exec_module(m)
finally: sys.stdout = old

VER = '14fbb754-86a3-4aa6-88ff-1f82fe7fe7fa'

# 每语：副标题(≤30字符) + 关键词(≤100字符)。原则：剔除实测废词(zebra撞度假村/bendy撞农场游戏)，
# 副标题不重复名字里已有的词(hypermobility在名字里=关键词字段不浪费重复)，塞满到100。
DATA = {
  'en-US': {
    'subtitle': 'Joint pain & subluxation log',   # 29字符
    'keywords': 'joint pain,subluxation,dislocation,eds,heds,tracker,journal,symptom,beighton,hypermobile,bendy,chronic pain,zebra app,flexible joints,daily log',  # 满100截
  },
  'ja': {
    'subtitle': '関節の痛みと亜脱臼を記録',  # 15字符
    'keywords': '関節,関節痛,過伸展,亜脱臼,脱臼,エーラス・ダンロス,EDS,記録,日記,痛み,関節の曲がりすぎ,体のゆるみ,症状記録,ビートン,慢性痛,関節トラブル,体の痛み',
  },
  'de-DE': {
    'subtitle': 'Gelenkschmerz & Subluxation',
    'keywords': 'Hypermobilität,Gelenk,Gelenkschmerz,Subluxation,Ausrenkung,EDS,hEDS,Tagebuch,Schmerz,Symptom,Beighton,überbeweglich,Gelenktagbuch,chronisch,locker',
  },
  'fr-FR': {
    'subtitle': 'Douleur articulaire & luxation',
    'keywords': 'hyperlaxité,articulation,douleur,subluxation,luxation,EDS,journal,symptôme,Beighton,souplesse,chronique,traqueur,carnet,membre,mobilité',
  },
  'es-ES': {
    'subtitle': 'Dolor articular y subluxación',
    'keywords': 'hipermovilidad,articulaciones,dolor,subluxación,dislocación,EDS,diario,síntoma,Beighton,flexible,laxitud,crónico,registro,dolor articular,laxitud articular',
  },
}

# 简繁中（新locale要POST建）
ZH = {
  'zh-Hans': {
    'subtitle': '关节过度活动与疼痛记录',
    'keywords': '关节,关节痛,过度活动,关节松弛,半脱位,脱臼,疼痛,记录,日记,症状,埃勒斯-当洛,EDS,慢性疼痛,关节弹响,全身松弛,易疲劳,体检,康复,理疗,伸展',
    'desc': '为关节过度活动（HSD/EDS）人群设计的简洁记录工具。几秒记下：哪个关节、疼痛程度、持续多久、做了什么缓解。支持照片对比、Beighton九点自评、按关节自动分组、给医生看的PDF报告。无需账号、无云端、无广告——数据永不离开手机。本应用不是医疗器械。',
  },
  'zh-Hant': {
    'subtitle': '關節過度活動與疼痛記錄',
    'keywords': '關節,關節痛,過度活動,關節鬆弛,半脫位,脫臼,疼痛,記錄,日記,症狀,埃勒斯-當洛,EDS,慢性疼痛,關節彈響,全身鬆弛,易疲勞,體檢,復健,物理治療,伸展',
    'desc': '為關節過度活動（HSD/EDS）族群設計的簡潔記錄工具。幾秒記下：哪個關節、疼痛程度、持續多久、做了什麼緩解。支援照片對比、Beighton九點自評、按關節自動分組、給醫師看的PDF報告。無需帳號、無雲端、無廣告——資料永不離開手機。本應用不是醫療器材。',
  },
}

def clip(s, n, tag):
    if len(s) > n:
        print(f'  ⚠️ {tag} 超{n}({len(s)})截断: {s}')
        s = s[:n]
    return s

print('=== ① 现有5语：副标题+关键词满填 PATCH ===')
st, r = m.asc(f'/appStoreVersions/{VER}/appStoreVersionLocalizations?limit=10')
locs = {d['attributes']['locale']: d['id'] for d in r.get('data', [])}
for locale, info in DATA.items():
    sub = clip(info['subtitle'], 30, f'{locale}副标题')
    kw = clip(info['keywords'], 100, f'{locale}关键词')
    st, r = m.asc(f'/appStoreVersionLocalizations/{locs[locale]}', 'PATCH', {
        'data': {'type': 'appStoreVersionLocalizations', 'id': locs[locale],
                 'attributes': {'subtitle': sub, 'keywords': kw}}})
    print(f'  {locale}: HTTP {st} | sub={len(sub)}/30 kw={len(kw)}/100')

print('=== ② 新增 zh-Hans / zh-Hant ===')
for locale, info in ZH.items():
    # 先建locale
    st, r = m.asc(f'/appStoreVersions/{VER}/appStoreVersionLocalizations', 'POST', {
        'data': {'type': 'appStoreVersionLocalizations',
                 'relationships': {'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': VER}}},
                 'attributes': {'locale': locale}}})
    if st in (200, 201):
        lid = r['data']['id']
        print(f'  {locale}: locale已建 id={lid[:12]}')
    elif st == 409:
        # 已存在，找出id
        st2, r2 = m.asc(f'/appStoreVersions/{VER}/appStoreVersionLocalizations?limit=10')
        lid = next((d['id'] for d in r2.get('data', []) if d['attributes'].get('locale') == locale), None)
        print(f'  {locale}: 已存在 id={lid[:12] if lid else "?"}')
    else:
        print(f'  {locale}: 建locale失败 HTTP {st} {json.dumps(r)[:200]}')
        continue
    sub = clip(info['subtitle'], 30, f'{locale}副标题')
    kw = clip(info['keywords'], 100, f'{locale}关键词')
    st3, r3 = m.asc(f'/appStoreVersionLocalizations/{lid}', 'PATCH', {
        'data': {'type': 'appStoreVersionLocalizations', 'id': lid,
                 'attributes': {'subtitle': sub, 'keywords': kw,
                                'description': info['desc'], 'supportUrl': 'https://postwriter.cn'}}})
    print(f'  {locale}: 填料 HTTP {st3} | sub={len(sub)}/30 kw={len(kw)}/100')

print('=== ③ 复核 ===')
st, r = m.asc(f'/appStoreVersions/{VER}/appStoreVersionLocalizations?limit=10')
for d in r.get('data', []):
    a = d['attributes']
    kw = a.get('keywords') or ''
    print(f"  {a.get('locale')}: sub={'✓'+str(len(a.get('subtitle') or '')) if a.get('subtitle') else '空'} kw={len(kw)}/100")
