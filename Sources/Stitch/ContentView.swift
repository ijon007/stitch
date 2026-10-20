import SwiftUI
import UIKit

struct ContentView: View {
    @State private var tab: AppTab = .boards
    @State private var width: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        tabs
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .simultaneousGesture(edgeSwipe)
            .sensoryFeedback(.selection, trigger: tab)
    }

    /// Swipe in from the screen edge to move one tab over, like Instagram.
    private var edgeSwipe: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .global)
            .onEnded { value in
                let edge: CGFloat = 28
                let dx = value.translation.width
                guard abs(dx) > 70, abs(dx) > abs(value.translation.height) * 1.5 else { return }
                let all = AppTab.allCases
                guard let index = all.firstIndex(of: tab) else { return }
                let motion: Animation = reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.34, dampingFraction: 1)
                if value.startLocation.x < edge, dx > 0, index > 0 {
                    withAnimation(motion) { tab = all[index - 1] }
                } else if value.startLocation.x > width - edge, dx < 0, index < all.count - 1 {
                    withAnimation(motion) { tab = all[index + 1] }
                }
            }
    }

    private var tabs: some View {
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
