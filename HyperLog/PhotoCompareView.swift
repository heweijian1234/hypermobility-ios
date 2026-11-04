import SwiftUI

// MARK: - 同部位照片并排对比（P2-8：肿胀变化肉眼可见——照片已在存，缺对比视图）
struct PhotoCompareView: View {
    @State private var entries: [JointEntry] = EntryStore.load()
    @State private var part = "knee"

    private var photoEntries: [JointEntry] {
        entries.filter { $0.bodyPart == part && $0.photoFile != nil }
    }

    private var partsWithPhotos: [String] {
        let set = Set(entries.filter { $0.photoFile != nil }.map(\.bodyPart))
        return EntryStore.bodyParts.filter { set.contains($0.key) }.map(\.key)
    }

    var body: some View {
        List {
            if partsWithPhotos.isEmpty {
                Text("还没有带照片的记录——记条目时附上照片，这里就能按部位并排对比变化。")
                    .foregroundColor(.secondary)
            } else {
                Section("部位") {
                    Picker("部位", selection: $part) {
                        ForEach(partsWithPhotos, id: \.self) { key in
                            Text(EntryStore.bodyParts.first(where: { $0.key == key })?.label ?? key).tag(key)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("时间序（旧→新，往下翻）") {
                    ForEach(photoEntries.reversed()) { e in
                        if let file = e.photoFile,
                           let img = UIImage(contentsOfFile: EntryStore.photoURL(file).path) {
                            VStack(alignment: .leading, spacing: 4) {
                                Image(uiImage: img)
                                    .resizable().scaledToFit()
                                    .frame(maxHeight: 260)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                HStack {
                                    Text(e.date.formatted(.dateTime.year().month().day()))
                                        .font(.caption.bold())
                                    Text(e.severityLabel)
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("照片对比")
        .navigationBarTitleDisplayMode(.inline)
    }
}
