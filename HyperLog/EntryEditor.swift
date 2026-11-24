import SwiftUI
import Foundation
import PhotosUI

// MARK: - 条目编辑
// 旧版：8 个 Section + 部位 10 行 inline picker + 4 段 segmented 里塞 31 字符长文案
// （在 iPhone 上必然截断成 "Severe (s…"），一次记录要滚 4-5 屏。
// 现在：部位 chips + 严重度四段常驻首屏，其余细节折叠成「带当前值」的入口，点击展开子页。

struct EntryEditor: View {

    /// nil = 新建；有值 = 编辑/补细节
    var editing: JointEntry?
    var onSave: (JointEntry?) -> Void

    @State private var bodyPart: String = "knee"
    @State private var customPart: String = ""
    @State private var severity: Int = 1
    @State private var painDuration: String? = "minutes"
    @State private var treatment: String? = "none"
    @State private var triggers: Set<String> = []
    @State private var notes: String = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var newImages: [UIImage] = []
    @State private var keepFiles: [String] = []
    @State private var showCamera = false
    @State private var beightonChecks: [Bool] = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

    private var beightonScore: Int { beightonChecks.filter { $0 }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    areaCard
                    severityCard
                    detailsCard
                    photoCard
                    beightonCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 34)
            }
            .background(Theme.paper)
            .navigationTitle(L(editing == nil ? "New entry" : "Edit entry"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onSave(nil) }
                        .foregroundColor(Theme.ink2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.accent)
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

    // MARK: 部位

    private var areaCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardLabel("AREA")
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(EntryStore.bodyParts, id: \.key) { item in
                    areaChip(item.key, item.label)
                }
            }
            if bodyPart == "other" {
                TextField("Type the area (e.g. rib, toe, TMJ…)", text: $customPart)
                    .font(Theme.ui(12))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8).stroke(Theme.hair, lineWidth: 1)
                    )
                    .padding(.top, 2)
            }
        }
        .paperCard()
    }

    private func areaChip(_ key: String, _ text: String) -> some View {
        let selected = bodyPart == key
        return Button {
            bodyPart = key
        } label: {
            Text(text)
                .font(Theme.ui(10.5, selected ? .semibold : .medium))
                .foregroundColor(selected ? .white : Theme.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8).fill(selected ? Theme.accent : Theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? Theme.accent : Theme.hair, lineWidth: 1.2)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: 严重度

    private var severityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardLabel("HOW MUCH")
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { level in
                    Button {
                        severity = level
                    } label: {
                        Text(Theme.severityLabel(level))
                            .font(Theme.ui(11, .semibold))
                            .foregroundColor(severity == level ? .white : Theme.ink2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(severity == level ? Theme.severityColor(level) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hair, lineWidth: 1.2))

            Text("Severe = it slipped out or dislocated.")
                .font(Theme.ui(10))
                .foregroundColor(Theme.ink3)
        }
        .paperCard()
    }

    // MARK: 细节

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardLabel("DETAILS")
            durationRow
            divider
            treatmentRow
            divider
            triggersRow
            divider
            notesRow
        }
        .paperCard()
    }

    private var durationRow: some View {
        Menu {
            ForEach(EntryStore.painDurationOptions, id: \.key) { opt in
                Button(opt.label) { painDuration = opt.key }
            }
        } label: {
            valueRow("Pain duration", durationLabel)
        }
    }

    private var treatmentRow: some View {
        Menu {
            ForEach(EntryStore.treatmentOptions, id: \.key) { opt in
                Button(opt.label) { treatment = opt.key }
            }
        } label: {
            valueRow("Treatment", treatmentLabel)
        }
    }

    private var triggersRow: some View {
        NavigationLink {
            TriggerPickerView(selection: $triggers)
        } label: {
            valueRow("Triggers", triggersLabel)
        }
        .buttonStyle(.plain)
    }

    private var notesRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes")
                .font(Theme.ui(12.5))
                .foregroundColor(Theme.ink)
            TextField("What happened, how it feels, what you were doing…", text: $notes, axis: .vertical)
                .font(Theme.ui(12))
                .lineLimit(2...6)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.hair, lineWidth: 1))
        }
        .padding(.vertical, 11)
    }

    private func valueRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(Theme.ui(12.5))
                .foregroundColor(Theme.ink)
            Spacer(minLength: 8)
            Text(value)
                .font(Theme.ui(11.5, .medium))
                .foregroundColor(Theme.ink2)
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.ink3)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.hair)
            .frame(height: 1)
    }

    // MARK: 照片

    private var photoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardLabel("PHOTOS")
            HStack(spacing: 8) {
                Button {
                    showCamera = true
                } label: {
                    pillLabel("Camera", "camera.fill")
                }
                .buttonStyle(.plain)
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 9, matching: .images) {
                    pillLabel("Library", "photo.on.rectangle")
                }
                .buttonStyle(.plain)
            }
            photoGrid
        }
        .paperCard()
    }

    private func pillLabel(_ text: String, _ icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(Theme.ui(12, .semibold))
        }
        .foregroundColor(Theme.accent)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Capsule().fill(Theme.paper))
        .overlay(Capsule().stroke(Theme.hair, lineWidth: 1.2))
    }

    @ViewBuilder
    private var photoGrid: some View {
        let total = keepFiles.count + newImages.count
        if total > 0 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(keepFiles.enumerated()), id: \.offset) { index, file in
                        ZStack(alignment: .topTrailing) {
                            if let img = UIImage(contentsOfFile: EntryStore.photoURL(file).path) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                            }
                            removeButton { keepFiles.remove(at: index) }
                        }
                    }
                    ForEach(Array(newImages.enumerated()), id: \.offset) { index, img in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            removeButton { newImages.remove(at: index) }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 84)
        }
    }

    private func removeButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 13))
                .foregroundColor(.white)
                .background(Circle().fill(Color.black.opacity(0.55)))
        }
        .buttonStyle(.plain)
        .padding(3)
    }

    // MARK: Beighton

    private var beightonCard: some View {
        NavigationLink {
            BeightonEditorView(checks: $beightonChecks)
        } label: {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Beighton self-check")
                        .font(Theme.ui(12.5))
                        .foregroundColor(Theme.ink)
                    Text("Optional · saved with this entry")
                        .font(Theme.ui(10))
                        .foregroundColor(Theme.ink3)
                }
                Spacer(minLength: 8)
                Text("\(beightonScore) / 9")
                    .font(Theme.serif(15))
                    .foregroundColor(Theme.accent)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.ink3)
            }
            .padding(14)
            .contentShape(Rectangle())
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hair, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: 小件

    private func cardLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(Theme.mono(9))
            .foregroundColor(Theme.ink3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 2)
    }

    // MARK: 标签

    private var durationLabel: String {
        EntryStore.painDurationOptions.first(where: { $0.key == painDuration })?.label ?? "—"
    }
    private var treatmentLabel: String {
        EntryStore.treatmentOptions.first(where: { $0.key == treatment })?.label ?? "—"
    }
    private var triggersLabel: String {
        if triggers.isEmpty { return "None" }
        if triggers.contains("none") { return "Not sure" }
        let order = EntryStore.triggerOptions.map { $0.key }
        let labels = order.compactMap { key -> String? in
            guard triggers.contains(key) else { return nil }
            return EntryStore.triggerOptions.first(where: { $0.key == key })?.label
        }
        return labels.isEmpty ? "None" : labels.joined(separator: ", ")
    }

    // MARK: 存取

    private func save() {
        let id = editing?.id ?? UUID()

        // 编辑时被移除的旧照片文件清理（防磁盘泄漏）
        if let old = editing {
            let oldFiles = old.photoFiles ?? []
            for file in oldFiles where !keepFiles.contains(file) {
                try? FileManager.default.removeItem(at: EntryStore.photoDir.appendingPathComponent(file))
            }
        }

        var files = keepFiles
        for (index, img) in newImages.enumerated() {
            if let name = EntryStore.savePhoto(img, for: id, index: keepFiles.count + index) {
                files.append(name)
            }
        }

        let anyChecked = beightonChecks.contains { $0 }
        let partToSave = (bodyPart == "other" && !customPart.trimmingCharacters(in: .whitespaces).isEmpty)
            ? "other:" + customPart.trimmingCharacters(in: .whitespaces)
            : bodyPart

        let entry = JointEntry(
            id: id,
            date: editing?.date ?? Date(),
            bodyPart: partToSave,
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
        if e.bodyPart.hasPrefix("other:") {
            bodyPart = "other"
            customPart = String(e.bodyPart.dropFirst("other:".count))
        } else {
            bodyPart = e.bodyPart
        }
        severity = e.severity
        painDuration = e.painDuration ?? "minutes"
        treatment = e.treatment ?? "none"
        triggers = Set(e.triggers)
        notes = e.notes
        keepFiles = e.photoFiles ?? []
        if let score = e.beighton {
            var checks = Array(repeating: false, count: 9)
            for i in 0..<min(score, 9) { checks[i] = true }
            beightonChecks = checks
        }
    }
}

// MARK: - 诱因多选

struct TriggerPickerView: View {
    @Binding var selection: Set<String>

    var body: some View {
        List {
            Section {
                ForEach(EntryStore.triggerOptions, id: \.key) { opt in
                    Toggle(isOn: binding(opt.key)) {
                        Text(opt.label)
                            .font(Theme.ui(14))
                    }
                    .tint(Theme.accent)
                }
            } footer: {
                Text("“Not sure” clears the others.")
                    .font(Theme.ui(11))
            }
        }
        .navigationTitle("Triggers")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func binding(_ key: String) -> Binding<Bool> {
        Binding(
            get: { selection.contains(key) },
            set: { on in
                if on {
                    if key == "none" {
                        selection = ["none"]
                    } else {
                        selection.remove("none")
                        selection.insert(key)
                    }
                } else {
                    selection.remove(key)
                }
            }
        )
    }
}

// MARK: - Beighton 九项

struct BeightonEditorView: View {
    @Binding var checks: [Bool]

    private var score: Int { checks.filter { $0 }.count }

    var body: some View {
        List {
            Section {
                ForEach(Array(BeightonItems.all.enumerated()), id: \.offset) { index, item in
                    Toggle(isOn: binding(index)) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(Theme.ui(13.5))
                            Text(item.how)
                                .font(Theme.ui(10.5))
                                .foregroundColor(Theme.ink3)
                        }
                    }
                    .tint(Theme.accent)
                }
            } footer: {
                Text("Used by clinicians as a 9-point screen for generalised joint hypermobility. This is a self-check, not a diagnosis.")
                    .font(Theme.ui(11))
            }
        }
        .navigationTitle(L("Beighton · %@/9", "\(score)"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func binding(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { checks.indices.contains(index) && checks[index] },
            set: { on in
                while checks.count < 9 { checks.append(false) }
                if checks.indices.contains(index) { checks[index] = on }
            }
        )
    }
}

