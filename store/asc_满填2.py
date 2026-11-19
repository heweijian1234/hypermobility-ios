# -*- coding: utf-8 -*-
"""H 0.1.0 满填v2（健哥令：能满则满不浪费）
两层结构：
  关键词(100字符) → appStoreVersionLocalizations (version层)
  副标题(30字符) + 名字 → appInfoLocalizations (appInfo层)
新增 zh-Hans/zh-Hant 双层都要建（appInfo层POST建locale，version层跟挂）
"""
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
INFO = 'e2943a90-f375-45db-8e41-eb768c005b49'

# 原则：副标题塞搜索词（名字已有的hypermobility不重复占）；关键词满100；废词(zebra/bendy)剔除换实测有效词
SUBTITLE = {  # appInfo层
  'en-US': 'Joint pain & subluxation log',
  'ja':    '関節痛・亜脱臼を記録するアプリ',
  'de-DE': 'Gelenkschmerz & Subluxation Log',
  'fr-FR': 'Douleur et subluxation tracker',
  'es-ES': 'Dolor articular y subluxación',
  'zh-Hans': '关节松弛疼痛半脱位记录',
  'zh-Hant': '關節鬆弛疼痛半脫位記錄',
}
KEYWORDS = {  # version层，目标满100
  'en-US': 'joint pain,subluxation,dislocation,heds,eds,tracker,symptom,beighton,hypermobile,chronic,journal,flexible,hypermobility spectrum,shoulder,knee,finger,pain diary,health log',  # 逐词精选后组
  'ja':    '関節,関節痛,過伸展,亜脱臼,脱臼,エーラス・ダンロス,EDS,記録,日記,痛み,症状,慢性痛,関節が曲がりすぎ,体が柔らかい,関節のゆるみ,ビートンスコア,肩,膝,指,痛み日記',
  'de-DE': 'Gelenkschmerz,Subluxation,Ausrenkung,Hypermobilität,Gelenk,hEDS,EDS,Tagebuch,Schmerz,Symptom,Beighton,überbeweglich,chronisch,Gelenktagbuch,Schultter,Knie,Finger,Schmerztagebuch',
  'fr-FR': 'douleur,subluxation,luxation,hyperlaxité,articulation,EDS,hEDS,journal,symptôme,Beighton,souplesse,chronique,épaule,genou,doigt,carnet,douleur articulaire,hypermobile',
  'es-ES': 'dolor,subluxación,dislocación,hipermovilidad,articulaciones,EDS,diario,síntoma,Beighton,flexible,laxitud,crónico,hombro,rodilla,dedo,registro,dolor articular,hipermóvil',
  'zh-Hans': '关节痛,关节松弛,半脱位,脱臼,过度活动,关节弹响,全身松弛,慢性疼痛,疼痛记录,症状日记,埃勒斯当洛,关节过度活动,EDS,易疲劳,康复理疗,手指关节,膝盖,肩膀,体质记录,健康管理',
  'zh-Hant': '關節痛,關節鬆弛,半脫位,脫臼,過度活動,關節彈響,全身鬆弛,慢性疼痛,疼痛記錄,症狀日記,埃勒斯當洛,關節過度活動,EDS,易疲勞,復健治療,手指關節,膝蓋,肩膀,體質記錄,健康管理',
}
ZH_DESC = {
  'zh-Hans': '为关节过度活动（HSD/EDS）人群设计的简洁记录工具。几秒记下：哪个关节、疼痛程度、持续多久、做了什么缓解。支持照片对比、Beighton九点自评、按关节自动分组、给医生看的PDF报告。无需账号、无云端、无广告——数据永不离开手机。本应用不是医疗器械。',
  'zh-Hant': '為關節過度活動（HSD/EDS）族群設計的簡潔記錄工具。幾秒記下：哪個關節、疼痛程度、持續多久、做了什麼緩解。支援照片對比、Beighton九點自評、按關節自動分組、給醫師看的PDF報告。無需帳號、無雲端、無廣告——資料永不離開手機。本應用不是醫療器材。',
}

def clip(s, n, tag):
    if len(s) > n:
        # 从尾部截到不破坏词（截到最后一个逗号）
        cut = s[:n]
        if ',' in cut: cut = cut[:cut.rfind(',')]
        print(f'  ⚠️ {tag} {len(s)}→{len(cut)}（保词截断）')
        return cut
    return s

print('=== ① 关键词满填（version层 7语）===')
st, r = m.asc(f'/appStoreVersions/{VER}/appStoreVersionLocalizations?limit=10')
vlocs = {d['attributes']['locale']: d['id'] for d in r.get('data', [])}
print('  现有version locale:', list(vlocs))

# zh locale在version层不存在——locale列表由appInfo层决定，先建appInfo层
print('=== ② appInfo层建 zh-Hans/zh-Hant + 副标题全语满填 ===')
st2, r2 = m.asc(f'/appInfos/{INFO}/appInfoLocalizations?limit=15')
ilocs = {d['attributes']['locale']: d['id'] for d in r2.get('data', [])}
print('  现有appInfo locale:', list(ilocs))

for locale, sub in SUBTITLE.items():
    # 不存在则建（zh两语）
    if locale not in ilocs:
        st3, r3 = m.asc(f'/appInfos/{INFO}/appInfoLocalizations', 'POST', {
            'data': {'type': 'appInfoLocalizations',
                     'relationships': {'appInfo': {'data': {'type': 'appInfos', 'id': INFO}}},
                     'attributes': {'locale': locale, 'name': 'Hypermobility Log 關節記錄' if locale=='zh-Hant' else 'Hypermobility Log 关节记录'}}})
        if st3 in (200, 201):
            ilocs[locale] = r3['data']['id']
            print(f'  {locale}: appInfo locale已建（名字带中文）')
        else:
            print(f'  {locale}: 建失败 {st3} {json.dumps(r3)[:150]}')
            continue
    # 副标题PATCH
    s = clip(sub, 30, f'{locale}副标题')
    st4, r4 = m.asc(f'/appInfoLocalizations/{ilocs[locale]}', 'PATCH', {
        'data': {'type': 'appInfoLocalizations', 'id': ilocs[locale],
                 'attributes': {'subtitle': s}}})
    print(f'  {locale}: 副标题 HTTP {st4} ({len(s)}/30) {'' if st4 in (200,201,204) else json.dumps(r4)[:120]}')

print('=== ③ 关键词PATCH（version层）===')
# zh的version locale：appInfo层建好后，version层可能会自动出现？探一遍再建
st5, r5 = m.asc(f'/appStoreVersions/{VER}/appStoreVersionLocalizations?limit=15')
vlocs = {d['attributes']['locale']: d['id'] for d in r5.get('data', [])}
for locale, kw in KEYWORDS.items():
    if locale not in vlocs:
        st6, r6 = m.asc(f'/appStoreVersions/{VER}/appStoreVersionLocalizations', 'POST', {
            'data': {'type': 'appStoreVersionLocalizations',
                     'relationships': {'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': VER}}},
                     'attributes': {'locale': locale}}})
        if st6 in (200, 201):
            vlocs[locale] = r6['data']['id']
            print(f'  {locale}: version locale已建')
        else:
            print(f'  {locale}: version建失败 {st6}')
            continue
    k = clip(kw, 100, f'{locale}关键词')
    attrs = {'keywords': k}
    if locale in ZH_DESC:
        attrs['description'] = ZH_DESC[locale]
        attrs['supportUrl'] = 'https://postwriter.cn'
    st7, r7 = m.asc(f'/appStoreVersionLocalizations/{vlocs[locale]}', 'PATCH', {
        'data': {'type': 'appStoreVersionLocalizations', 'id': vlocs[locale], 'attributes': attrs}})
    ok = st7 in (200, 201, 204)
    print(f'  {locale}: 关键词 HTTP {st7} ({len(k)}/100){'' if ok else ' ' + json.dumps(r7)[:120]}')

print('=== ④ 总复核 ===')
st8, r8 = m.asc(f'/appStoreVersions/{VER}/appStoreVersionLocalizations?limit=15')
for d in r8.get('data', []):
    a = d['attributes']
    print(f"  [kw] {a.get('locale')}: {len(a.get('keywords') or '')}/100")
st9, r9 = m.asc(f'/appInfos/{INFO}/appInfoLocalizations?limit=15')
for d in r9.get('data', []):
    a = d['attributes']
    print(f"  [sub] {a.get('locale')}: {len(a.get('subtitle') or '')}/30 name={a.get('name')}")
