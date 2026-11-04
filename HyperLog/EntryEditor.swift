import SwiftUI
import PhotosUI

// MARK: - 条目编辑：新建/补细节/编辑（部位/程度/疼痛持续/处置/诱因/备注/多张照片/Beighton）
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
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var newImages: [UIImage] = []      // 本次新选/新拍的
    @State private var keepFiles: [String] = []       // 保留的已有文件
    @State private var showCamera = false
    @State private var beightonChecks: [Bool] = []

    private var beightonScore: Int { beightonChecks.filter { $0 }.count }

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
                        .lineLimit(6...12)
                }
                Section("照片（可多张）") {
                    HStack(spacing: 24) {
                        Button {
                            showCamera = true
                        } label: {
                            Label("拍照", systemImage: "camera.fill")
                        }
                        PhotosPicker(selection: $pickerItems, maxSelectionCount: 9, matching: .images) {
                            Label("相册（可多选）", systemImage: "photo.on.rectangle")
                        }
                    }
                    .buttonStyle(.borderless)
                    photoGrid
                }
                Section("Beighton 自评（选填，随本条保存）") {
                    ForEach(Array(BeightonItems.all.enumerated()), id: \.offset) { i, item in
                        Toggle(isOn: Binding(
                            get: { beightonChecks.indices.contains(i) && beightonChecks[i] },
                            set: { on in
                                while beightonChecks.count < 9 { beightonChecks.append(false) }
                                beightonChecks[i] = on
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title).font(.caption)
                                Text(item.how).font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                    HStack {
                        Text("自评分").font(.subheadline)
                        Spacer()
                        Text("\(beightonScore) / 9").bold().foregroundColor(.purple)
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
                    Button("保存") { save() }
                }
            }
            .onAppear(perform: loadExisting)
            .sheet(isPresented: $showCamera) {
                CameraPicker(image: Binding(
                    get: { nil },
                    set: { if let img = $0 { newImages.append(img) } }
                ))
            }
            .onChange(of: pickerItems) { items in
                guard !items.isEmpty else { return }
                Task {
                    var imgs: [UIImage] = []
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            imgs.append(img)
                        }
                    }
                    newImages.append(contentsOf: imgs)
                    pickerItems = []
                }
            }
        }
    }

    /// 已有照片（文件）+ 新选（内存）混排；右上小×删除
    @ViewBuilder
    private var photoGrid: some View {
        let total = keepFiles.count + newImages.count
        if total > 0 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(keepFiles.enumerated()), id: \.offset) { i, file in
                        ZStack(alignment: .topTrailing) {
                            if let img = UIImage(contentsOfFile: EntryStore.photoURL(file).path) {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            removeButton { keepFiles.remove(at: i) }
                        }
                    }
                    ForEach(Array(newImages.enumerated()), id: \.offset) { i, img in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            removeButton { newImages.remove(at: i) }
                        }
                    }
                }
            }
            .frame(height: 84)
        }
    }

    private func removeButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(.white)
                .background(Circle().fill(Color.black.opacity(0.55)))
        }
        .padding(3)
    }

    private func save() {
        let id = editing?.id ?? UUID()
        var files = keepFiles
        for (i, img) in newImages.enumerated() {
            if let name = EntryStore.savePhoto(img, for: id, index: files.count + i) {
                files.append(name)
            }
        }
        let anyChecked = beightonChecks.contains { $0 }
        let entry = JointEntry(
            id: id,
            date: editing?.date ?? Date(),
            bodyPart: bodyPart,
            severity: severity,
            notes: notes,
            photoFile: nil,
            photoFiles: files.isEmpty ? nil : files,
            painDuration: painDuration ?? "minutes",
            treatment: treatment ?? "none",
            triggers: Array(triggers),
            quick: false,
            beighton: anyChecked ? beightonScore : nil
        )
        onSave(entry)
    }

    private func loadExisting() {
        guard let e = editing else { return }
        bodyPart = e.bodyPart
        severity = e.severity
        painDuration = e.painDuration
        treatment = e.treatment
        triggers = Set(e.triggers)
        notes = e.notes
        keepFiles = e.photoFiles ?? []
        if let b = e.beighton {
            var checks = Array(repeating: false, count: 9)
            for i in 0..<min(b, 9) { checks[i] = true }
            beightonChecks = checks
        }
    }
}
