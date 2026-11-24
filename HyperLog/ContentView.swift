import SwiftUI
import PhotosUI

// MARK: - 主页
// 结构（对照 docs/UI评审-HyperLog-2026-11-25.html）：
// 本周概览 → 记录列表 → 底部单一主行动。
// 旧版三个 64pt 圆按钮（Quick Log / ＋ / More）平分注意力，且 overlay 不参与 List 布局会压住末行；
// 现在收成一条 safeAreaInset 主按钮，More 上移到导航栏。

struct ContentView: View {

    @State private var entries: [JointEntry] = EntryStore.load()
    @State private var grouping = false
    @State private var editingEntry: JointEntry?
    @State private var showEditor = false
    @State private var showCapture = false
    @State private var pendingDetails: JointEntry?
    @State private var goReport = false
    @State private var goPhotos = false
    @State private var goFeedback = false
    @State private var selectedDay: Date?
    @State private var showAll = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()
                if entries.isEmpty {
                    emptyState
                } else {
                    entryList
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink { AboutView() } label: {
                        Image(systemName: "info.circle")
                    }
                    .tint(Theme.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { goReport = true } label: {
                            Label("Report sharing", systemImage: "square.and.arrow.up")
                        }
                        Button { goPhotos = true } label: {
                            Label("Photo compare", systemImage: "photo.on.rectangle.angled")
                        }
                        Divider()
                        Button { goFeedback = true } label: {
                            Label("Feedback", systemImage: "paperplane")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .tint(Theme.accent)
                }
            }
            .safeAreaInset(edge: .bottom) { logBar }
            .navigationDestination(isPresented: $goReport) { DoctorReportView() }
            .navigationDestination(isPresented: $goPhotos) { PhotoCompareView() }
            .navigationDestination(isPresented: $goFeedback) { FeedbackView() }
            .sheet(isPresented: $showCapture, onDismiss: handleCaptureDismiss) {
                QuickCaptureView(
                    lastPart: entries.first?.bodyPart ?? "knee",
                    lastSeverity: entries.first?.severity ?? 2,
                    onSave: { entry in save(entry) },
                    onDetails: { entry in pendingDetails = entry }
                )
                .presentationDetents([.height(560), .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showEditor, onDismiss: {
                entries = EntryStore.load()
                editingEntry = nil
            }) {
                EntryEditor(editing: editingEntry) { new in
                    if let new { save(new) }
                    showEditor = false
                }
            }
        }
    }

    // MARK: 列表

    private var entryList: some View {
        List {
            headerRow
            weekRow
            sectionHeadRow
            rowsContent
            earlierRow
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
    }

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(dateRangeText)
                .font(Theme.mono(9.5))
                .foregroundColor(Theme.ink3)
            Text("This week")
                .font(Theme.serif(31))
                .foregroundColor(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
        .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 4, trailing: 18))
        .listRowSeparator(.hidden)
        .listRowBackground(Theme.paper)
    }

    private var weekRow: some View {
        weekCard
            .listRowInsets(EdgeInsets(top: 8, leading: 18, bottom: 4, trailing: 18))
            .listRowSeparator(.hidden)
            .listRowBackground(Theme.paper)
    }

    private var weekCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("FLARE PATTERN")
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.ink3)
                Spacer()
                Button {
                    goReport = true
                } label: {
                    HStack(spacing: 2) {
                        Text("Report")
                            .font(Theme.ui(10.5, .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(Theme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 10)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(weekBuckets.enumerated()), id: \.offset) { _, bucket in
                    dayColumn(bucket)
                }
            }
            .frame(height: 62)

            Rectangle()
                .fill(Theme.hair)
                .frame(height: 1)
                .padding(.top, 12)

            weekFooter
                .padding(.top, 11)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke(Theme.hair, lineWidth: 1)
        )
    }

    /// 未选日期 = 本周汇总；点了柱子 = 那一天的发作详情
    @ViewBuilder
    private var weekFooter: some View {
        if let day = selectedDay {
            dayDetail(day)
        } else {
            weekSummary
        }
    }

    private var weekSummary: some View {
        HStack(alignment: .center, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(weekTotal)")
                    .font(Theme.serif(24))
                    .foregroundColor(Theme.ink)
                Text("flares")
                    .font(Theme.ui(11))
                    .foregroundColor(Theme.ink2)
            }
            Rectangle()
                .fill(Theme.hair)
                .frame(width: 1, height: 11)
                .padding(.horizontal, 2)
            Text(topAreaText)
                .font(Theme.ui(10.5))
                .foregroundColor(Theme.ink2)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(deltaText)
                .font(Theme.mono(10, .bold))
                .foregroundColor(weekDelta == 0 ? Theme.ink3 : Theme.severityColor(2))
                .lineLimit(1)
        }
    }

    private func dayDetail(_ day: Date) -> some View {
        let info = EntryStats.summary(for: day, in: entries)
        return HStack(alignment: .center, spacing: 6) {
            Text(day.formatted(.dateTime.month(.abbreviated).day()))
                .font(Theme.ui(11, .semibold))
                .foregroundColor(Theme.ink)
            Text(verbatim: "·")
                .font(Theme.ui(11))
                .foregroundColor(Theme.ink3)
            Text(L("%@ flares", "\(info.count)"))
                .font(Theme.ui(10.5))
                .foregroundColor(info.count == 0 ? Theme.ink3 : Theme.ink2)
            if !info.areas.isEmpty {
                Text(info.areas.joined(separator: ", "))
                    .font(Theme.ui(10.5))
                    .foregroundColor(Theme.ink3)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button {
                selectedDay = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.ink3)
            }
            .buttonStyle(.plain)
        }
    }

    private func dayColumn(_ bucket: (date: Date, count: Int, peak: Int)) -> some View {
        let isToday = Calendar.current.isDateInToday(bucket.date)
        let isSelected = selectedDay.map { Calendar.current.isDate($0, inSameDayAs: bucket.date) } ?? false
        let height = bucket.count == 0
            ? 5.0
            : min(14.0 + Double(bucket.peak) * 7.0 + Double(min(bucket.count, 3)) * 4.0, 40.0)
        let fill = bucket.count == 0 ? Theme.hair : Theme.severityColor(max(bucket.peak, 0))
        return Button {
            selectedDay = isSelected ? nil : bucket.date
        } label: {
            VStack(spacing: 5) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(fill)
                    .frame(height: height)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2.5)
                            .stroke(isSelected ? Theme.ink : Color.clear, lineWidth: 1.6)
                    )
                Text(EntryStats.weekdayLetter(bucket.date))
                    .font(Theme.mono(9, isToday ? .bold : .regular))
                    .foregroundColor(isToday ? Theme.paper : (isSelected ? Theme.ink : Theme.ink3))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(isToday ? Theme.ink : Color.clear, in: RoundedRectangle(cornerRadius: 3))
            }
            .frame(maxWidth: .infinity, maxHeight: 62, alignment: .bottom)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var sectionHeadRow: some View {
        HStack {
            Text(listSectionKey)
                .font(Theme.mono(9.5))
                .foregroundColor(Theme.ink3)
            Spacer()
            Button {
                grouping.toggle()
            } label: {
                HStack(spacing: 3) {
                    Text(groupingModeKey)
                        .font(Theme.ui(10.5, .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(Theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 21)
        .padding(.bottom, 2)
        .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
        .listRowSeparator(.hidden)
        .listRowBackground(Theme.paper)
    }

    @ViewBuilder
    private var rowsContent: some View {
        if grouping {
            ForEach(EntryStore.grouped(displayed), id: \.part) { group in
                groupLabel(group.label, group.count)
                ForEach(group.items) { entry in
                    row(entry)
                }
            }
        } else {
            ForEach(displayed) { entry in
                row(entry)
            }
        }
    }

    /// 记录变长后只列最近 7 天；更早的折成一行，点开再看
    @ViewBuilder
    private var earlierRow: some View {
        if hasEarlierEntry {
            Button {
                showAll.toggle()
            } label: {
                HStack {
                    Text(showAll
                         ? L("Show recent only")
                         : L("Show %@ earlier entries", "\(earlierCount)"))
                        .font(Theme.ui(11.5, .medium))
                    Spacer(minLength: 6)
                    Image(systemName: showAll ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(Theme.accent)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
            .listRowSeparator(.hidden)
            .listRowBackground(Theme.paper)
        }
    }

    private func groupLabel(_ label: String, _ count: Int) -> some View {
        Text("\(label.uppercased()) · \(count)")
            .font(Theme.mono(9))
            .foregroundColor(Theme.ink3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
            .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 2, trailing: 18))
            .listRowSeparator(.hidden)
            .listRowBackground(Theme.paper)
    }

    private func row(_ entry: JointEntry) -> some View {
        Button {
            editingEntry = entry
            showEditor = true
        } label: {
            EntryRow(entry: entry)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
        .listRowSeparator(.hidden)
        .listRowBackground(Theme.paper)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                delete(entry)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: 底部主行动

    private var logBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.hair)
                .frame(height: 0.5)
            Button {
                showCapture = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                    Text("Log a flare")
                        .font(Theme.ui(14.5, .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 13).fill(Theme.accent))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
        .background(Theme.paper)
    }

    // MARK: 空状态

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Date().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased())
                .font(Theme.mono(9.5))
                .foregroundColor(Theme.ink3)
            Text("HyperLog")
                .font(Theme.serif(23))
                .foregroundColor(Theme.ink)
                .padding(.top, 2)

            Spacer(minLength: 40)

            Text("Your joints,\non the record.")
                .font(Theme.serif(31))
                .foregroundColor(Theme.ink)
                .lineSpacing(3)

            Text("Log a flare in two taps today — the pattern it draws is what convinces a doctor tomorrow.")
                .font(Theme.ui(13))
                .foregroundColor(Theme.ink2)
                .lineSpacing(3)
                .padding(.top, 12)

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.accent)
                Text("No account. Photos and notes never leave this phone.")
                    .font(Theme.ui(11))
                    .foregroundColor(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.hair, lineWidth: 1))
            .padding(.top, 20)

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: 数据

    // MARK: 近 7 天窗口

    private var recentWindow: [JointEntry] {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date())) else {
            return entries
        }
        return entries.filter { $0.date >= start }
    }
    private var displayed: [JointEntry] {
        if showAll || recentWindow.isEmpty { return entries }
        return recentWindow
    }
    private var hasEarlierEntry: Bool {
        !recentWindow.isEmpty && entries.count > recentWindow.count
    }
    private var earlierCount: Int {
        max(entries.count - recentWindow.count, 0)
    }

    private var weekBuckets: [(date: Date, count: Int, peak: Int)] {
        EntryStats.dailyBuckets(entries, days: 7)
    }
    private var weekTotal: Int {
        weekBuckets.reduce(0) { $0 + $1.count }
    }
    private var weekDelta: Int {
        EntryStats.weekDelta(entries)
    }
    private var groupingModeKey: LocalizedStringKey {
        grouping ? "By time" : "By area"
    }
    private var listSectionKey: LocalizedStringKey {
        showAll ? "ALL ENTRIES" : "RECENT"
    }
    private var deltaText: String {
        if weekDelta == 0 { return L("even") }
        let sign = weekDelta > 0 ? "+" : "-"
        return L("%@ vs last", sign + "\(abs(weekDelta))")
    }
    private var topAreaText: String {
        guard let top = EntryStats.topArea(entries) else { return L("No pattern yet") }
        return L("%@ most frequent", top.label)
    }
    private var dateRangeText: String {
        let cal = Calendar.current
        let today = Date()
        let start = cal.date(byAdding: .day, value: -6, to: today) ?? today
        let a = start.formatted(.dateTime.month(.abbreviated).day())
        let b = today.formatted(.dateTime.month(.abbreviated).day())
        return "\(a) — \(b)".uppercased()
    }

    // MARK: 动作

    private func save(_ entry: JointEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        } else {
            entries.insert(entry, at: 0)
        }
        EntryStore.save(entries)
    }

    private func handleCaptureDismiss() {
        guard let pending = pendingDetails else { return }
        pendingDetails = nil
        editingEntry = pending
        // 等前一个 sheet 完全收起再弹编辑器，避免 presenting 冲突
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            showEditor = true
        }
    }

    private func delete(_ entry: JointEntry) {
        EntryStore.deletePhotoFiles(entry)
        entries.removeAll { $0.id == entry.id }
        EntryStore.save(entries)
    }
}

// MARK: - 记录行

struct EntryRow: View {
    let entry: JointEntry
    @ScaledMetric(relativeTo: .body) private var thumbSize: CGFloat = 50

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(EntryStore.displayPart(entry.bodyPart))
                    .font(Theme.serif(17))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                Text(metaLine)
                    .font(Theme.ui(10.5, .medium))
                    .foregroundColor(Theme.ink2)
                    .lineLimit(1)
                if !noteLine.isEmpty {
                    Text(noteLine)
                        .font(Theme.ui(10.5))
                        .foregroundColor(Theme.ink3)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            Text(Theme.severityShortLabel(entry.severity))
                .font(.system(size: 8.5, weight: .heavy))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.severityColor(entry.severity)))
                .padding(.top, 3)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var thumbnail: some View {
        let files = entry.photoFiles ?? []
        if let first = files.first,
           let img = UIImage(contentsOfFile: EntryStore.photoURL(first).path) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: thumbSize, height: thumbSize)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.hair, lineWidth: 1))
        } else {
            RoundedRectangle(cornerRadius: 11)
                .fill(Theme.paper)
                .frame(width: thumbSize, height: thumbSize)
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(Theme.hair, style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                )
                .overlay(
                    Image(systemName: "camera")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.ink3)
                )
        }
    }

    private var metaLine: String {
        var parts: [String] = []
        parts.append(entry.date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
        if !entry.painDurationLabel.isEmpty { parts.append(entry.painDurationLabel.lowercased()) }
        if !entry.treatmentLabel.isEmpty { parts.append(entry.treatmentLabel) }
        return parts.joined(separator: " · ")
    }

    private var noteLine: String {
        if !entry.notes.isEmpty { return entry.notes }
        if entry.quick { return L("Draft — tap to finish the details.") }
        return ""
    }

    private var accessibilityText: String {
        var parts = [EntryStore.displayPart(entry.bodyPart), Theme.severityLabel(entry.severity)]
        parts.append(entry.date.formatted(.dateTime.month(.wide).day().hour().minute()))
        if !entry.notes.isEmpty { parts.append(entry.notes) }
        return parts.joined(separator: ", ")
    }
}
