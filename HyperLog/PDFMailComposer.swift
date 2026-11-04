import SwiftUI
import MessageUI

// 带附件的邮件直发（发给医生场景）
struct PDFMailComposer: UIViewControllerRepresentable {
    let attachment: Data
    let filename: String

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let m = MFMailComposeViewController()
        m.setSubject("HyperLog 关节报告")
        m.setMessageBody("医生您好，附件是我的关节发作记录报告（HyperLog 生成）。", isHTML: false)
        m.addAttachmentData(attachment, mimeType: "application/pdf", fileName: filename)
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
