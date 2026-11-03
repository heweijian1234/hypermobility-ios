import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("All entries and photos stay on this phone. Nothing is uploaded, ever.", systemImage: "lock.shield.fill")
                    .font(.subheadline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                Text("What HyperLog is for").font(.headline)
                Text("A simple journal for people with hypermobile joints — log pain, flexibility changes, subluxations or dislocations, attach a photo, and see patterns over time. Useful to show your physiotherapist, rheumatologist or GP.")

                Text("Not a medical device").font(.headline)
                Text("HyperLog records what you experience. It does not diagnose any condition, including Ehlers-Danlos syndromes or generalized joint hypermobility. For medical concerns, talk to a healthcare professional.")

                Text("Privacy").font(.headline)
                Text("• No account, no network, no analytics, no ads.\n• Photos are stored inside the app's own storage on your device.\n• Export/share only happens when you choose to.")
            }
            .padding()
        }
        .navigationTitle("About & Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
