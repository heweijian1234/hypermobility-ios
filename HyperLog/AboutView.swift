import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("All entries and photos stay on this device. Nothing is ever uploaded.", systemImage: "lock.shield.fill")
                    .font(.subheadline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                Text("What HyperLog is for").font(.headline)
                Text("A simple journal for hypermobile joints — log pain, flexibility changes, subluxations or dislocations with photos and notes. Entries group themselves by joint so patterns jump out. Perfect to show your physio or rheumatologist.")

                Text("Not a medical device").font(.headline)
                Text("HyperLog records what you experience. It does not diagnose any condition (including Ehlers-Danlos syndromes or generalized joint hypermobility). Consult a healthcare professional for medical concerns.")

                Text("Privacy").font(.headline)
                Text("• No account, no network, no analytics, no ads\n• Photos are stored inside the app's own storage\n• Nothing leaves the app unless you choose to share it")
            }
            .padding()
        }
        .navigationTitle("About & Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink { FeedbackView() } label: {
                    Label("Feedback", systemImage: "paperplane")
                }
            }
        }
    }
}
