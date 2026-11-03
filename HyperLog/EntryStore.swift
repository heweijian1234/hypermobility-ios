import Foundation
import UIKit

// MARK: - 关节记录模型（hypermobility/EDS 人群：部位+严重度+文字+照片）

struct JointEntry: Codable, Identifiable {
    let id: UUID
    var date: Date
    var bodyPart: String        // knee/shoulder/finger/hip/back/ankle/wrist/neck/other
    var severity: Int           // 0-3
    var notes: String
    var photoFile: String?      // 沙盒文件名（不带路径）

    var severityLabel: String {
        switch severity {
        case 0: return "Mild"
        case 1: return "Moderate"
        case 2: return "Significant"
        default: return "Severe"
        }
    }
}

enum EntryStore {
    static let bodyParts: [(key: String, label: String, icon: String)] = [
        ("knee", "Knee", "person.fill"),
        ("shoulder", "Shoulder", "figure.arms.open"),
        ("finger", "Fingers", "hand.raised.fill"),
        ("hip", "Hip", "figure.stand"),
        ("back", "Back", "figure.stand.line.dotted.figure"),
        ("ankle", "Ankle", "figure.walk"),
        ("wrist", "Wrist", "hand.draw.fill"),
        ("neck", "Neck", "person.bust"),
        ("jaw", "Jaw", "mouth.fill"),
        ("other", "Other", "circle"),
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
              let list = try? JSONDecoder().decode([JointEntry].self, from: data) else { return [] }
        return list.sorted { $0.date > $1.date }
    }

    static func savePhoto(_ image: UIImage, for id: UUID) -> String? {
        let name = "photo-\(id.uuidString).jpg"
        let url = photoDir.appendingPathComponent(name)
        guard let data = image.jpegData(compressionQuality: 0.75) else { return nil }
        do { try data.write(to: url); return name } catch { return nil }
    }

    static func photoURL(_ file: String) -> URL {
        photoDir.appendingPathComponent(file)
    }

    /// 按部位分组（自动整理）
    static func grouped(_ entries: [JointEntry]) -> [(part: String, label: String, count: Int, items: [JointEntry])] {
        let labels = Dictionary(uniqueKeysWithValues: bodyParts.map { ($0.key, $0.label) })
        let dict = Dictionary(grouping: entries, by: { $0.bodyPart })
        return dict
            .map { (part: $0.key, label: labels[$0.key] ?? $0.key, count: $0.value.count, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.count > $1.count }
    }
}
