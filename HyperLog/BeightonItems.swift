import Foundation

// Beighton 9 项定义（嵌入详细记录的紧凑自查——随条目保存）
// 文案走 L()：键=英文原文，中文见 zh-Hans.lproj/Localizable.strings
enum BeightonItems {
    static let all: [(key: String, title: String, how: String)] = [
        ("pinkyR", L("Pinky (right)"), L("Bends past 90°")),
        ("pinkyL", L("Pinky (left)"), L("Bends past 90°")),
        ("thumbR", L("Thumb (right)"), L("Can be pressed to the forearm")),
        ("thumbL", L("Thumb (left)"), L("Can be pressed to the forearm")),
        ("elbowR", L("Elbow (right)"), L("Hyperextends past 10°")),
        ("elbowL", L("Elbow (left)"), L("Hyperextends past 10°")),
        ("kneeR", L("Knee (right)"), L("Hyperextends past 10° standing")),
        ("kneeL", L("Knee (left)"), L("Hyperextends past 10° standing")),
        ("bend", L("Bend forward"), L("Knees straight, palms flat on floor")),
    ]
}
