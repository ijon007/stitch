import SwiftUI
import UIKit

extension AppTab {
    var title: String {
        switch self {
        case .boards: "Boards"
        case .friends: "Friends"
        case .profile: "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .boards: "square.on.square"
        case .friends: "person.2"
        case .profile: "person.crop.circle"
        }
    }
}

/// True while a page has something pushed, so the edge belongs to the back swipe.
struct PagerLock: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

/// Tabs laid side by side. Swiping in from a screen edge drags the pages with
/// your finger, like Instagram; tapping the bar springs to the page.
struct ContentView: View {
    @State private var tab: AppTab = .boards
    @State private var drag: CGFloat = 0
    @State private var tracking = false
    @State private var locked = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let edge: CGFloat = 28
    private var all: [AppTab] { AppTab.allCases }
    private var index: Int { all.firstIndex(of: tab) ?? 0 }

    private var settle: Animation {
        reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.36, dampingFraction: 0.92)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            TabPages(width: width, onStartBoard: { select(.boards) })
                .equatable()
                .offset(x: -CGFloat(index) * width + drag)
                .frame(width: width, alignment: .leading)
                .simultaneousGesture(swipe(width: width))
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    StitchTabBar(
                        selected: tab,
                        position: width > 0 ? CGFloat(index) - drag / width : CGFloat(index),
                        select: select
                    )
                }
        }
        .background(StitchColor.cream.ignoresSafeArea())
        .onPreferenceChange(PagerLock.self) { locked = $0 }
        .sensoryFeedback(.selection, trigger: tab)
    }

    private func select(_ next: AppTab) {
        withAnimation(settle) {
            tab = next
            drag = 0
        }
    }

    private func swipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
                if !tracking {
                    let start = value.startLocation.x
                    let fromEdge = start < edge || start > width - edge
                    guard !locked, fromEdge,
                          abs(value.translation.width) > abs(value.translation.height) else { return }
                    tracking = true
                }
                var dx = value.translation.width
                // Rubber-band past the first and last page.
                if (index == 0 && dx > 0) || (index == all.count - 1 && dx < 0) { dx /= 3 }
                drag = dx
            }
            .onEnded { value in
                guard tracking else { return }
                tracking = false
                let dx = value.translation.width
                let flung = value.predictedEndTranslation.width
                var next = index
                if (dx < -width * 0.35 || flung < -width * 0.6), index < all.count - 1 {
                    next += 1
                } else if (dx > width * 0.35 || flung > width * 0.6), index > 0 {
                    next -= 1
                }
                withAnimation(settle) {
                    tab = all[next]
                    drag = 0
                }
            }
    }
}

/// Equatable on width only, so dragging just moves the pages instead of re-rendering them.
private struct TabPages: View, Equatable {
    var width: CGFloat
    var onStartBoard: () -> Void

    nonisolated static func == (a: TabPages, b: TabPages) -> Bool { a.width == b.width }

    var body: some View {
        HStack(spacing: 0) {
            StartBoardView()
                .frame(width: width)
            FriendsView(onStartBoard: onStartBoard)
                .frame(width: width)
            ProfileView()
                .frame(width: width)
        }
    }
}

private struct StitchTabBar: View {
    var selected: AppTab
    /// Fractional page index, so the highlight tracks a drag in progress.
    var position: CGFloat
    var select: (AppTab) -> Void

    var body: some View {
        let count = CGFloat(AppTab.allCases.count)
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { item in
                let isOn = item == selected
                Button { select(item) } label: {
                    VStack(spacing: 2) {
                        Image(systemName: isOn ? item.symbol + ".fill" : item.symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .contentTransition(.symbolEffect(.replace))
                        Text(item.title)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(isOn ? StitchColor.accent : StitchColor.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
            }
        }
        .background(alignment: .leading) {
            GeometryReader { geo in
                let slot = geo.size.width / count
                Capsule()
                    .fill(StitchColor.ink.opacity(0.07))
                    .frame(width: slot, height: geo.size.height)
                    .offset(x: slot * min(max(position, 0), count - 1))
            }
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal, 24)
        .padding(.bottom, 2)
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
