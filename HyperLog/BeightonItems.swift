import Foundation

// Beighton 9 项定义（嵌入详细记录的紧凑自查——随条目保存）
enum BeightonItems {
    static let all: [(key: String, title: String, how: String)] = [
        ("pinkyR", "小指（右）", "被动弯超过 90°"),
        ("pinkyL", "小指（左）", "被动弯超过 90°"),
        ("thumbR", "拇指（右）", "被动扳能碰到前臂"),
        ("thumbL", "拇指（左）", "被动扳能碰到前臂"),
        ("elbowR", "肘（右）", "伸直时超伸超过 10°"),
        ("elbowL", "肘（左）", "伸直时超伸超过 10°"),
        ("kneeR", "膝（右）", "站直时超伸超过 10°"),
        ("kneeL", "膝（左）", "站直时超伸超过 10°"),
        ("bend", "直立前弯", "双膝伸直，手掌能平贴地面"),
    ]
}
