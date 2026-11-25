import SwiftUI

// MARK: - Pro 付费墙

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 8.5, weight: .heavy))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(Theme.severityColor(2)))
    }
}

struct PaywallView: View {

    @EnvironmentObject private var pro: ProStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.ink2)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Theme.surface))
                            .overlay(Circle().stroke(Theme.hair, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 6)

                Text("HyperLog Pro")
                    .font(Theme.serif(28))
                    .foregroundColor(Theme.ink)
                Text("Pay once. Keep it.")
                    .font(Theme.ui(12.5))
                    .foregroundColor(Theme.ink2)
                    .padding(.top, 3)

                VStack(spacing: 0) {
                    benefit("square.and.arrow.up",
                            "Doctor report",
                            "Export a PDF, spreadsheet (CSV) or plain text you can hand to a physio or rheumatologist.")
                    divider
                    benefit("photo.on.rectangle.angled",
                            "Photo comparison",
                            "Put two photos side by side and see swelling change over time.")
                    divider
                    benefit("list.bullet.rectangle",
                            "All records",
                            "Browse your entire history by month, not just the last 7 days.")
                }
                .padding(.horizontal, 14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(Theme.hair, lineWidth: 1)
                )
                .padding(.top, 22)

                Button {
                    Task { await pro.purchase() }
                } label: {
                    HStack(spacing: 8) {
                        if pro.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "lock.open.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text(L("Unlock for %@", pro.priceText))
                                .font(Theme.ui(15, .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 13).fill(Theme.accent))
                }
                .buttonStyle(.plain)
                .disabled(pro.isLoading)
                .padding(.top, 20)

                Button {
                    Task { await pro.restore() }
                } label: {
                    Text("Restore purchase")
                        .font(Theme.ui(12, .semibold))
                        .foregroundColor(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(.plain)

                if let message = pro.message {
                    Text(message)
                        .font(Theme.ui(11))
                        .foregroundColor(Theme.severityColor(2))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }

                Text("One-time purchase, no subscription. Payment is charged to your Apple ID. Restore it any time on any device signed in with the same Apple ID.")
                    .font(Theme.ui(10))
                    .foregroundColor(Theme.ink3)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(Theme.paper)
        .presentationDetents([.height(600), .large])
        .presentationDragIndicator(.visible)
        .onChange(of: pro.isPro) { owned in
            if owned { dismiss() }
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.hair).frame(height: 1)
    }

    private func benefit(_ icon: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.accent)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Theme.paper))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.ui(13, .semibold))
                    .foregroundColor(Theme.ink)
                Text(detail)
                    .font(Theme.ui(11))
                    .foregroundColor(Theme.ink2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
    }
}
