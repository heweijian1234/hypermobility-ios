import SwiftUI
import PhotosUI

// MARK: - 主页：左下快记 / 中间＋详细记录 / 右下工具（报告分享+照片对比）
// 布局（健哥 11-04 拍板）：＋只管详细记录；自评并入详细记录底部；其余功能右下角
struct ContentView: View {
    @State private var entries: [JointEntry] = EntryStore.load()
    @State private var grouping = false
    @State private var editingEntry: JointEntry?
    @State private var showEditor = false
    @State private var goReport = false
    @State private var goPhotos = false
    @State private var goFeedback = false

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
            // 左下：快记
            .overlay(alignment: .bottomLeading) {
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
            // 中间：＋ 详细记录（新建——editingEntry 必须清空，此前残留=bug"只改旧记录"）
            .overlay(alignment: .bottom) {
                Button {
                    editingEntry = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color(red: 0.55, green: 0.45, blue: 0.75)))
                }
                .padding(.bottom, 12)
            }
            // 右下：三合一工具（健哥 11-04 令：对比/分享/反馈合一个图标展开）
            .overlay(alignment: .bottomTrailing) {
                Menu {
                    Button { goReport = true } label: { Label("报告分享", systemImage: "square.and.arrow.up") }
                    Button { goPhotos = true } label: { Label("照片对比", systemImage: "photo.on.rectangle.angled") }
                    Button { goFeedback = true } label: { Label("意见反馈", systemImage: "paperplane") }
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: "ellipsis").font(.body)
                        Text("更多").font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color(red: 0.55, green: 0.45, blue: 0.75)))
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
            .navigationDestination(isPresented: $goReport) { DoctorReportView() }
            .navigationDestination(isPresented: $goPhotos) { PhotoCompareView() }
            .navigationDestination(isPresented: $goFeedback) { FeedbackView() }
            .sheet(isPresented: $showEditor, onDismiss: {
                entries = EntryStore.load()
                editingEntry = nil
            }) {
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
                               severity: 2, notes: "", photoFile: nil, photoFiles: nil,
                               painDuration: nil, treatment: nil, triggers: [], quick: true, beighton: nil)
        entries.insert(entry, at: 0)
        EntryStore.save(entries)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// 左滑删除（含照片文件清理）
    private func delete(_ entry: JointEntry) {
        for file in entry.photoFiles ?? [] {
            try? FileManager.default.removeItem(at: EntryStore.photoURL(file))
        }
        entries.removeAll { $0.id == entry.id }
        EntryStore.save(entries)
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "figure.yoga")
                .font(.system(size: 52))
                .foregroundColor(.purple)
            Text("记录你的关节")
                .font(.headline)
            Text("发作时点左下角「快记」一键落下，疼过再补细节；平时点中间「＋」详细记录。")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var timelineList: some View {
        List {
            ForEach(entries) { entry in
                Button {
                    editingEntry = entry
                    showEditor = true
                } label: {
                    EntryRow(entry: entry)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        delete(entry)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
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
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                delete(e)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
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
            if let files = entry.photoFiles, !files.isEmpty,
               let img = UIImage(contentsOfFile: EntryStore.photoURL(files[0]).path) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .bottomTrailing) {
                        if files.count > 1 {
                            Text("\(files.count)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(3)
                                .background(Circle().fill(Color.purple))
                        }
                    }
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
