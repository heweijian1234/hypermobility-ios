import SwiftUI
import MessageUI

// MARK: - 用户反馈页（健哥 11-04 令）——邮件直达 48449892@qq.com（用户主动发信，不破坏"无联网"承诺）
struct FeedbackView: View {
    @State private var text = ""
    @State private var showMail = false
    @State private var mailAvailable = MFMailComposeViewController.canSendMail()

    var body: some View {
        Form {
            Section("Tell us what you think") {
                TextField("What works, what doesn't, what you wish existed — the developer reads every message.", text: $text, axis: .vertical)
                    .lineLimit(6...14)
            }
            Section {
                Button {
                    showMail = true
                } label: {
                    Label("Send to developer", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .disabled(!mailAvailable)
                if !mailAvailable {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No mail account on this device — send feedback to:")
                            .font(.caption).foregroundColor(.secondary)
                        Text("48449892@qq.com")
                            .font(.body.bold())
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMail) {
            MailComposer(body: text)
        }
    }
}

struct MailComposer: UIViewControllerRepresentable {
    let body: String
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let m = MFMailComposeViewController()
        m.setToRecipients(["48449892@qq.com"])
        m.setSubject("HyperLog 用户反馈")
        m.setMessageBody(body, isHTML: false)
        m.mailComposeDelegate = context.coordinator
        return m
    }
    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}
