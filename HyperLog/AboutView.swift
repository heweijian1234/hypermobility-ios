import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.accent)
                    Text("All entries and photos stay on this device. Nothing is ever uploaded.")
                        .font(Theme.ui(12.5))
                        .foregroundColor(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hair, lineWidth: 1))

                section(
                    "What HyperLog is for",
                    "A simple journal for hypermobile joints — log pain, flexibility changes, subluxations or dislocations with photos and notes. Entries group themselves by joint so patterns jump out. Perfect to show your physio or rheumatologist."
                )

                section(
                    "Not a medical device",
                    "HyperLog records what you experience. It does not diagnose any condition (including Ehlers-Danlos syndromes or generalized joint hypermobility). Consult a healthcare professional for medical concerns."
                )

                section(
                    "Privacy",
                    "No account, no network, no analytics, no ads.\nPhotos are stored inside the app's own storage.\nNothing leaves the app unless you choose to share it."
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(Theme.paper)
        .navigationTitle("About & Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink { FeedbackView() } label: {
                    Image(systemName: "paperplane")
                }
                .tint(Theme.accent)
            }
        }
    }

    private func section(_ title: LocalizedStringKey, _ text: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.serif(17))
                .foregroundColor(Theme.ink)
            Text(text)
                .font(Theme.ui(12.5))
                .foregroundColor(Theme.ink2)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
