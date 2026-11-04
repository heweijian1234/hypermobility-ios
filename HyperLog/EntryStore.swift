import Foundation
import UIKit

// MARK: - 关节记录模型（hypermobility/EDS 人群）——测试期中文版

struct JointEntry: Codable, Identifiable {
    let id: UUID
    var date: Date
    var bodyPart: String        // knee/shoulder/...（存键，显示走中文名）
    var severity: Int           // 0-3（患者自然语言分档，医学换算留给医生——健哥 11-04 拍板）
    var notes: String
    var photoFile: String?    // 旧单 photos字段（读入迁移用）
    var photoFiles: [String]? // 多 photos（健哥 11-04 令）
    // 11-04 增量（健哥拍板 P0/P1/P2 + 疼痛持续时间）
    var painDuration: String?   // 疼痛持续时间（选项）
    var treatment: String?      // self复位/医院复位/未复位
    var triggers: [String]      // 关节版诱因
    var quick: Bool             // 一键Quick Log（To fill细节标记）
    var beighton: Int?          // 本次记录时的 Beighton Score（0-9，随条目存——健哥 11-04 拍板并入）

    var severityLabel: String {
        switch severity {
        case 0: return "轻微"
        case 1: return "中等"
        case 2: return "明显"
        default: return "Severe (subluxation/dislocation)"
        }
    }
    var treatmentLabel: String {
        EntryStore.treatmentOptions.first(where: { $0.key == treatment })?.label ?? ""
    }
    var painDurationLabel: String {
        EntryStore.painDurationOptions.first(where: { $0.key == painDuration })?.label ?? ""
    }
}

// Beighton 自评记录（历史分值）
struct BeightonRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let score: Int   // 0-9
}

enum EntryStore {
    static let bodyParts: [(key: String, label: String)] = [
        ("knee", "Knee"), ("shoulder", "Shoulder"), ("finger", "Fingers"),
        ("hip", "Hip"), ("back", "Back"), ("ankle", "Ankle"),
        ("wrist", "Wrist"), ("neck", "Neck"), ("jaw", "Jaw"), ("other", "Other"),
    ]

    // 疼痛持续时间（选项式——疼痛中单手能选，不打字）
    static let painDurationOptions: [(key: String, label: String)] = [
        ("minutes", "A few minutes"),
        ("halfhour", "~30 minutes"),
        ("couplehours", "1-2 hours"),
        ("halfday", "Half a day"),
        ("allday", "All day"),
        ("ongoing", "Still hurting"),
    ]

    // 处置（医生问诊必问项）
    static let treatmentOptions: [(key: String, label: String)] = [
        ("self", "Self-repositioned"),
        ("hospital", "Repositioned at hospital"),
        ("none", "Went back on its own"),
    ]

    // 关节版诱因
    static let triggerOptions: [(key: String, label: String)] = [
        ("sitting", "Sitting long 🪑"),
        ("sports", "Exercise/stretch 🏃"),
        ("lifting", "Lifting heavy 📦"),
        ("sleepPosture", "Sleep posture 🛏"),
        ("weather", "Weather change 🌦"),
        ("none", "Not sure"),
    ]

    static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("entries", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var photoDir: URL {
        let dir = directory.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func save(_ entries: [JointEntry]) {
        let url = directory.appendingPathComponent("entries.json")
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: url)
        }
    }

    static func load() -> [JointEntry] {
        let url = directory.appendingPathComponent("entries.json")
        guard let data = try? Data(contentsOf: url),
              var list = try? JSONDecoder().decode([JointEntry].self, from: data) else { return [] }
        // 旧单 photos迁移并入多 photos
        var migrated = false
        for i in list.indices {
            if let single = list[i].photoFile {
                if list[i].photoFiles == nil { list[i].photoFiles = [single] }
                list[i].photoFile = nil
                migrated = true
            }
        }
        if migrated { save(list) }
        return list.sorted { $0.date > $1.date }
    }

    static func savePhoto(_ image: UIImage, for id: UUID, index: Int) -> String? {
        let name = "photo-\(id.uuidString)-\(index).jpg"
        let url = photoDir.appendingPathComponent(name)
        guard let data = image.jpegData(compressionQuality: 0.75) else { return nil }
        do { try data.write(to: url); return name } catch { return nil }
    }

    static func photoURL(_ file: String) -> URL {
        photoDir.appendingPathComponent(file)
    }

    /// By area分组（自动整理）
    static func grouped(_ entries: [JointEntry]) -> [(part: String, label: String, count: Int, items: [JointEntry])] {
        let labels = Dictionary(uniqueKeysWithValues: bodyParts.map { ($0.key, $0.label) })
        let dict = Dictionary(grouping: entries, by: { $0.bodyPart })
        return dict
            .map { (part: $0.key, label: labels[$0.key] ?? $0.key, count: $0.value.count, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.count > $1.count }
    }

    // MARK: Beighton 存档
    static func saveBeighton(_ records: [BeightonRecord]) {
        let url = directory.appendingPathComponent("beighton.json")
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: url)
        }
    }
    static func loadBeighton() -> [BeightonRecord] {
        let url = directory.appendingPathComponent("beighton.json")
        guard let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([BeightonRecord].self, from: data) else { return [] }
        return list.sorted { $0.date > $1.date }
    }
}
