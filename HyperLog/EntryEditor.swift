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
                Section("Which joint / area?") {
                    Picker("Area", selection: $bodyPart) {
                        ForEach(EntryStore.bodyParts, id: \.key) { part in
                            Text(part.label).tag(part.key)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("How significant?") {
                    Picker("Severity", selection: $severity) {
                        Text("Mild").tag(0)
                        Text("Moderate").tag(1)
                        Text("Significant").tag(2)
                        Text("Severe (subluxation/dislocation)").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Notes") {
                    TextField("What happened, how it feels, what you were doing…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Photo (optional)") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(photoImage == nil ? "Choose from library" : "Replace photo", systemImage: "photo.on.rectangle")
                    }
                    if let img = photoImage {
                        Image(uiImage: img)
                            .resizable().scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .navigationTitle("New entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onSave(nil) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
            .onChange(of: photoItem) { _, item in
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
