import SwiftUI

struct ContentView: View {
    @State private var tab: AppTab = .boards

    var body: some View {
        TabView(selection: $tab) {
            Tab("Boards", systemImage: "square.on.square", value: .boards) {
                StartBoardView()
            }
            Tab("Friends", systemImage: "person.2", value: .friends) {
                QuietPage(title: "Friends")
            }
            Tab("Profile", systemImage: "person.crop.circle", value: .profile) {
                ProfileView()
            }
        }
        .tint(StitchColor.accent)
    }
}

private struct QuietPage: View {
    var title: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            StitchColor.cream.ignoresSafeArea()
            Text(title)
                .font(StitchFont.display(34))
                .tracking(-1)
                .foregroundStyle(StitchColor.ink)
                .padding(.horizontal, 20)
                .padding(.top, 8)
        }
    }
}
