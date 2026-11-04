import SwiftUI

// MARK: - Beighton 评分自评（关节过度活动官方量表，9 分制）
// 医生初筛标准——App 里有这个=懂行（P1）
struct BeightonView: View {
    @State private var records: [BeightonRecord] = EntryStore.loadBeighton()
    @State private var scores: [Bool] = Array(repeating: false, count: 9)

    // 9 项（左右对称：小指/拇指/肘/膝 + 前弯）
    private let items: [(key: String, title: String, how: String)] = [
        ("pinkyR", "小指（右手）", "被动弯超过 90°"),
        ("pinkyL", "小指（左手）", "被动弯超过 90°"),
        ("thumbR", "拇指（右手）", "被动扳能碰到前臂"),
        ("thumbL", "拇指（左手）", "被动扳能碰到前臂"),
        ("elbowR", "肘（右侧）", "伸直时超伸超过 10°"),
        ("elbowL", "肘（左侧）", "伸直时超伸超过 10°"),
        ("kneeR", "膝（右侧）", "站直时超伸超过 10°"),
        ("kneeL", "膝（左侧）", "站直时超伸超过 10°"),
        ("bend", "直立前弯", "双膝伸直，手掌能平贴地面"),
    ]

    private var total: Int { scores.filter { $0 }.count }

    var body: some View {
        List {
            Section {
                VStack(spacing: 6) {
                    Text("本次得分：\(total) / 9")
                        .font(.title2.bold())
                        .foregroundColor(.purple)
                    Text(total >= 5 ? "≥5 分：符合全身性关节过度活动（以医生诊断为准）" : "记录你的自查结果，供医生参考")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                Button {
                    let rec = BeightonRecord(id: UUID(), date: Date(), score: total)
                    records.insert(rec, at: 0)
                    EntryStore.saveBeighton(records)
                } label: {
                    Label("保存本次自评", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
            Section("逐项自查（能做到就打开）") {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    Toggle(isOn: $scores[i]) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.subheadline)
                            Text(item.how).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
            if !records.isEmpty {
                Section("历史自评") {
                    ForEach(records) { rec in
                        HStack {
                            Text(rec.date.formatted(.dateTime.year().month().day()))
                            Spacer()
                            Text("\(rec.score) / 9").bold().foregroundColor(.purple)
                        }
                    }
                }
            }
            Section {
                Text("Beighton 量表是关节过度活动的通用自查工具，不是诊断——结果请交给医生解读。")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .navigationTitle("Beighton 自评")
        .navigationBarTitleDisplayMode(.inline)
    }
}
