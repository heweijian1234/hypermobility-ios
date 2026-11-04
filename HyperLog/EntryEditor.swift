import SwiftUI
import PhotosUI

// MARK: - 新增条目：部位/严重度/文字/照片（相册选取，存本地沙盒）
struct EntryEditor: View {
    var onSave: (JointEntry?) -> Void

    @State private var bodyPart = "knee"
    @State private var severity = 1
    @State private var notes = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoImage: UIImage?

    var body: some View {
        NavigationStack {
            Form {
                Section("哪个关节/部位？") {
                    Picker("部位", selection: $bodyPart) {
                        ForEach(EntryStore.bodyParts, id: \.key) { part in
                            Text(part.label).tag(part.key)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("程度如何？") {
                    Picker("程度", selection: $severity) {
                        Text("轻微").tag(0)
                        Text("中等").tag(1)
                        Text("明显").tag(2)
                        Text("严重（半脱位/脱位）").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
                Section("备注") {
                    TextField("什么情况、什么感觉、当时在干什么……", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("照片（选填）") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(photoImage == nil ? "从相册选择" : "换一张", systemImage: "photo.on.rectangle")
                    }
                    if let img = photoImage {
                        Image(uiImage: img)
                            .resizable().scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .navigationTitle("新记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onSave(nil) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let id = UUID()
                        var file: String?
                        if let img = photoImage {
                            file = EntryStore.savePhoto(img, for: id)
                        }
                        let entry = JointEntry(id: id, date: Date(), bodyPart: bodyPart,
                                               severity: severity, notes: notes, photoFile: file)
                        onSave(entry)
                    }
                }
            }
            .onChange(of: photoItem) { item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        photoImage = img
                    }
                }
            }
        }
    }
}
