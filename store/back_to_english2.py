# -*- coding: utf-8 -*-
"""英文回改第二轮：清残留（用户可见字符串）"""
import os, sys
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
BASE = r"E:\AI-Projects\个人成长\10-项目\SaaS项目\hypermobility-ios"

MAP2 = {
    # EntryEditor 残留
    '"程度"': '"Severity"', '"疼痛持续时间"': '"Pain duration"', '"处置"': '"Treatment"',
    'Text("轻微").tag(0)': 'Text("Mild").tag(0)',
    'Text("中等").tag(1)': 'Text("Moderate").tag(1)',
    'Text("明显").tag(2)': 'Text("Significant").tag(2)',
    # DoctorReport 残留
    '\\(ranged.count) 次': '\\(ranged.count)',
    '\\(EntryStore.grouped(ranged).count) 个': '\\(EntryStore.grouped(ranged).count)',
    '\\(top.label)（\\(top.count) 次）': '\\(top.label) — \\(top.count)',
    '\\(severe) 次': '\\(severe)',
    '\\(hospital) 次': '\\(hospital)',
    'Text("【\\(g.label)】").foregroundColor(.secondary)': 'Text(g.label).foregroundColor(.secondary)',
    'Text("\\(g.count) 次").foregroundColor(.purple)': 'Text("\\(g.count)").foregroundColor(.purple)',
    '"  episodes"': '" episodes"',
    '\\(ranged.filter { $0.severity >= 3 }.count) 次': '\\(ranged.filter { $0.severity >= 3 }.count)',
    '\\(ranged.filter { $0.treatment == "hospital" }.count) 次': '\\(ranged.filter { $0.treatment == "hospital" }.count)',
    '严重 \\(': 'Severe \\(',
    ' · Hospital:  \\(': ' · Hospital: \\(',
    '"【\\(g.label)】\\(g.count) 次"': '"\\(g.label): \\(g.count)"',
    '"疼\\(e.painDurationLabel)"': '"pain: \\(e.painDurationLabel)"',
    '"HyperLog报告.pdf"': '"HyperLog-Report.pdf"',
    'Label("Other方式分享（Gmail/Outlook/信息/存储）"': 'Label("Share other ways (Gmail/Outlook/Messages/Files)"',
    # PhotoCompare 残留
    'Text("\\(files.count)  photos")': 'Text("\\(files.count) photos")',
    # 概览 PDF 小标题（图2 系列）
    '"按日统计（范围天数内每天的发作数）"': '"daily counts"',
}

for rel in ["HyperLog/EntryEditor.swift", "HyperLog/DoctorReportView.swift", "HyperLog/PhotoCompareView.swift", "HyperLog/ContentView.swift"]:
    path = os.path.join(BASE, rel)
    txt = open(path, encoding="utf-8").read()
    orig = txt
    for k, v in MAP2.items():
        txt = txt.replace(k, v)
    if txt != orig:
        open(path, "w", encoding="utf-8").write(txt)
        print("patched", rel)

# 最终验证：列出所有还含中文的用户可见字符串行（Text("/Label("/Section("/Button("/Picker( 里带 CJK）
import re
cjk = re.compile(r'[一-鿿]')
for root, _, files in os.walk(os.path.join(BASE, "HyperLog")):
    for f in files:
        if not f.endswith(".swift"):
            continue
        p = os.path.join(root, f)
        for i, line in enumerate(open(p, encoding="utf-8"), 1):
            if cjk.search(line) and re.search(r'Text\("|Label\("|Section\("|Button\("|Picker\("|Text\(\\|navigationTitle|TextField\("', line):
                print(f"残留 {f}:{i}: {line.strip()[:100]}")
print("DONE2")
