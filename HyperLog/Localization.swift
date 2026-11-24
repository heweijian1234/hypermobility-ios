import Foundation

// MARK: - 运行时本地化
// SwiftUI 里 Text("字面量") 走 LocalizedStringKey，会自动查 Localizable.strings；
// 但「字符串变量 / 数组里的标签 / String(format:) 模板」不会——那些位置统一用 L()。
//
// 语言资源：HyperLog/en.lproj（主体，英文）、HyperLog/zh-Hans.lproj（简体中文）
// 跟随系统语言：设置 → 通用 → 语言与地区，把中文排第一，App 即中文。

/// 本地化查找；带可变参数时按 %@ 模板格式化（统一用 %@ 传字符串，避开 %d 与 Int 宽度的坑）
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, comment: "")
    if args.isEmpty { return format }
    return String(format: format, arguments: args)
}
