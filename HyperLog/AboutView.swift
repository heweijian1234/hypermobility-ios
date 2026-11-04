import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("所有记录和照片都留在本机，永不联网上传。", systemImage: "lock.shield.fill")
                    .font(.subheadline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                Text("HyperLog 是干什么的").font(.headline)
                Text("给关节过度活动（\"软关节\"）人群的简单日志——记录疼痛、柔韧度变化、半脱位或脱位，配上照片和备注，按关节自动分组看规律。给你的理疗师、风湿科医生看再合适不过。")

                Text("不是医疗器械").font(.headline)
                Text("HyperLog 只记录你的感受。它不诊断任何病症（包括埃勒斯-当洛综合征或全身性关节过度活动）。健康问题请咨询专业医生。")

                Text("隐私").font(.headline)
                Text("• 无账号、无联网、无统计、无广告\n• 照片存在 App 自己的存储区里\n• 只有你主动分享时才会导出")
            }
            .padding()
        }
        .navigationTitle("关于与隐私")
        .navigationBarTitleDisplayMode(.inline)
    }
}
