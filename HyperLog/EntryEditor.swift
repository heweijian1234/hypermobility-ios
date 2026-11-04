import SwiftUI
import PhotosUI

// MARK: - 条目编辑：新建/补细节/编辑（部位/程度/疼痛持续/处置/诱因/备注/照片）
struct EntryEditor: View {
    /// nil=新建；有值=编辑这条（一键快记的"补细节"就是编辑模式）
    var editing: JointEntry?
    var onSave: (JointEntry?) -> Void

    @State private var bodyPart: String = "knee"
    @State private var severity = 1
    @State private var painDuration: String?
    @State private var treatment: String?
    @State private var triggers: Set<String> = []
    @State private var notes = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoImage: UIImage?
    @State private var keepPhotoFile: String?

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
                Section("疼了多久？") {
                    Picker("疼痛持续时间", selection: Binding(
                        get: { painDuration ?? "minutes" },
                        set: { painDuration = $0 }
                    )) {
                        ForEach(EntryStore.painDurationOptions, id: \.key) { opt in
                            Text(opt.label).tag(opt.key)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("怎么处理的？") {
                    Picker("处置", selection: Binding(
                        get: { treatment ?? "none" },
                        set: { treatment = $0 }
                    )) {
                        ForEach(EntryStore.treatmentOptions, id: \.key) { opt in
                            Text(opt.label).tag(opt.key)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("发作前在干什么？（诱因）") {
                    ForEach(EntryStore.triggerOptions, id: \.key) { opt in
                        Toggle(opt.label, isOn: Binding(
                            get: { triggers.contains(opt.key) },
                            set: { on in
                                if on { triggers.insert(opt.key) } else { triggers.remove(opt.key) }
                                if opt.key != "none" { triggers.remove("none") }
                                if opt.key == "none" { triggers.removeAll(); triggers.insert("none") }
                            }
                        ))
                    }
                }
                Section("备注") {
                    TextField("什么情况、什么感觉、当时在干什么……", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("照片（选填）") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(photoImage == nil && keepPhotoFile == nil ? "从相册选择" : "换一张", systemImage: "photo.on.rectangle")
                    }
                    if let img = photoImage {
                        Image(uiImage: img)
                            .resizable().scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else if let file = keepPhotoFile,
                              let img = UIImage(contentsOfFile: EntryStore.photoURL(file).path) {
                        Image(uiImage: img)
                            .resizable().scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .navigationTitle(editing == nil ? "新记录" : "补充/编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onSave(nil) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let id = editing?.id ?? UUID()
                        var file = keepPhotoFile
                        if let img = photoImage {
                            file = EntryStore.savePhoto(img, for: id)
                        }
                        let entry = JointEntry(
                            id: id,
                            date: editing?.date ?? Date(),
                            bodyPart: bodyPart,
                            severity: severity,
                            notes: notes,
                            photoFile: file,
                            painDuration: painDuration ?? "minutes",
                            treatment: treatment ?? "none",
                            triggers: Array(triggers),
                            quick: false   // 补完细节不再是快记
                        )
                        onSave(entry)
                    }
                }
            }
            .onAppear(perform: loadExisting)
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

    private func loadExisting() {
        guard let e = editing else { return }
        bodyPart = e.bodyPart
        severity = e.severity
        painDuration = e.painDuration
        treatment = e.treatment
        triggers = Set(e.triggers)
        notes = e.notes
        keepPhotoFile = e.photoFile
    }
}
