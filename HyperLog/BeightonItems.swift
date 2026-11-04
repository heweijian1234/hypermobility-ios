import Foundation

// Beighton 9 项定义（嵌入详细记录的紧凑自查——随条目Save）
enum BeightonItems {
    static let all: [(key: String, title: String, how: String)] = [
        ("pinkyR", "Pinky (right)", "Bends past 90°"),
        ("pinkyL", "Pinky (left)", "Bends past 90°"),
        ("thumbR", "Thumb (right)", "Can be pressed to the forearm"),
        ("thumbL", "Thumb (left)", "Can be pressed to the forearm"),
        ("elbowR", "Elbow (right)", "Hyperextends past 10°"),
        ("elbowL", "Elbow (left)", "Hyperextends past 10°"),
        ("kneeR", "Knee (right)", "Hyperextends past 10° standing"),
        ("kneeL", "Knee (left)", "Hyperextends past 10° standing"),
        ("bend", "Bend forward", "Knees straight, palms flat on floor"),
    ]
}
