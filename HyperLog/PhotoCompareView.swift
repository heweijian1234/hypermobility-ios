import SwiftUI

// MARK: - 照片对比
// 旧版是单列 240pt 大图垂直堆叠，要判断「肿有没有消」得来回滚动记忆比对。
// 现在：THEN / NOW 两张固定并排，点下方胶片条换图，中间标出相隔天数。

struct PhotoItem: Identifiable {
    let id: String        // 文件名，天然唯一
    let entryID: UUID
    let file: String
    let date: Date
    let severity: Int
}

struct PhotoCompareView: View {
    @State private var entries: [JointEntry] = EntryStore.load()
    @State private var part = ""
    @State private var slot = 1        // 0 = THEN, 1 = NOW
    @State private var thenID: String?
    @State private var nowID: String?

    private var partsWithPhotos: [(key: String, label: String)] {
        let keys = Set(entries.filter { !($0.photoFiles ?? []).isEmpty }.map { $0.bodyPart })
        return EntryStore.bodyParts.filter { keys.contains($0.key) }.map { (key: $0.key, label: $0.label) }
    }

    private var items: [PhotoItem] {
        var result: [PhotoItem] = []
        for entry in entries where entry.bodyPart == part {
            for file in (entry.photoFiles ?? []) {
                result.append(PhotoItem(id: file, entryID: entry.id, file: file, date: entry.date, severity: entry.severity))
            }
        }
        return result.sorted { $0.date < $1.date }
    }

    private var thenItem: PhotoItem? {
        items.first(where: { $0.file == thenID }) ?? items.first
    }
    private var nowItem: PhotoItem? {
        items.first(where: { $0.file == nowID }) ?? items.last
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if partsWithPhotos.isEmpty {
                    emptyState
                } else {
                    areaChips
                    pairSection
                    slotPicker
                    filmstrip
                    caption
                }
            }
            .padding(.bottom, 30)
        }
        .background(Theme.paper)
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            if part.isEmpty { part = partsWithPhotos.first?.key ?? "knee" }
        }
    }

    // MARK: 头

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("CHANGE OVER TIME")
                .font(Theme.mono(9.5))
                .foregroundColor(Theme.ink3)
            Text("Photo compare")
                .font(Theme.serif(28))
                .foregroundColor(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var areaChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(partsWithPhotos, id: \.key) { item in
                    let selected = part == item.key
                    Button {
                        part = item.key
                        thenID = nil
                        nowID = nil
                    } label: {
                        Text(item.label)
                            .font(Theme.ui(11.5, selected ? .semibold : .medium))
                            .foregroundColor(selected ? .white : Theme.ink2)
                            .padding(.horizontal, 13)
                            .frame(height: 32)
                            .background(Capsule().fill(selected ? Theme.accent : Theme.surface))
                            .overlay(Capsule().stroke(selected ? Theme.accent : Theme.hair, lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 14)
    }

    // MARK: 并排

    private var pairSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                photoCell(thenItem, label: "THEN")
                photoCell(nowItem, label: "NOW")
            }
            Text(gapText)
                .font(Theme.mono(9.5))
                .foregroundColor(Theme.ink3)
        }
        .padding(.horizontal, 18)
    }

    private func photoCell(_ item: PhotoItem?, label: LocalizedStringKey) -> some View {
        ZStack(alignment: .topLeading) {
            Theme.paper
            if let item,
               let img = UIImage(contentsOfFile: EntryStore.photoURL(item.file).path) {
                GeometryReader { geo in
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.ink3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Text(label)
                .font(Theme.mono(8.5, .bold))
                .foregroundColor(Theme.ink)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Theme.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 4))
                .padding(7)

            if let item {
                VStack {
                    Spacer()
                    HStack {
                        Text(item.date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(Theme.ui(10, .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                        Spacer()
                    }
                }
                .padding(8)
            }
        }
        .frame(height: 196)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hair, lineWidth: 1))
    }

    private var gapText: String {
        guard let a = thenItem, let b = nowItem else { return L("TAP A PHOTO BELOW") }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: a.date),
                                                   to: Calendar.current.startOfDay(for: b.date)).day ?? 0
        if days == 0 { return L("SAME DAY · TAP EITHER TO SWAP") }
        return L("%@ DAYS APART · TAP A PHOTO BELOW", "\(days)")
    }

    // MARK: 换图

    private var slotPicker: some View {
        HStack(spacing: 4) {
            Text("FILLING")
                .font(Theme.mono(9))
                .foregroundColor(Theme.ink3)
            Spacer()
            slotButton("THEN", 0)
            slotButton("NOW", 1)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    private func slotButton(_ text: LocalizedStringKey, _ tag: Int) -> some View {
        let selected = slot == tag
        return Button {
            slot = tag
        } label: {
            Text(text)
                .font(Theme.mono(9, .bold))
                .foregroundColor(selected ? .white : Theme.ink2)
                .padding(.horizontal, 11)
                .frame(height: 26)
                .background(Capsule().fill(selected ? Theme.accent : Theme.surface))
                .overlay(Capsule().stroke(selected ? Theme.accent : Theme.hair, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var filmstrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items) { item in
                    let isThen = item.file == thenItem?.file
                    let isNow = item.file == nowItem?.file
                    Button {
                        if slot == 0 { thenID = item.file } else { nowID = item.file }
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            if let img = UIImage(contentsOfFile: EntryStore.photoURL(item.file).path) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipped()
                            } else {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Theme.surface)
                                    .frame(width: 56, height: 56)
                            }
                            Circle()
                                .fill(Theme.severityColor(item.severity))
                                .frame(width: 6, height: 6)
                                .padding(4)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(isThen || isNow ? Theme.accent : Theme.hair, lineWidth: isThen || isNow ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 2)
        }
        .padding(.top, 12)
    }

    private var caption: some View {
        Text("Same joint, same distance. Tap a thumbnail to load it into the selected side.")
            .font(Theme.ui(10.5))
            .foregroundColor(Theme.ink2)
            .lineSpacing(2)
            .padding(.horizontal, 18)
            .padding(.top, 12)
    }

    // MARK: 空

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No photos yet")
                .font(Theme.serif(20))
                .foregroundColor(Theme.ink)
            Text("Attach photos to an entry when you log a flare — they will line up here so you can see swelling change side by side.")
                .font(Theme.ui(12.5))
                .foregroundColor(Theme.ink2)
                .lineSpacing(3)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }
}
