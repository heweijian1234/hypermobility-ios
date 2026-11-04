# -*- coding: utf-8 -*-
import re, os, sys
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
BASE = r"E:\AI-Projects\个人成长\10-项目\SaaS项目\hypermobility-ios\HyperLog"
cjk = re.compile(r"[一-鿿]")
bad = 0
for root, _, files in os.walk(BASE):
    for f in files:
        if not f.endswith(".swift"):
            continue
        for i, line in enumerate(open(os.path.join(root, f), encoding="utf-8"), 1):
            if cjk.search(line) and re.search(r'Text\("|Label\("|Section\("|Button\("|Picker\("|navigationTitle|TextField\("', line):
                print(f"{f}:{i}: {line.strip()[:80]}")
                bad += 1
print("CLEAN" if bad == 0 else f"{bad} LEFT")
