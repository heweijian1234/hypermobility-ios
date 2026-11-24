import Foundation

// MARK: - 首页概览统计（只读，不改数据模型）
// 首页要回答的三个问题：这周几次 / 最常哪个关节 / 比上周好没好。
// 数据层不动，纯计算，可安全用于任何快照。

enum EntryStats {

    /// 最近 N 天（含今天）逐日桶：日期 / 当天次数 / 当天最高严重度（-1 = 无记录）
    static func dailyBuckets(_ entries: [JointEntry], days: Int = 7) -> [(date: Date, count: Int, peak: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var result: [(date: Date, count: Int, peak: Int)] = []
        result.reserveCapacity(days)

        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let sameDay = entries.filter { cal.isDate($0.date, inSameDayAs: day) }
            let peak = sameDay.map { $0.severity }.max() ?? -1
            result.append((date: day, count: sameDay.count, peak: peak))
        }
        return result
    }

    /// 最近 N 天内的记录数
    static func count(_ entries: [JointEntry], lastDays days: Int) -> Int {
        guard let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: Date())) else {
            return 0
        }
        return entries.filter { $0.date >= start }.count
    }

    /// 本周（7 天）vs 上周（前 7 天）的差值
    static func weekDelta(_ entries: [JointEntry]) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let weekStart = cal.date(byAdding: .day, value: -6, to: today),
              let prevStart = cal.date(byAdding: .day, value: -13, to: today) else { return 0 }
        let thisWeek = entries.filter { $0.date >= weekStart }.count
        let lastWeek = entries.filter { $0.date >= prevStart && $0.date < weekStart }.count
        return thisWeek - lastWeek
    }

    /// 最常见部位（近 N 天；样本为空时回退到全部记录）
    static func topArea(_ entries: [JointEntry], lastDays days: Int = 7) -> (label: String, count: Int)? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        let recent = entries.filter { $0.date >= start }
        let pool = recent.isEmpty ? entries : recent
        guard let top = EntryStore.grouped(pool).first else { return nil }
        return (label: top.label, count: top.count)
    }

    /// 单字母星期（Calendar 1 = 周日）
    static func weekdayLetter(_ date: Date) -> String {
        let letters = ["S", "M", "T", "W", "T", "F", "S"]
        let idx = Calendar.current.component(.weekday, from: date) - 1
        guard idx >= 0 && idx < letters.count else { return "" }
        return letters[idx]
    }

    /// 某一天的概况（点首页柱状时用）：当天条数 + 涉及部位（去重、保持出现顺序）
    static func summary(for day: Date, in entries: [JointEntry]) -> (count: Int, areas: [String]) {
        let cal = Calendar.current
        let sameDay = entries.filter { cal.isDate($0.date, inSameDayAs: day) }
        var seen = Set<String>()
        var areas: [String] = []
        for e in sortedByDate(sameDay) {
            let label = EntryStore.displayPart(e.bodyPart)
            if !seen.contains(label) {
                seen.insert(label)
                areas.append(label)
            }
        }
        return (sameDay.count, areas)
    }

    private static func sortedByDate(_ entries: [JointEntry]) -> [JointEntry] {
        entries.sorted { $0.date < $1.date }
    }
}
