import SwiftUI
import UIKit

// MARK: - 设计 token（单一事实源）
// 规范见 docs/UI评审-HyperLog-2026-11-25.html
// 颜色 / 字号 / 严重度梯度只在这里定义，视图与 PDF 共用；换皮只改本文件。

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex & 0xFF0000) >> 16) / 255.0
        let g = Double((hex & 0x00FF00) >> 8) / 255.0
        let b = Double(hex & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

enum Theme {

    // MARK: 底色与墨色
    static let paper   = Color(hex: 0xF6F3EC)   // 页面底色
    static let surface = Color(hex: 0xFFFDF8)   // 卡片面
    static let ink     = Color(hex: 0x1B1A17)   // 正文
    static let ink2    = Color(hex: 0x5F5C53)   // 次要
    static let ink3    = Color(hex: 0x8D8879)   // 辅助
    static let hair    = Color(hex: 0xE4DDCB)   // 分隔线
    static let accent  = Color(hex: 0x22344D)   // 主行动色

    // MARK: 严重度：单一色相热力梯度（白字四档全部 ≥4.5:1）
    // 替换旧的 green / yellow / orange / red 交通灯——黄色文字在白底只有 1.5:1
    static let severityColors: [Color] = [
        Color(hex: 0x8A6E2B),   // 0 Mild
        Color(hex: 0xA5661F),   // 1 Moderate
        Color(hex: 0xA34A24),   // 2 Significant
        Color(hex: 0x7C2D1C)    // 3 Severe
    ]
    private static let severityFull  = ["Mild", "Moderate", "Significant", "Severe"]
    private static let severityUpper = ["MILD", "MODERATE", "SIGNIFICANT", "SEVERE"]

    static func severityColor(_ level: Int) -> Color {
        severityColors[min(max(level, 0), 3)]
    }
    static func severityLabel(_ level: Int) -> String {
        L(severityFull[min(max(level, 0), 3)])
    }
    /// 列表胶囊用：全大写短标签，避免 "Severe (subluxation/dislocation)" 撑爆行宽
    static func severityShortLabel(_ level: Int) -> String {
        L(severityUpper[min(max(level, 0), 3)])
    }

    // MARK: 字体：衬线用系统 New York（iOS 自带，零字体资源）
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: PDF 用 UIColor
    static let accentUI = UIColor(red: 0.133, green: 0.204, blue: 0.302, alpha: 1)
    static func severityUI(_ level: Int) -> UIColor {
        UIColor(severityColor(level))
    }

    // MARK: 通用小件
    static let cardRadius: CGFloat = 14
    static let hairline: CGFloat = 1
}
