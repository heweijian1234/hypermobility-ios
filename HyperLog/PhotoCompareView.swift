import SwiftUI

// MARK: - 同Area照片并排对比（P2-8：肿胀变化肉眼可见——照片已在存，缺对比视图）
struct PhotoCompareView: View {
    @State private var entries: [JointEntry] = EntryStore.load()
    @State private var part = "knee"

    private var photoEntries: [JointEntry] {
        entries.filter { $0.bodyPart == part && !($0.photoFiles ?? []).isEmpty }
    }

    private var partsWithPhotos: [String] {
        let set = Set(entries.filter { !($0.photoFiles ?? []).isEmpty }.map(\.bodyPart))
        return EntryStore.bodyParts.filter { set.contains($0.key) }.map(\.key)
    }

    var body: some View {
        List {
            if partsWithPhotos.isEmpty {
                Text("No entries with photos yet — attach photos to entries to compare changes side by side here.")
                    .foregroundColor(.secondary)
            } else {
                Section("Area") {
                    Picker("Area", selection: $part) {
                        ForEach(partsWithPhotos, id: \.self) { key in
                            Text(EntryStore.bodyParts.first(where: { $0.key == key })?.label ?? key).tag(key)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Chronological (oldest first)") {
                    ForEach(photoEntries.reversed()) { e in
                        let files = e.photoFiles ?? []
                        if !files.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(files.enumerated()), id: \.offset) { _, file in
                                            if let img = UIImage(contentsOfFile: EntryStore.photoURL(file).path) {
                                                Image(uiImage: img)
                                                    .resizable().scaledToFit()
                                                    .frame(height: 240)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                            }
                                        }
                                    }
                                }
                                HStack {
                                    Text(e.date.formatted(.dateTime.year().month().day()))
                                        .font(.caption.bold())
                                    Text(e.severityLabel)
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    if files.count > 1 {
                                        Text("\(files.count) photos").font(.caption2).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("Photo Compare")
        .navigationBarTitleDisplayMode(.inline)
    }
}
