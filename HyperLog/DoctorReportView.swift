import SwiftUI
import MessageUI

// MARK: - Report Sharing（健哥 11-04 令：医生报告→Report Sharing；只留 PDF+内容说明）
struct PDFAttachment: Identifiable {
    let id = UUID()
    let data: Data?
}

struct DoctorReportView: View {
    @State private var range = 1   // 0=7天 1=30天 2=All
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
            Picker("Range", selection: $range) {
                Text("Last 7 days").tag(0)
                Text("Last 30 days").tag(1)
                Text("All").tag(2)
            }
            .pickerStyle(.segmented)

            Section("Preview (this is what the PDF contains)") {
                statRow("Total episodes", "\(ranged.count)")
                statRow("Areas involved", "\(EntryStore.grouped(ranged).count)")
                if let top = EntryStore.grouped(ranged).first {
                    statRow("Most frequent area", "\(top.label) — \(top.count)")
                }
                let severe = ranged.filter { $0.severity >= 3 }.count
                statRow("Severe episodes (subluxation/dislocation)", "\(severe)")
                let hospital = ranged.filter { $0.treatment == "hospital" }.count
                statRow("Hospital repositioning", "\(hospital)")
                ForEach(EntryStore.grouped(ranged), id: \.part) { g in
                    HStack {
                        Text(g.label).foregroundColor(.secondary)
                        Spacer()
                        Text("\(g.count)").foregroundColor(.purple)
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
                    Label("Email to doctor", systemImage: "envelope.fill")
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
                    Label("Share other ways (Gmail/Outlook/Messages/Files)", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Text("PDF includes: summary stats, per-joint bar chart, daily trend, latest Beighton score, and the full episode list (time / area / severity / pain duration / treatment / triggers / photos / notes).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Report Sharing")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $pdfData) { attachment in
            if let data = attachment.data {
                PDFMailComposer(attachment: data, filename: "HyperLog-Report.pdf")
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
        var lines = ["HyperLog Joint Episode Report"]
        lines.append("Range: \(range == 0 ? "last 7 days" : range == 1 ? "last 30 days" : "All") ·  \(ranged.count)  episodes")
        lines.append("Severe episodes (subluxation/dislocation)：\(ranged.filter { $0.severity >= 3 }.count)")
        lines.append("Hospital repositioning：\(ranged.filter { $0.treatment == "hospital" }.count)")
        lines.append("")
        for g in EntryStore.grouped(ranged) {
            lines.append("\(g.label): \(g.count)")
            for e in g.items.prefix(50) {
                var parts = [e.date.formatted(.dateTime.month().day().hour().minute())]
                parts.append(e.severityLabel)
                if !e.painDurationLabel.isEmpty { parts.append("pain: \(e.painDurationLabel)") }
                if !e.treatmentLabel.isEmpty { parts.append(e.treatmentLabel) }
                lines.append("  · " + parts.joined(separator: " · "))
            }
        }
        if let b = entries.compactMap(\.beighton).last {
            lines.append("")
            lines.append("Latest Beighton: \(b)/9")
        }
        lines.append("(Self-recorded with HyperLog — for reference, not a diagnosis.)")
        return lines.joined(separator: "\n")
    }

    /// PDF：概览+图表（Area横条图/按日趋势竖条图）+Episode details+Beighton——健哥 11-04 令：不能只有文字
    private func makePDF() -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("HyperLog-Report.pdf")
        let purple = UIColor(red: 0.45, green: 0.3, blue: 0.7, alpha: 1)
        let groups = EntryStore.grouped(ranged)

        // 按日统计（范围天数内每天的发作数）
        let days = dailyCounts()

        try? renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            let cg = ctx.cgContext

            // 标题
            ("HyperLog Joint Episode Report" as NSString).draw(
                at: CGPoint(x: 40, y: 36),
                withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18), .foregroundColor: purple])
            let sub = "Range: \(range == 0 ? "last 7 days" : range == 1 ? "last 30 days" : "All") ·  \(ranged.count)  episodes · Severe \(ranged.filter { $0.severity >= 3 }.count) · Hospital: \(ranged.filter { $0.treatment == "hospital" }.count)"
            if let b = ranged.compactMap(\.beighton).last {
                ("Latest Beighton: \(b)/9" as NSString).draw(
                    at: CGPoint(x: 40, y: 76),
                    withAttributes: [.font: UIFont.boldSystemFont(ofSize: 12), .foregroundColor: purple])
            }
            (sub as NSString).draw(
                at: CGPoint(x: 40, y: 62),
                withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkGray])

            var y: CGFloat = 92

            // 图1：Episodes per area（横向条形）
            ("Episodes per area" as NSString).draw(
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
            ("Daily trend" as NSString).draw(
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

            // Episode details（含照片小图，自动翻页）
            ("Episode details" as NSString).draw(
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
                    ("Triggers: \(tr)" as NSString).draw(
                        at: CGPoint(x: 52, y: y),
                        withAttributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.darkGray])
                    y += 12
                }
                if !e.notes.isEmpty {
                    ("Notes：\(e.notes)" as NSString).draw(
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
