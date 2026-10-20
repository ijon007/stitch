import SwiftUI

struct ProfileBoard: Identifiable, Hashable {
    var id: String
    var title: String
    var owner: String?
    var sticker: String
    var saved: SavedBoard? = nil
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
    @State private var opened: SavedBoard?
    @State private var store = BoardStore.shared

    private var yourBoards: [ProfileBoard] {
        store.boards.map { ProfileBoard(id: $0.id.uuidString, title: $0.title, sticker: "", saved: $0) } + yours
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            profile
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $showSettings) {
                    SettingsView(name: name)
                }
                .fullScreenCover(item: $opened) { board in
                    SavedBoardViewer(board: board)
                }
        }
    }

    private var profile: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            ShelfSwitch(shelf: $shelf)
            ZStack {
                if shelf == .yours {
                    shelfPage(yourBoards, empty: .yours)
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
                Avatar(person: FriendSample.me, size: 34)
                    .overlay {
                        Circle().stroke(StitchColor.line, lineWidth: 0.5)
                    }

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
                        BoardCoverCard(board: board) {
                            if let saved = board.saved { opened = saved }
                        }
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
    var onOpen: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                if let saved = board.saved {
                    SavedCover(board: saved)
                } else {
                    CoverArt(sticker: board.sticker)
                }
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

private struct SavedCover: View {
    var board: SavedBoard

    var body: some View {
        ZStack {
            StitchColor.slot
            if let image = BoardStore.shared.image(board) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 176)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct SavedBoardViewer: View {
    var board: SavedBoard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Text(board.title)
                    .font(StitchFont.display(22))
                    .foregroundStyle(StitchColor.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 72)
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(StitchColor.ink)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                    Spacer()
                    if let image = BoardStore.shared.image(board) {
                        ShareLink(item: Image(uiImage: image), preview: SharePreview(board.title, image: Image(uiImage: image))) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(StitchColor.ink)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Share")
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 52)

            if let image = BoardStore.shared.image(board) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .padding(.horizontal, 16)
                    .frame(maxHeight: .infinity)
                    .accessibilityLabel(board.title)
            }

            Text(board.created.formatted(date: .abbreviated, time: .omitted))
                .font(StitchFont.sans(14, weight: .medium))
                .foregroundStyle(StitchColor.muted)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StitchColor.cream)
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
