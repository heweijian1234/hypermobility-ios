import SwiftUI
import PhotosUI

// MARK: - 主页：时间线+按部位分组 + 新增条目
// 合规：track/log 措辞；照片全本地；无诊断
struct ContentView: View {
    @State private var entries: [JointEntry] = EntryStore.load()
    @State private var showNew = false
    @State private var grouping: Bool = false

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
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showNew = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.purple))
                }
                .padding(20)
            }
            .sheet(isPresented: $showNew, onDismiss: { entries = EntryStore.load() }) {
                EntryEditor { new in
                    if let new {
                        entries.insert(new, at: 0)
                        EntryStore.save(entries)
                    }
                    showNew = false   // 🔴关 sheet——回调里不关 isPresented=按钮"无反应"（GrindSnore 同坑，横向补修）
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "figure.yoga")
                .font(.system(size: 52))
                .foregroundColor(.purple)
            Text("Track your joints")
                .font(.headline)
            Text("Log pain, flexibility, subluxations or dislocations — with a photo and notes. Everything stays on this phone.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var timelineList: some View {
        List(entries) { entry in
            EntryRow(entry: entry)
        }
        .listStyle(.plain)
    }

    private var groupedList: some View {
        List {
            ForEach(EntryStore.grouped(entries), id: \.part) { group in
                Section("\(group.label) · \(group.count)") {
                    ForEach(group.items) { EntryRow(entry: $0) }
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
                    Spacer()
                    Text(entry.severityLabel)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(severityColor.opacity(0.18), in: Capsule())
                        .foregroundColor(severityColor)
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
