import SwiftUI
import UIKit

struct ContentView: View {
    @State private var tab: AppTab = .boards

    var body: some View {
        TabView(selection: $tab) {
            Tab("Boards", systemImage: "square.on.square", value: .boards) {
                StartBoardView()
            }
            Tab("Friends", systemImage: "person.2", value: .friends) {
                FriendsView(onStartBoard: { tab = .boards })
            }
            Tab("Profile", systemImage: "person.crop.circle", value: .profile) {
                ProfileView()
            }
        }
        .tint(StitchColor.accent)
    }
}

/// Hidden nav bars drop the back swipe; keep it whenever there is somewhere to go back to.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
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
