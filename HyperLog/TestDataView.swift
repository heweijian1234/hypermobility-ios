import SwiftUI

// MARK: - 测试数据（快速攒数据看图表效果）
// 上架前把 ContentView.showsTestTools 改成 false，入口即从菜单消失（本文件留着不碍事）。

struct TestDataView: View {

    var onChange: () -> Void

    @State private var cursor: Date = Calendar.current.startOfDay(for: Date())
    @State private var total: Int = 0
    @State private var customDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var showClearConfirm = false

    /// 权重偏轻：轻的多、严重的少，看起来更像真实记录
    private let severityPool = [0, 0, 0, 1, 1, 1, 2, 2, 3]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                intro
                counterCard
                addCard
                customCard
                clearCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
        .background(Theme.paper)
        .navigationTitle(L("Test data"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { total = EntryStore.load().count }
        .alert(L("Delete all entries?"), isPresented: $showClearConfirm) {
            Button(L("Cancel"), role: .cancel) { }
            Button(L("Delete"), role: .destructive) { clearAll() }
        } message: {
            Text("This cannot be undone.")
        }
    }

    // MARK: 区块

    private var intro: some View {
        Text("For checking how the charts look. Each tap adds one random entry and moves the date back one day — not for real records.")
            .font(Theme.ui(11.5))
            .foregroundColor(Theme.ink2)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var counterCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("TOTAL ENTRIES")
                .font(Theme.mono(9))
                .foregroundColor(Theme.ink3)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(total)")
                    .font(Theme.serif(34))
                    .foregroundColor(Theme.ink)
                Spacer(minLength: 6)
                Text(L("Next entry: %@", cursor.formatted(.dateTime.month(.abbreviated).day())))
                    .font(Theme.ui(10))
                    .foregroundColor(Theme.ink3)
                    .lineLimit(1)
            }
        }
        .paperCard()
    }

    private var addCard: some View {
        VStack(spacing: 9) {
            Button {
                add(days: 1)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("Add one day")
                        .font(Theme.ui(14, .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent))
            }
            .buttonStyle(.plain)

            Button {
                add(days: 7)
            } label: {
                Text("Add 7 days")
                    .font(Theme.ui(13, .semibold))
                    .foregroundColor(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12).stroke(Theme.hair, lineWidth: 1.4)
                    )
            }
            .buttonStyle(.plain)
        }
        .paperCard()
    }

    private var customCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add on a specific date")
                .font(Theme.ui(12.5))
                .foregroundColor(Theme.ink)
            HStack(spacing: 10) {
                DatePicker("", selection: $customDate, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                Spacer(minLength: 6)
                Button {
                    addOn(customDate)
                } label: {
                    Text("Add")
                        .font(Theme.ui(12, .semibold))
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(Capsule().fill(Theme.surface))
                        .overlay(Capsule().stroke(Theme.hair, lineWidth: 1.2))
                }
                .buttonStyle(.plain)
            }
        }
        .paperCard()
    }

    private var clearCard: some View {
        Button {
            showClearConfirm = true
        } label: {
            Text("Clear all entries")
                .font(Theme.ui(12.5, .semibold))
                .foregroundColor(Theme.severityColor(3))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
        }
        .buttonStyle(.plain)
        .paperCard()
    }

    // MARK: 动作

    private func add(days: Int) {
        var list = EntryStore.load()
        for _ in 0..<days {
            list.append(makeEntry(on: cursor))
            cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        EntryStore.save(list)
        total = list.count
        onChange()
    }

    private func addOn(_ date: Date) {
        var list = EntryStore.load()
        list.append(makeEntry(on: date))
        EntryStore.save(list)
        total = list.count
        onChange()
    }

    private func makeEntry(on day: Date) -> JointEntry {
        let keys = EntryStore.bodyParts.map { $0.key }.filter { $0 != "other" }
        let part = keys.randomElement() ?? "knee"
        let severity = severityPool.randomElement() ?? 1
        let duration = EntryStore.painDurationOptions.randomElement()?.key
        let treatment = EntryStore.treatmentOptions.randomElement()?.key

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: day)
        comps.hour = Int.random(in: 8...21)
        comps.minute = Int.random(in: 0...59)
        let stamp = Calendar.current.date(from: comps) ?? day

        return JointEntry(
            id: UUID(),
            date: min(stamp, Date()),
            bodyPart: part,
            severity: severity,
            notes: "",
            photoFile: nil,
            photoFiles: nil,
            painDuration: duration,
            treatment: treatment,
            triggers: [],
            quick: false,
            beighton: nil
        )
    }

    private func clearAll() {
        for entry in EntryStore.load() {
            EntryStore.deletePhotoFiles(entry)
        }
        EntryStore.save([])
        total = 0
        onChange()
    }
}
