import SwiftUI

// MARK: - 快速记录（半屏确认卡）
// 旧的 Quick Log 直接落库：bodyPart 沿用上一条、severity 写死 2，用户看不到也改不了。
// 现在点击后先给一张确认卡：部位九宫格 + 严重度四段 + 可选备注，两次点击完成；
// 想填更多就点 Add details 进完整表单（预填同一份数据）。

struct QuickCaptureView: View {

    var onSave: (JointEntry) -> Void
    var onDetails: (JointEntry) -> Void

    @State private var part: String
    @State private var severity: Int
    @State private var note: String = ""

    @Environment(\.dismiss) private var dismiss

    init(lastPart: String, lastSeverity: Int,
         onSave: @escaping (JointEntry) -> Void,
         onDetails: @escaping (JointEntry) -> Void) {
        self.onSave = onSave
        self.onDetails = onDetails
        _part = State(initialValue: lastPart)
        _severity = State(initialValue: min(max(lastSeverity, 0), 3))
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What just happened?")
                .font(Theme.serif(23))
                .foregroundColor(Theme.ink)

            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .semibold))
                (Text("Now") + Text(verbatim: " · " + Date().formatted(.dateTime.hour().minute())))
                    .font(Theme.mono(10.5))
            }
            .foregroundColor(Theme.ink2)
            .padding(.top, 4)

            label("AREA")
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(EntryStore.bodyParts, id: \.key) { item in
                    partChip(item.key, item.label)
                }
            }

            label("HOW MUCH")
            severityPicker

            Text("Severe = it slipped out or dislocated.")
                .font(Theme.ui(10))
                .foregroundColor(Theme.ink3)
                .padding(.top, 6)

            label("REASON")
            TextField("Reaching for a box overhead.", text: $note, axis: .vertical)
                .lineLimit(1...2)
                .font(Theme.ui(12))
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.hair, lineWidth: 1.2))

            Spacer(minLength: 12)

            HStack(spacing: 9) {
                Button(action: { submit(false) }) {
                    Text("Save")
                        .font(Theme.ui(14, .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(RoundedRectangle(cornerRadius: 13).fill(Theme.accent))
                }
                Button(action: { submit(true) }) {
                    Text("Add details")
                        .font(Theme.ui(13, .semibold))
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 16)
                        .frame(height: 46)
                        .background(RoundedRectangle(cornerRadius: 13).stroke(Theme.hair, lineWidth: 1.4))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.surface)
    }

    // MARK: 小件

    private func label(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(Theme.mono(9))
            .foregroundColor(Theme.ink3)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }

    private func partChip(_ key: String, _ text: String) -> some View {
        let selected = part == key
        return Button {
            part = key
        } label: {
            Text(text)
                .font(Theme.ui(10.5, selected ? .semibold : .medium))
                .foregroundColor(selected ? .white : Theme.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selected ? Theme.accent : Theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? Theme.accent : Theme.hair, lineWidth: 1.2)
                )
        }
        .buttonStyle(.plain)
    }

    private var severityPicker: some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { level in
                Button {
                    severity = level
                } label: {
                    Text(Theme.severityLabel(level))
                        .font(Theme.ui(11, .semibold))
                        .foregroundColor(severity == level ? .white : Theme.ink2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
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
    }

    // MARK: 提交

    private func submit(_ details: Bool) {
        let entry = JointEntry(
            id: UUID(),
            date: Date(),
            bodyPart: part,
            severity: severity,
            notes: note.trimmingCharacters(in: .whitespacesAndNewlines),
            photoFile: nil,
            photoFiles: nil,
            painDuration: nil,
            treatment: nil,
            triggers: [],
            quick: !details,
            beighton: nil
        )
        if details {
            onDetails(entry)
        } else {
            onSave(entry)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        dismiss()
    }
}
