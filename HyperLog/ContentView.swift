import SwiftUI
import PhotosUI

// MARK: - 主页：一键快记 + 时间线/分组 + 报告/自评/照片对比入口
// 快记逻辑（P0-1）：发作时手在疼——一键落下记录（默认上次部位），疼过再补细节
struct ContentView: View {
    @State private var entries: [JointEntry] = EntryStore.load()
    @State private var grouping = false
    @State private var editingEntry: JointEntry?   // 补细节/编辑目标
    @State private var showEditor = false
    @State private var newFromQuick = false

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyView
                } else if grouping {
                    groupedList
                } else {
                    timelineList
                }
            }
            .navigationTitle("HyperLog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink { AboutView() } label: { Image(systemName: "info.circle") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        grouping.toggle()
                    } label: {
                        Image(systemName: grouping ? "list.bullet" : "square.grid.2x2")
                    }
                }
            }
            .overlay(alignment: .bottomLeading) {
                // 一键快记（发作时的救命键——单手大目标）
                Button {
                    quickLog()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "bolt.fill").font(.title3.bold())
                        Text("快记").font(.caption2.bold())
                    }
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Color.purple))
                }
                .padding(.leading, 16)
                .padding(.bottom, 16)
            }
            .overlay(alignment: .bottomTrailing) {
                Menu {
                    Button { newFromQuick = false; showEditor = true } label: {
                        Label("详细记录", systemImage: "square.and.pencil")
                    }
                    NavigationLink { BeightonView() } label: {
                        Label("Beighton 自评", systemImage: "checklist")
                    }
                    NavigationLink { DoctorReportView() } label: {
                        Label("医生报告", systemImage: "stethoscope")
                    }
                    NavigationLink { PhotoCompareView() } label: {
                        Label("照片对比", systemImage: "photo.on.rectangle.angled")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color(red: 0.55, green: 0.45, blue: 0.75)))
                }
                .padding(20)
            }
            .sheet(isPresented: $showEditor, onDismiss: { entries = EntryStore.load() }) {
                EntryEditor(editing: editingEntry) { new in
                    if let new {
                        if let idx = entries.firstIndex(where: { $0.id == new.id }) {
                            entries[idx] = new
                        } else {
                            entries.insert(new, at: 0)
                        }
                        EntryStore.save(entries)
                    }
                    showEditor = false
                }
            }
        }
    }

    /// 一键快记：上次部位+当前时间+quick 标记，落库即走
    private func quickLog() {
        let lastPart = entries.first?.bodyPart ?? "knee"
        let entry = JointEntry(id: UUID(), date: Date(), bodyPart: lastPart,
                               severity: 2, notes: "", photoFile: nil,
                               painDuration: nil, treatment: nil, triggers: [], quick: true)
        entries.insert(entry, at: 0)
        EntryStore.save(entries)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "figure.yoga")
                .font(.system(size: 52))
                .foregroundColor(.purple)
            Text("记录你的关节")
                .font(.headline)
            Text("发作时点左下角「快记」一键落下，疼过再补细节；平时从右下角详细记录。")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var timelineList: some View {
        List(entries) { entry in
            Button {
                editingEntry = entry
                showEditor = true
            } label: {
                EntryRow(entry: entry)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }

    private var groupedList: some View {
        List {
            ForEach(EntryStore.grouped(entries), id: \.part) { group in
                Section("\(group.label) · \(group.count)") {
                    ForEach(group.items) { e in
                        Button {
                            editingEntry = e
                            showEditor = true
                        } label: { EntryRow(entry: e) }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct EntryRow: View {
    let entry: JointEntry
    var body: some View {
        HStack(spacing: 12) {
            if let file = entry.photoFile,
               let img = UIImage(contentsOfFile: EntryStore.photoURL(file).path) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 52, height: 52)
                    .overlay(Image(systemName: "camera").foregroundColor(.purple))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(partLabel).font(.subheadline.weight(.semibold))
                    if entry.quick {
                        Text("待补").font(.caption2.bold())
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2), in: Capsule())
                            .foregroundColor(.orange)
                    }
                    Spacer()
                    Text(entry.severityLabel)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(severityColor.opacity(0.18), in: Capsule())
                        .foregroundColor(severityColor)
                }
                HStack(spacing: 8) {
                    if !entry.painDurationLabel.isEmpty {
                        Text("疼\(entry.painDurationLabel)").font(.caption).foregroundColor(.secondary)
                    }
                    if !entry.treatmentLabel.isEmpty {
                        Text(entry.treatmentLabel).font(.caption).foregroundColor(.secondary)
                    }
                }
                if !entry.notes.isEmpty {
                    Text(entry.notes).font(.caption).foregroundColor(.secondary).lineLimit(2)
                }
                Text(entry.date.formatted(.dateTime.month().day().hour().minute()))
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var partLabel: String {
        EntryStore.bodyParts.first(where: { $0.key == entry.bodyPart })?.label ?? entry.bodyPart
    }

    private var severityColor: Color {
        switch entry.severity {
        case 0: return .green
        case 1: return .yellow
        case 2: return .orange
        default: return .red
        }
    }
}
