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
        case 0: return L("Mild")
        case 1: return L("Moderate")
        case 2: return L("Significant")
        default: return L("Severe (subluxation/dislocation)")
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
    // 显示名走 L()：数组是懒加载，首次访问时按当前系统语言取译文
    static let bodyParts: [(key: String, label: String)] = [
        ("knee", L("Knee")), ("shoulder", L("Shoulder")), ("finger", L("Fingers")),
        ("hip", L("Hip")), ("back", L("Back")), ("ankle", L("Ankle")),
        ("wrist", L("Wrist")), ("neck", L("Neck")), ("jaw", L("Jaw")), ("other", L("Other")),
    ]

    // 疼痛持续时间（选项式——疼痛中单手能选，不打字）
    static let painDurationOptions: [(key: String, label: String)] = [
        ("minutes", L("A few minutes")),
        ("halfhour", L("~30 minutes")),
        ("couplehours", L("1-2 hours")),
        ("halfday", L("Half a day")),
        ("allday", L("All day")),
        ("ongoing", L("Still hurting")),
    ]

    // 处置（医生问诊必问项）
    static let treatmentOptions: [(key: String, label: String)] = [
        ("self", L("Self-repositioned")),
        ("hospital", L("Repositioned at hospital")),
        ("none", L("Went back on its own")),
    ]

    // 关节版诱因（11-25：去掉 emoji，跟 SF Symbols 图标体系冲突，纯文字更稳）
    static let triggerOptions: [(key: String, label: String)] = [
        ("sitting", L("Sitting long")),
        ("sports", L("Exercise / stretch")),
        ("lifting", L("Lifting heavy")),
        ("sleepPosture", L("Sleep posture")),
        ("weather", L("Weather change")),
        ("none", L("Not sure")),
    ]

    static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("entries", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 显示名统一解析（健哥 11-19 令②：other:xxx → "xxx"；普通键 → 英文标签）
    static func displayPart(_ key: String) -> String {
        if key.hasPrefix("other:") {
            let custom = String(key.dropFirst("other:".count))
            return custom.isEmpty ? L("Other") : custom
        }
        return bodyParts.first(where: { $0.key == key })?.label ?? key
    }

    static var photoDir: URL {
        let dir = directory.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 11-23修：删除entry时清理其照片文件（防photos目录磁盘泄漏）
    static func deletePhotoFiles(_ entry: JointEntry) {
        let files = entry.photoFiles ?? (entry.photoFile.map { [$0] } ?? [])
        for f in files {
            try? FileManager.default.removeItem(at: photoDir.appendingPathComponent(f))
        }
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

    /// By area分组（自动整理）——other:xxx 各自定义名独立成组（健哥 11-19 令②）
    static func grouped(_ entries: [JointEntry]) -> [(part: String, label: String, count: Int, items: [JointEntry])] {
        let dict = Dictionary(grouping: entries, by: { $0.bodyPart })
        return dict
            .map { (part: $0.key, label: displayPart($0.key), count: $0.value.count, items: $0.value.sorted { $0.date > $1.date }) }
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
