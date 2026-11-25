import SwiftUI
import MessageUI

// MARK: - 报告（给医生看的证据）
// 旧版是一屏「五行统计 + 两个同义按钮 + 三行说明」，像后台管理界面。
// 现在：大号数字先行、部位条形图直接画在页面上、30 日热度条、一个主按钮。
// PDF 生成逻辑保持原样，只把硬编码紫色换成 Theme.accentUI。

struct PDFAttachment: Identifiable {
    let id = UUID()
    let data: Data?
}

struct DoctorReportView: View {
    @State private var range = 1   // 0=7天 1=30天 2=All
    @State private var entries: [JointEntry] = EntryStore.load()
    @State private var pdfData: PDFAttachment?
    @State private var showPaywall = false

    @EnvironmentObject private var pro: ProStore

    private var ranged: [JointEntry] {
        switch range {
        case 0: return entries.filter { $0.date >= Date().addingTimeInterval(-7 * 86400) }
        case 2: return entries
        default: return entries.filter { $0.date >= Date().addingTimeInterval(-30 * 86400) }
        }
    }

    private var groups: [(part: String, label: String, count: Int, items: [JointEntry])] {
        EntryStore.grouped(ranged)
    }

    private var severeCount: Int { ranged.filter { $0.severity >= 3 }.count }
    private var hospitalCount: Int { ranged.filter { $0.treatment == "hospital" }.count }
    private var maxAreaCount: Int { max(groups.first?.count ?? 1, 1) }
    private var rangeLabel: String {
        switch range {
        case 0: return L("The last 7 days")
        case 2: return L("All time")
        default: return L("The last 30 days")
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerBlock
                rangeChips
                statCard
                areaBars
                dayStrip
                actions
            }
            .padding(.bottom, 34)
        }
        .background(Theme.paper)
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(item: $pdfData) { attachment in
            if let data = attachment.data {
                PDFMailComposer(attachment: data, filename: "HyperLog-Report.pdf")
            }
        }
    }

    // MARK: 头

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("FOR YOUR DOCTOR")
                .font(Theme.mono(9.5))
                .foregroundColor(Theme.ink3)
            Text(rangeLabel)
                .font(Theme.serif(28))
                .foregroundColor(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var rangeChips: some View {
        HStack(spacing: 6) {
            rangeChip("7 days", 0)
            rangeChip("30 days", 1)
            rangeChip("All", 2)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    private func rangeChip(_ text: LocalizedStringKey, _ tag: Int) -> some View {
        let selected = range == tag
        return Button {
            range = tag
        } label: {
            Text(text)
                .font(Theme.ui(11.5, selected ? .semibold : .medium))
                .foregroundColor(selected ? .white : Theme.ink2)
                .padding(.horizontal, 13)
                .frame(height: 32)
                .background(Capsule().fill(selected ? Theme.accent : Theme.surface))
                .overlay(Capsule().stroke(selected ? Theme.accent : Theme.hair, lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }

    // MARK: 主数字

    private var statCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("EPISODES RECORDED")
                .font(Theme.mono(9))
                .foregroundColor(Theme.ink3)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(ranged.count)")
                    .font(Theme.serif(46))
                    .foregroundColor(Theme.ink)
                Text("episodes")
                    .font(Theme.ui(12))
                    .foregroundColor(Theme.ink2)
                Spacer(minLength: 4)
                Text(comparisonText)
                    .font(Theme.mono(10, .bold))
                    .foregroundColor(Theme.ink3)
            }
            .padding(.top, 2)

            Rectangle()
                .fill(Theme.hair)
                .frame(height: 1)
                .padding(.top, 10)

            HStack(spacing: 12) {
                metaStat("\(severeCount)", "severe")
                metaStat("\(hospitalCount)", "hospital reset")
                metaStat("\(groups.count)", "areas")
                Spacer(minLength: 0)
            }
            .padding(.top, 10)
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(Theme.hair, lineWidth: 1)
        )
        .padding(.horizontal, 18)
    }

    private func metaStat(_ value: String, _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(Theme.ui(11.5, .bold))
                .foregroundColor(Theme.ink)
            Text(label)
                .font(Theme.ui(10.5))
                .foregroundColor(Theme.ink2)
        }
    }

    private var comparisonText: String {
        // 与前一个等长周期对比；All 不做对比
        guard range != 2 else { return "" }
        let days = range == 0 ? 7 : 30
        let now = Date()
        let start = now.addingTimeInterval(-Double(days) * 86400)
        let prevStart = start.addingTimeInterval(-Double(days) * 86400)
        let prev = entries.filter { $0.date >= prevStart && $0.date < start }.count
        let delta = ranged.count - prev
        if delta == 0 { return L("even vs prev.") }
        let sign = delta > 0 ? "+" : "-"
        return L("%@ vs prev.", sign + "\(abs(delta))")
    }

    // MARK: 部位条形

    private var areaBars: some View {
        VStack(spacing: 0) {
            ForEach(Array(groups.prefix(5).enumerated()), id: \.offset) { _, group in
                areaRow(group.label, group.count)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(Theme.hair, lineWidth: 1)
        )
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private func areaRow(_ label: String, _ count: Int) -> some View {
        HStack(spacing: 9) {
            Text(label)
                .font(Theme.ui(11.5, .medium))
                .foregroundColor(Theme.ink)
                .frame(width: 62, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.paper)
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: max(geo.size.width * CGFloat(count) / CGFloat(maxAreaCount), 6))
                }
            }
            .frame(height: 7)
            Text("\(count)")
                .font(Theme.mono(10.5))
                .foregroundColor(Theme.ink2)
                .frame(width: 24, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }

    // MARK: 30 日热度条

    private var dayStrip: some View {
        let days = dailyCounts()
        let peak = max(days.map { $0.1 }.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 2.5) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, item in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(item.1 == 0 ? Theme.hair : Theme.severityColor(item.1 >= peak ? 3 : (item.1 >= 2 ? 2 : 1)))
                        .frame(height: item.1 == 0 ? 5 : 8 + CGFloat(item.1) / CGFloat(peak) * 22)
                }
            }
            .frame(height: 30, alignment: .bottom)

            HStack {
                Text(firstDayLabel(days))
                Spacer()
                Text("TODAY")
            }
            .font(Theme.mono(8.5))
            .foregroundColor(Theme.ink3)
            .padding(.top, 6)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    private func firstDayLabel(_ days: [(String, Int)]) -> String {
        guard let first = days.first else { return "" }
        return first.0.uppercased()
    }

    // MARK: 行动

    private var actions: some View {
        VStack(spacing: 10) {
            if !pro.isPro {
                HStack(spacing: 6) {
                    ProBadge()
                    Text("Exporting is part of Pro")
                        .font(Theme.ui(11))
                        .foregroundColor(Theme.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            Button {
                if pro.isPro { sendToDoctor() } else { showPaywall = true }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: pro.isPro ? "doc.text" : "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Send to doctor")
                        .font(Theme.ui(14.5, .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 13).fill(Theme.accent))
            }
            .buttonStyle(.plain)

            if pro.isPro {
                Menu {
                    Button {
                        if let url = makeCSV() { share(url) }
                    } label: {
                        Label("Spreadsheet (CSV)", systemImage: "tablecells")
                    }
                    Button {
                        if let url = makeText() { share(url) }
                    } label: {
                        Label("Plain text", systemImage: "doc.plaintext")
                    }
                } label: {
                    otherFormatsLabel
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    otherFormatsLabel
                }
                .buttonStyle(.plain)
            }

            Text("Summary, per-area chart, daily trend, latest Beighton score and the full episode list — photos included.")
                .font(Theme.ui(10))
                .foregroundColor(Theme.ink3)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 10)
                .padding(.top, 2)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(pro) }
    }

    private var otherFormatsLabel: some View {
        HStack(spacing: 4) {
            Text("Other formats")
                .font(Theme.ui(12, .semibold))
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundColor(Theme.accent)
    }

    private func sendToDoctor() {
        guard let url = makePDF() else { return }
        if MFMailComposeViewController.canSendMail() {
            pdfData = PDFAttachment(data: try? Data(contentsOf: url))
        } else {
            // 未配系统邮件账户（国内常见）——直接走分享面板
            share(url)
        }
    }

    private func share(_ url: URL) {
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first?.present(av, animated: true)
    }

    // MARK: - PDF（逻辑未改，仅换色）

    // MARK: 其他格式（CSV / 纯文本）——与「发给医生」的 PDF 明确区分

    private var pdfRangeText: String {
        L(range == 0 ? "Last 7 days" : range == 1 ? "Last 30 days" : "All")
    }

    private func makeText() -> URL? {
        var lines: [String] = []
        lines.append(L("HyperLog Joint Episode Report"))
        lines.append(L("Range: %@ · %@ episodes · Severe %@ · Hospital: %@",
                       pdfRangeText, "\(ranged.count)", "\(severeCount)", "\(hospitalCount)"))
        lines.append("")
        for group in groups {
            lines.append("\(group.label): \(group.count)")
            for e in group.items {
                var parts = [e.date.formatted(.dateTime.month().day().hour().minute()), e.severityLabel]
                if !e.painDurationLabel.isEmpty { parts.append(e.painDurationLabel) }
                if !e.treatmentLabel.isEmpty { parts.append(e.treatmentLabel) }
                lines.append("  · " + parts.joined(separator: " · "))
                if !e.triggers.isEmpty {
                    let tr = e.triggers
                        .compactMap { k in EntryStore.triggerOptions.first(where: { $0.key == k })?.label }
                        .joined(separator: ", ")
                    lines.append("    " + L("Triggers: %@", tr))
                }
                if !e.notes.isEmpty {
                    lines.append("    " + L("Notes: %@", e.notes))
                }
            }
        }
        if let b = ranged.compactMap(\.beighton).last {
            lines.append("")
            lines.append(L("Latest Beighton: %@", "\(b)/9"))
        }
        lines.append("")
        lines.append(L("Self-recorded with HyperLog — for reference, not a diagnosis."))
        return writeTemp(lines.joined(separator: "\n"), name: "HyperLog-Report.txt")
    }

    private func makeCSV() -> URL? {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"

        var rows: [String] = []
        let header = [L("Date"), L("Time"), L("Area"), L("Severity"), L("Pain duration"),
                      L("Treatment"), L("Triggers"), L("Beighton"), L("Photos"), L("Notes")]
        rows.append(header.map(csvField).joined(separator: ","))

        for e in ranged.sorted(by: { $0.date < $1.date }) {
            let triggers = e.triggers
                .compactMap { k in EntryStore.triggerOptions.first(where: { $0.key == k })?.label }
                .joined(separator: " / ")
            let cells = [
                dateFmt.string(from: e.date),
                timeFmt.string(from: e.date),
                EntryStore.displayPart(e.bodyPart),
                Theme.severityLabel(e.severity),
                e.painDurationLabel,
                e.treatmentLabel,
                triggers,
                e.beighton.map { "\($0)/9" } ?? "",
                "\((e.photoFiles ?? []).count)",
                e.notes
            ]
            rows.append(cells.map(csvField).joined(separator: ","))
        }
        // BOM：让 Excel 正确识别 UTF-8（中文不乱码）
        let body = "\u{FEFF}" + rows.joined(separator: "\r\n")
        return writeTemp(body, name: "HyperLog-Report.csv")
    }

    private func csvField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private func writeTemp(_ content: String, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try content.data(using: .utf8)?.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private func makePDF() -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("HyperLog-Report.pdf")
        let purple = Theme.accentUI
        let groups = EntryStore.grouped(ranged)

        // 按日统计（范围天数内每天的发作数）
        let days = dailyCounts()

        try? renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            let cg = ctx.cgContext

            // 标题
            (L("HyperLog Joint Episode Report") as NSString).draw(
                at: CGPoint(x: 40, y: 36),
                withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18), .foregroundColor: purple])
            let sub = L("Range: %@ · %@ episodes · Severe %@ · Hospital: %@",
                        pdfRangeText,
                        "\(ranged.count)",
                        "\(ranged.filter { $0.severity >= 3 }.count)",
                        "\(ranged.filter { $0.treatment == "hospital" }.count)")
            if let b = ranged.compactMap(\.beighton).last {
                (L("Latest Beighton: %@", "\(b)/9") as NSString).draw(
                    at: CGPoint(x: 40, y: 76),
                    withAttributes: [.font: UIFont.boldSystemFont(ofSize: 12), .foregroundColor: purple])
            }
            (sub as NSString).draw(
                at: CGPoint(x: 40, y: 62),
                withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkGray])

            var y: CGFloat = 92

            // 图1：Episodes per area（横向条形）
            (L("Episodes per area") as NSString).draw(
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
            (L("Daily trend") as NSString).draw(
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
                cg.setFillColor(count >= 3 ? Theme.severityUI(3).cgColor : purple.cgColor)
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
            (L("Episode details") as NSString).draw(
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
                var line = "\(e.date.formatted(.dateTime.month().day().hour().minute())) · \(EntryStore.displayPart(e.bodyPart)) · \(e.severityLabel)"
                if !e.painDurationLabel.isEmpty { line += " · pain: \(e.painDurationLabel)" }
                if !e.treatmentLabel.isEmpty { line += " · \(e.treatmentLabel)" }
                (line as NSString).draw(
                    at: CGPoint(x: 40, y: y),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.black])
                y += 13
                if !e.triggers.isEmpty {
                    let tr = e.triggers.compactMap { k in EntryStore.triggerOptions.first(where: { $0.key == k })?.label }.joined(separator: "、")
                    (L("Triggers: %@", tr) as NSString).draw(
                        at: CGPoint(x: 52, y: y),
                        withAttributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.darkGray])
                    y += 12
                }
                if !e.notes.isEmpty {
                    (L("Notes: %@", e.notes) as NSString).draw(
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
                    (L("Beighton: %@", "\(b)/9") as NSString).draw(
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
