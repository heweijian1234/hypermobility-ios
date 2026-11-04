import SwiftUI
import MessageUI

// MARK: - 报告分享（健哥 11-04 令：医生报告→报告分享；只留 PDF+内容说明）
struct PDFAttachment: Identifiable {
    let id = UUID()
    let data: Data?
}

struct DoctorReportView: View {
    @State private var range = 1   // 0=7天 1=30天 2=全部
    @State private var entries: [JointEntry] = EntryStore.load()
    @State private var pdfData: PDFAttachment?

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

            Section("预览（PDF 里就是这些）") {
                statRow("发作总次数", "\(ranged.count) 次")
                statRow("涉及部位", "\(EntryStore.grouped(ranged).count) 个")
                if let top = EntryStore.grouped(ranged).first {
                    statRow("最频繁部位", "\(top.label)（\(top.count) 次）")
                }
                let severe = ranged.filter { $0.severity >= 3 }.count
                statRow("严重发作（半脱位/脱位）", "\(severe) 次")
                let hospital = ranged.filter { $0.treatment == "hospital" }.count
                statRow("去医院复位", "\(hospital) 次")
                ForEach(EntryStore.grouped(ranged), id: \.part) { g in
                    HStack {
                        Text("【\(g.label)】").foregroundColor(.secondary)
                        Spacer()
                        Text("\(g.count) 次").foregroundColor(.purple)
                    }
                }
            }

            Section {
                Button {
                    guard let url = makePDF() else { return }
                    if MFMailComposeViewController.canSendMail() {
                        pdfData = PDFAttachment(data: try? Data(contentsOf: url))
                    } else {
                        // 未配系统邮件账户（国内常见）——直接走分享面板（QQ邮箱/Gmail/Outlook 全在里面）
                        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        UIApplication.shared.connectedScenes
                            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
                            .first?.present(av, animated: true)
                    }
                } label: {
                    Label("邮件发送给医生", systemImage: "envelope.fill")
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
                    Label("其他方式分享（Gmail/Outlook/信息/存储）", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Text("PDF 包含：发作统计（总次数/各部位/严重/就医）＋ 图表（部位条形图/每日趋势）＋ 最近 Beighton 分 ＋ 逐条明细（时间/部位/程度/疼多久/怎么处理/诱因/照片/备注）")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("报告分享")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $pdfData) { attachment in
            if let data = attachment.data {
                PDFMailComposer(attachment: data, filename: "HyperLog报告.pdf")
            }
        }
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
        lines.append("严重发作（半脱位/脱位）：\(ranged.filter { $0.severity >= 3 }.count) 次")
        lines.append("去医院复位：\(ranged.filter { $0.treatment == "hospital" }.count) 次")
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
        if let b = entries.compactMap(\.beighton).last {
            lines.append("")
            lines.append("最近 Beighton 自评：\(b)/9")
        }
        lines.append("（HyperLog 患者自录——供医生参考，非诊断）")
        return lines.joined(separator: "\n")
    }

    /// PDF：概览+图表（部位横条图/按日趋势竖条图）+逐条明细+Beighton——健哥 11-04 令：不能只有文字
    private func makePDF() -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("HyperLog报告.pdf")
        let purple = UIColor(red: 0.45, green: 0.3, blue: 0.7, alpha: 1)
        let groups = EntryStore.grouped(ranged)

        // 按日统计（范围天数内每天的发作数）
        let days = dailyCounts()

        try? renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            let cg = ctx.cgContext

            // 标题
            ("HyperLog 关节发作报告" as NSString).draw(
                at: CGPoint(x: 40, y: 36),
                withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18), .foregroundColor: purple])
            let sub = "范围：\(range == 0 ? "最近7天" : range == 1 ? "最近30天" : "全部") · 共 \(ranged.count) 次发作 · 严重 \(ranged.filter { $0.severity >= 3 }.count) 次 · 就医复位 \(ranged.filter { $0.treatment == "hospital" }.count) 次"
            if let b = ranged.compactMap(\.beighton).last {
                ("最近 Beighton 自评：\(b)/9" as NSString).draw(
                    at: CGPoint(x: 40, y: 76),
                    withAttributes: [.font: UIFont.boldSystemFont(ofSize: 12), .foregroundColor: purple])
            }
            (sub as NSString).draw(
                at: CGPoint(x: 40, y: 62),
                withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkGray])

            var y: CGFloat = 92

            // 图1：各部位发作次数（横向条形）
            ("各部位发作次数" as NSString).draw(
                at: CGPoint(x: 40, y: y),
                withAttributes: [.font: UIFont.boldSystemFont(ofSize: 12), .foregroundColor: UIColor.black])
            y += 18
            let maxCount = max(groups.map(\.count).max() ?? 1, 1)
            for g in groups.prefix(10) {
                let label = g.label as NSString
                label.draw(at: CGPoint(x: 40, y: y),
                           withAttributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.darkGray])
                let barW = CGFloat(g.count) / CGFloat(maxCount) * 380
                cg.setFillColor(purple.cgColor)
                cg.fill(CGRect(x: 90, y: y + 1, width: max(barW, 3), height: 10))
                ("\(g.count)" as NSString).draw(at: CGPoint(x: 92 + max(barW, 3), y: y),
                                                withAttributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.black])
                y += 16
            }

            y += 12
            // 图2：按日发作趋势（竖向条形）
            ("每日发作趋势" as NSString).draw(
                at: CGPoint(x: 40, y: y),
                withAttributes: [.font: UIFont.boldSystemFont(ofSize: 12), .foregroundColor: UIColor.black])
            y += 14
            let chartH: CGFloat = 90
            let chartW: CGFloat = 500
            let maxDay = max(days.map(\.1).max() ?? 1, 1)
            let barSlot = chartW / CGFloat(max(days.count, 1))
            cg.setStrokeColor(UIColor.lightGray.cgColor)
            cg.strokeLineSegments(between: [CGPoint(x: 40, y: y + chartH), CGPoint(x: 40 + chartW, y: y + chartH)])
            for (i, (day, count)) in days.enumerated() {
                let h = CGFloat(count) / CGFloat(maxDay) * (chartH - 14)
                let x = 40 + CGFloat(i) * barSlot + barSlot * 0.2
                cg.setFillColor(count >= 3 ? UIColor.systemOrange.cgColor : purple.cgColor)
                cg.fill(CGRect(x: x, y: y + chartH - max(h, count > 0 ? 3 : 0), width: barSlot * 0.6, height: max(h, count > 0 ? 3 : 0)))
                if count > 0 {
                    ("\(count)" as NSString).draw(at: CGPoint(x: x - 2, y: y + chartH - max(h, 3) - 10),
                                                  withAttributes: [.font: UIFont.systemFont(ofSize: 7), .foregroundColor: UIColor.black])
                }
                if i % max(days.count / 8, 1) == 0 {
                    let d = day.prefix(5)
                    (d as NSString).draw(at: CGPoint(x: x - 4, y: y + chartH + 2),
                                         withAttributes: [.font: UIFont.systemFont(ofSize: 6), .foregroundColor: UIColor.gray])
                }
            }
            y += chartH + 18

            // 逐条明细（含照片小图，自动翻页）
            ("逐条明细" as NSString).draw(
                at: CGPoint(x: 40, y: y),
                withAttributes: [.font: UIFont.boldSystemFont(ofSize: 12), .foregroundColor: UIColor.black])
            y += 16
            for e in ranged.prefix(80) {
                // 翻页检查（每条至少需要 34pt；带照片 100pt）
                let photos = (e.photoFiles ?? []).compactMap { UIImage(contentsOfFile: EntryStore.photoURL($0).path) }
                let need: CGFloat = photos.isEmpty ? 18 : 14 + CGFloat((photos.count + 3) / 4) * 66
                if y + need > 802 {
                    ctx.beginPage()
                    y = 40
                }
                var line = "\(e.date.formatted(.dateTime.month().day().hour().minute())) · \(EntryStore.bodyParts.first(where: { $0.key == e.bodyPart })?.label ?? e.bodyPart) · \(e.severityLabel)"
                if !e.painDurationLabel.isEmpty { line += " · 疼\(e.painDurationLabel)" }
                if !e.treatmentLabel.isEmpty { line += " · \(e.treatmentLabel)" }
                (line as NSString).draw(
                    at: CGPoint(x: 40, y: y),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.black])
                y += 13
                if !e.triggers.isEmpty {
                    let tr = e.triggers.compactMap { k in EntryStore.triggerOptions.first(where: { $0.key == k })?.label }.joined(separator: "、")
                    ("诱因：\(tr)" as NSString).draw(
                        at: CGPoint(x: 52, y: y),
                        withAttributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.darkGray])
                    y += 12
                }
                if !e.notes.isEmpty {
                    ("备注：\(e.notes)" as NSString).draw(
                        in: CGRect(x: 52, y: y, width: 480, height: 24),
                        withAttributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.darkGray])
                    y += 14
                }
                for (i, img) in photos.prefix(8).enumerated() {
                    let col = i % 4
                    let x = 52 + CGFloat(col) * 66
                    if col == 0 && i > 0 { y += 66 }
                    let rect = CGRect(x: x, y: y, width: 60, height: 60)
                    cg.saveGState()
                    cg.clip(to: rect)
                    img.draw(in: rect)
                    cg.restoreGState()
                }
                if !photos.isEmpty { y += 66 + 6 }
                if let b = e.beighton {
                    ("Beighton：\(b)/9" as NSString).draw(
                        at: CGPoint(x: 52, y: y),
                        withAttributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: purple])
                    y += 12
                }
                y += 4
            }
        }
        return url
    }

    /// 范围内按日 (日期串, 次数)
    private func dailyCounts() -> [(String, Int)] {
        let fmt = DateFormatter()
        fmt.dateFormat = "MM-dd"
        var dict: [String: Int] = [:]
        for e in ranged {
            let k = fmt.string(from: e.date)
            dict[k, default: 0] += 1
        }
        return dict.sorted { $0.key < $1.key }
    }
}
