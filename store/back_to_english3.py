# -*- coding: utf-8 -*-
"""英文回改第三轮：最后 8 处残留"""
import os, sys
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
BASE = r"E:\AI-Projects\个人成长\10-项目\SaaS项目\hypermobility-ios"

FIX = {
    "HyperLog/AboutView.swift": [
        ('Text("给关节过度活动（\\"软关节\\"）人群的简单日志——记录疼痛、柔韧度变化、半脱位或脱位，配上照片和Notes，按关节自动分组看规律。给你的理疗师、风湿科医生看再合适不过。")',
         'Text("A simple journal for hypermobile joints — log pain, flexibility changes, subluxations or dislocations with photos and notes. Entries group themselves by joint so patterns jump out. Perfect to show your physio or rheumatologist.")'),
        ('.navigationTitle("关于与Privacy")', '.navigationTitle("About & Privacy")'),
    ],
    "HyperLog/ContentView.swift": [
        ('Label("删除", systemImage: "trash")', 'Label("Delete", systemImage: "trash")'),
        ('Text("疼\\(entry.painDurationLabel)")', 'Text("pain: \\(entry.painDurationLabel)")'),
    ],
    "HyperLog/DoctorReportView.swift": [
        ('Picker("范围", selection: $range)', 'Picker("Range", selection: $range)'),
        ('Text("PDF 包含：发作统计（总次数/各Area/严重/就医）＋ 图表（Area条形图/每日趋势）＋ 最近 Beighton 分 ＋ Episode details（时间/Area/程度/疼多久/怎么处理/诱因/照片/Notes）")',
         'Text("PDF includes: summary stats, per-joint bar chart, daily trend, latest Beighton score, and the full episode list (time / area / severity / pain duration / treatment / triggers / photos / notes).")'),
    ],
    "HyperLog/FeedbackView.swift": [
        ('TextField("哪里好用、哪里别扭、想要什么功能……直接写，开发者本人看。", text: $text, axis: .vertical)',
         'TextField("What works, what doesn\'t, what you wish existed — the developer reads every message.", text: $text, axis: .vertical)'),
    ],
    "HyperLog/PhotoCompareView.swift": [
        ('Text("还没有带照片的记录——记条目时附上照片，这里就能By area并排对比变化。")',
         'Text("No entries with photos yet — attach photos to entries to compare changes side by side here.")'),
    ],
}

for rel, pairs in FIX.items():
    path = os.path.join(BASE, rel)
    txt = open(path, encoding="utf-8").read()
    for old, new in pairs:
        if old in txt:
            txt = txt.replace(old, new)
            print("fixed:", rel, old[:40])
        else:
            print("NOT FOUND:", rel, old[:40])
    open(path, "w", encoding="utf-8").write(txt)
print("DONE3")
