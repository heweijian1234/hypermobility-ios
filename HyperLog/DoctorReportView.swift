import SwiftUI

// MARK: - 给医生的范围报告（P0-3：范围选择+汇总；P2-7：PDF 生成）
struct DoctorReportView: View {
    @State private var range = 1   // 0=7天 1=30天 2=全部
    @State private var entries: [JointEntry] = EntryStore.load()
    @State private var shareItem: String?

    private var ranged: [JointEntry] {
        switch range {
        case 0: return entries.filter { $0.date >= Date().addingTimeInterval(-7 * 86400) }
        case 2: return entries
        default: return entries.filter { $0.date >= Date().addingTimeInterval(-30 * 86400) }
        }
    }

    var body: some View {
        List {
            Picker("范围", selection: $range) {
                Text("最近 7 天").tag(0)
                Text("最近 30 天").tag(1)
                Text("全部").tag(2)
            }
            .pickerStyle(.segmented)

            Section("概览（给医生看）") {
                statRow("发作总次数", "\(ranged.count) 次")
                statRow("涉及部位", "\(EntryStore.grouped(ranged).count) 个")
                if let top = EntryStore.grouped(ranged).first {
                    statRow("最频繁部位", "\(top.label)（\(top.count) 次）")
                }
                let severe = ranged.filter { $0.severity >= 3 }.count
                statRow("严重发作（半脱位/脱位）", "\(severe) 次")
                let hospital = ranged.filter { $0.treatment == "hospital" }.count
                statRow("去医院复位", "\(hospital) 次")
            }

            Section("按部位") {
                ForEach(EntryStore.grouped(ranged), id: \.part) { g in
                    HStack {
                        Text(g.label)
                        Spacer()
                        Text("\(g.count) 次").foregroundColor(.purple)
                    }
                }
            }

            Section {
                ShareLink(item: textReport, subject: Text("HyperLog 关节报告")) {
                    Label("分享报告（文字版）", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                Button {
                    if let url = makePDF() {
                        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        UIApplication.shared.connectedScenes
                            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
                            .first?.present(av, animated: true)
                    }
                } label: {
                    Label("导出 PDF（给医生）", systemImage: "doc.richtext")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .navigationTitle("医生报告")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundColor(.secondary)
            Spacer()
            Text(v).bold()
        }
    }

    private var textReport: String {
        var lines = ["HyperLog 关节发作报告"]
        lines.append("范围：\(range == 0 ? "最近7天" : range == 1 ? "最近30天" : "全部") · 共 \(ranged.count) 次发作")
        lines.append("")
        for g in EntryStore.grouped(ranged) {
            lines.append("【\(g.label)】\(g.count) 次")
            for e in g.items.prefix(50) {
                var parts = [e.date.formatted(.dateTime.month().day().hour().minute())]
                parts.append(e.severityLabel)
                if !e.painDurationLabel.isEmpty { parts.append("疼\(e.painDurationLabel)") }
                if !e.treatmentLabel.isEmpty { parts.append(e.treatmentLabel) }
                lines.append("  · " + parts.joined(separator: " · "))
            }
        }
        if let b = EntryStore.loadBeighton().first {
            lines.append("")
            lines.append("最近 Beighton 自评：\(b.score)/9（\(b.date.formatted(.dateTime.month().day()))）")
        }
        lines.append("（HyperLog 患者自录——供医生参考，非诊断）")
        return lines.joined(separator: "\n")
    }

    /// 简版 PDF：概览+按部位统计（P2-7；付费墙上线时再锁）
    private func makePDF() -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 72dpi
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("HyperLog报告.pdf")
        let text = textReport as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.black,
        ]
        try? renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor.purple,
            ]
            ("HyperLog 关节发作报告" as NSString).draw(at: CGPoint(x: 40, y: 40), withAttributes: titleAttrs)
            text.draw(in: CGRect(x: 40, y: 80, width: 515, height: 720), withAttributes: attrs)
        }
        return url
    }
}
