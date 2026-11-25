import SwiftUI

// MARK: - 全部记录（Pro）——按月归档，方便翻看整段病史

struct AllRecordsView: View {

    @State private var entries: [JointEntry] = EntryStore.load()
    @State private var editing: JointEntry?
    @State private var showEditor = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                summary
                ForEach(months, id: \.key) { month in
                    monthHeader(month)
                    ForEach(month.items) { entry in
                        row(entry)
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .background(Theme.paper)
        .navigationTitle(L("All records"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showEditor, onDismiss: { entries = EntryStore.load() }) {
            EntryEditor(editing: editing) { new in
                if let new { save(new) }
                showEditor = false
            }
        }
    }

    // MARK: 概览

    private var summary: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(L("EVERY EPISODE"))
                .font(Theme.mono(9.5))
                .foregroundColor(Theme.ink3)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(entries.count)")
                    .font(Theme.serif(34))
                    .foregroundColor(Theme.ink)
                Text("records")
                    .font(Theme.ui(12))
                    .foregroundColor(Theme.ink2)
                Spacer(minLength: 6)
                Text(rangeText)
                    .font(Theme.mono(9.5))
                    .foregroundColor(Theme.ink3)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    private var rangeText: String {
        guard let oldest = entries.min(by: { $0.date < $1.date }),
              let newest = entries.max(by: { $0.date < $1.date }) else { return "" }
        let a = oldest.date.formatted(.dateTime.year().month(.abbreviated))
        let b = newest.date.formatted(.dateTime.year().month(.abbreviated))
        return a == b ? a : "\(a) — \(b)"
    }

    private func monthHeader(_ month: (key: String, title: String, count: Int, items: [JointEntry])) -> some View {
        HStack {
            Text(month.title.uppercased())
                .font(Theme.mono(9.5))
                .foregroundColor(Theme.ink3)
            Spacer()
            Text("\(month.count)")
                .font(Theme.mono(9.5))
                .foregroundColor(Theme.ink3)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    // MARK: 行

    private func row(_ entry: JointEntry) -> some View {
        Button {
            editing = entry
            showEditor = true
        } label: {
            HStack(spacing: 12) {
                VStack(spacing: 1) {
                    Text(entry.date.formatted(.dateTime.day()))
                        .font(Theme.serif(17))
                        .foregroundColor(Theme.ink)
                    Text(entry.date.formatted(.dateTime.weekday(.narrow)))
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.ink3)
                }
                .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(EntryStore.displayPart(entry.bodyPart))
                        .font(Theme.ui(14, .medium))
                        .foregroundColor(Theme.ink)
                        .lineLimit(1)
                    Text(entry.date.formatted(.dateTime.hour().minute()))
                        .font(Theme.ui(10.5))
                        .foregroundColor(Theme.ink3)
                }

                Spacer(minLength: 6)

                Circle()
                    .fill(Theme.severityColor(entry.severity))
                    .frame(width: 7, height: 7)
                Text(Theme.severityShortLabel(entry.severity))
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundColor(Theme.ink2)
                    .lineLimit(1)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.hair)
                .frame(height: 0.5)
                .padding(.leading, 60)
        }
    }

    // MARK: 数据

    private var months: [(key: String, title: String, count: Int, items: [JointEntry])] {
        let cal = Calendar.current
        var buckets: [String: [JointEntry]] = [:]
        var order: [String] = []
        for entry in entries.sorted(by: { $0.date > $1.date }) {
            let comps = cal.dateComponents([.year, .month], from: entry.date)
            let key = String(format: "%04ld-%02ld", comps.year ?? 0, comps.month ?? 0)
            if buckets[key] == nil {
                order.append(key)
                buckets[key] = []
            }
            buckets[key]?.append(entry)
        }
        return order.map { key in
            let items = buckets[key] ?? []
            let title = items.first.map { $0.date.formatted(.dateTime.year().month(.wide)) } ?? key
            return (key: key, title: title, count: items.count, items: items)
        }
    }

    private func save(_ entry: JointEntry) {
        var list = EntryStore.load()
        if let idx = list.firstIndex(where: { $0.id == entry.id }) {
            list[idx] = entry
        } else {
            list.insert(entry, at: 0)
        }
        EntryStore.save(list)
        entries = EntryStore.load()
    }
}
