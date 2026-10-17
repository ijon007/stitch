import SwiftUI

struct ProfileBoard: Identifiable, Hashable {
    var id: String
    var title: String
    var owner: String?
    var sticker: String
}

enum ProfileShelf: String, CaseIterable, Identifiable {
    case yours
    case collabs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yours: "Yours"
        case .collabs: "Collabs"
        }
    }
}

struct ProfileView: View {
    var name: String = "Joni"
    var yours: [ProfileBoard] = ProfileBoard.sampleYours
    var collabs: [ProfileBoard] = ProfileBoard.sampleCollabs

    @State private var shelf: ProfileShelf = .yours
    @State private var showSettings = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            profile
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $showSettings) {
                    SettingsView(name: name)
                }
        }
    }

    private var profile: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            ShelfSwitch(shelf: $shelf)
            ZStack {
                if shelf == .yours {
                    shelfPage(yours, empty: .yours)
                        .transition(pageTransition(fromTrailing: false))
                } else {
                    shelfPage(collabs, empty: .collabs)
                        .transition(pageTransition(fromTrailing: true))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(StitchColor.cream)
        .animation(shelfMotion, value: shelf)
        .sensoryFeedback(.selection, trigger: shelf)
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(StitchColor.swatchStone.opacity(0.72))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Circle().stroke(StitchColor.line, lineWidth: 0.5)
                    }
                    .accessibilityHidden(true)

                Text(name)
                    .font(StitchFont.display(34))
                    .tracking(-0.8)
                    .foregroundStyle(StitchColor.ink)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(StitchColor.ink)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.small)
            .accessibilityLabel("Settings")
        }
    }

    @ViewBuilder
    private func shelfPage(_ boards: [ProfileBoard], empty: ProfileShelf) -> some View {
        if boards.isEmpty {
            EmptyShelf(shelf: empty)
        } else {
            ScrollView {
                LazyVStack(spacing: 18) {
                    ForEach(boards) { board in
                        BoardCoverCard(board: board)
                    }
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func pageTransition(fromTrailing: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }
        let x: CGFloat = fromTrailing ? 18 : -18
        return .asymmetric(
            insertion: .offset(x: x).combined(with: .opacity),
            removal: .offset(x: x).combined(with: .opacity)
        )
    }

    private var shelfMotion: Animation {
        reduceMotion
            ? .easeOut(duration: 0.16)
            : .spring(response: 0.32, dampingFraction: 1)
    }
}

private struct ShelfSwitch: View {
    @Binding var shelf: ProfileShelf
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ProfileShelf.allCases) { item in
                Button {
                    shelf = item
                } label: {
                    Text(item.title)
                        .font(StitchFont.sans(15, weight: .semibold))
                        .foregroundStyle(shelf == item ? StitchColor.ink : StitchColor.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .contentShape(Capsule())
                }
                .buttonStyle(PressScale(reduceMotion: reduceMotion))
                .accessibilityAddTraits(shelf == item ? [.isSelected] : [])
            }
        }
        .background {
            GeometryReader { geo in
                let tab = geo.size.width / CGFloat(ProfileShelf.allCases.count)
                Capsule()
                    .fill(Color.white.opacity(0.42))
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .frame(width: tab, height: geo.size.height)
                    .offset(x: tab * CGFloat(ProfileShelf.allCases.firstIndex(of: shelf) ?? 0))
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Boards")
    }
}

private struct BoardCoverCard: View {
    var board: ProfileBoard
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                CoverArt(sticker: board.sticker)
                HStack(alignment: .firstTextBaseline) {
                    Text(board.title)
                        .font(StitchFont.display(20))
                        .foregroundStyle(StitchColor.ink)
                    Spacer(minLength: 8)
                    if let owner = board.owner {
                        Text(owner)
                            .font(StitchFont.sans(13, weight: .medium))
                            .foregroundStyle(StitchColor.muted)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .buttonStyle(PressScale(reduceMotion: reduceMotion))
        .accessibilityLabel(accessibilityName)
    }

    private var accessibilityName: String {
        if let owner = board.owner {
            "\(board.title), with \(owner)"
        } else {
            board.title
        }
    }
}

private struct CoverArt: View {
    var sticker: String

    var body: some View {
        ZStack {
            StitchColor.slot
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(red: 148 / 255, green: 127 / 255, blue: 106 / 255))
                .frame(width: 128, height: 158)
                .rotationEffect(.degrees(-8))
                .offset(x: -52, y: 10)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(StitchColor.silk)
                .frame(width: 88, height: 90)
                .overlay {
                    Text(sticker)
                        .font(StitchFont.display(22))
                        .foregroundStyle(StitchColor.accent)
                }
                .rotationEffect(.degrees(11))
                .offset(x: 62, y: 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 176)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct EmptyShelf: View {
    var shelf: ProfileShelf

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(StitchColor.dash, style: StrokeStyle(lineWidth: 1.4, dash: [5, 5]))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(StitchColor.paper)
                    .frame(width: 46, height: 54)
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(StitchColor.photo)
                            .padding(5)
                            .padding(.bottom, 10)
                    }
                    .rotationEffect(.degrees(-8))
                    .offset(x: -8, y: -4)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(StitchColor.silk)
                    .frame(width: 42, height: 28)
                    .overlay {
                        Capsule()
                            .fill(StitchColor.accent.opacity(0.28))
                            .frame(width: 34, height: 7)
                    }
                    .rotationEffect(.degrees(12))
                    .offset(x: 14, y: 10)
            }
            .frame(width: 112, height: 132)

            VStack(spacing: 6) {
                Text(shelf == .yours ? "Nothing here yet" : "No collabs yet")
                    .font(StitchFont.display(26))
                    .foregroundStyle(StitchColor.ink)
                Text(shelf == .yours
                     ? "Boards you finish land here."
                     : "Boards you’re added to land here.")
                    .font(StitchFont.sans(14, weight: .medium))
                    .foregroundStyle(StitchColor.muted)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: -28)
    }
}

private struct PressScale: ButtonStyle {
    var reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 1), value: configuration.isPressed)
    }
}

extension ProfileBoard {
    static let sampleYours = [
        ProfileBoard(id: "silk-season", title: "Silk season", sticker: "silk"),
        ProfileBoard(id: "nasty-tailoring", title: "Nasty tailoring", sticker: "silk"),
    ]

    static let sampleCollabs = [
        ProfileBoard(id: "night-set", title: "Night set", owner: "Alex", sticker: "cut"),
        ProfileBoard(id: "studio-floor", title: "Studio floor", owner: "Noor", sticker: "hem"),
    ]
}

#Preview("Yours") {
    ProfileView()
}

#Preview("Empty") {
    ProfileView(yours: [], collabs: [])
}
