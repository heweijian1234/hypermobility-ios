import SwiftUI
import MessageUI

// MARK: - 用户反馈页 v2（健哥 11-19 令：同 GroomerBook 改法——道歉文案+邮箱统一 zerone348+无邮件账户回退）
struct FeedbackView: View {
    @State private var text = ""
    @State private var showMail = false
    @State private var noMail = false   // 11-23修：无邮件账户提示页
    @State private var mailAvailable = MFMailComposeViewController.canSendMail()

    var body: some View {
        Form {
            Section("Tell us what you think") {
                TextField("What works, what doesn't, what you wish existed — the developer reads every message.", text: $text, axis: .vertical)
                    .lineLimit(6...14)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            } label: {
                                Label("Done", systemImage: "keyboard.chevron.compact.down")
                            }
                        }
                    }
            }
            Section {
                Button {
                    if mailAvailable {
                        showMail = true
                    } else {
                        // 11-23修：无系统邮件账户不再mailto跳白屏（U同款）——弹提示页+复制正文
                        UIPasteboard.general.string = text
                        noMail = true
                    }
                } label: {
                    Label("Send to developer", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if !mailAvailable {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No mail account on this device — send feedback to:")
                            .font(.caption).foregroundColor(.secondary)
                        Text("zerone348@gmail.com")
                            .font(.body.bold())
                            .textSelection(.enabled)
                    }
                }
            } footer: {
                // 健哥 11-19 令：道歉+欢迎新功能想法（同 GroomerBook ⑦）
                Text("Sorry for any trouble! Please tell the developer what's not working — it will be fixed as soon as possible. New feature ideas are also very welcome, so the app can serve you better.")
            }
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMail) {
            MailComposer(body: text)
        }
        .sheet(isPresented: $noMail) {
            NavigationStack {
                Form {
                    Section {
                        Text("No system Mail account on this phone, so the draft can't open here.")
                            .font(.subheadline)
                        Text("Your feedback has been copied. Send it from any mail app (Gmail / Outlook) to:")
                            .font(.footnote).foregroundColor(.secondary)
                        Text("zerone348@gmail.com")
                            .font(.body.bold())
                            .textSelection(.enabled)
                    } footer: {
                        Text("Long-press the address above to copy it.")
                    }
                }
                .navigationTitle("Email the Developer")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { noMail = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

struct MailComposer: UIViewControllerRepresentable {
    let body: String
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let m = MFMailComposeViewController()
        m.setToRecipients(["zerone348@gmail.com"])
        m.setSubject("HyperLog Feedback")
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
