import SwiftUI
import UIKit

enum FriendsPage: String, CaseIterable, Identifiable {
    case people
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .people: "People"
        case .activity: "Activity"
        }
    }
}

struct FriendsView: View {
    var onStartBoard: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glass
    @FocusState private var searchFocused: Bool
    @State private var page: FriendsPage = .people
    @State private var friends = FriendSample.friends
    @State private var requests = FriendSample.requests
    @State private var waiting: [StitchPerson] = []
    @State private var searching = false
    @State private var query = ""
    @State private var copied = false
    @State private var selected: StitchPerson?
    @State private var accepted = 0
    @State private var sent = 0

    private var motion: Animation {
        reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.36, dampingFraction: 1)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var friendMatches: [StitchPerson] {
        friends.filter { $0.matches(query) }
    }

    private var strangerMatches: [StitchPerson] {
        FriendSample.directory.filter { person in
            person.matches(query)
                && !friends.contains { $0.id == person.id }
                && !requests.contains { $0.id == person.id }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if searching {
                searchPanel
                    .transition(.opacity)
            } else {
                PageSwitch(page: $page, badge: requests.count)
                    .transition(.opacity)
                ZStack {
                    if page == .people {
                        peoplePage
                            .transition(pageTransition(fromTrailing: false))
                    } else {
                        activityPage
                            .transition(pageTransition(fromTrailing: true))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(StitchColor.cream)
        .animation(motion, value: page)
        .sensoryFeedback(.selection, trigger: page)
        .sensoryFeedback(.success, trigger: accepted)
        .sensoryFeedback(.impact(weight: .light), trigger: sent)
        .sheet(item: $selected) { person in
            FriendSheet(
                person: person,
                onStartBoard: {
                    selected = nil
                    onStartBoard()
                },
                onRemove: { remove(person) }
            )
            .presentationDetents([.height(person.boards.isEmpty ? 270 : 320)])
            .presentationDragIndicator(.visible)
        }
        .onAppear(perform: FriendLookupCheck.run)
    }

    // MARK: Header

    private var header: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                if searching {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(StitchColor.muted)
                        TextField("Name or username", text: $query)
                            .font(StitchFont.sans(16, weight: .medium))
                            .foregroundStyle(StitchColor.ink)
                            .focused($searchFocused)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .glassEffectID("add", in: glass)

                    Button(action: closeSearch) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(StitchColor.ink)
                            .frame(width: 48, height: 48)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .glassEffectID("close", in: glass)
                    .accessibilityLabel("Close search")
                } else {
                    Text("Friends")
                        .font(StitchFont.display(34))
                        .tracking(-1)
                        .foregroundStyle(StitchColor.ink)
                        .transition(.opacity)

                    Spacer(minLength: 12)

                    Button(action: openSearch) {
                        Label("Add", systemImage: "plus")
                            .font(StitchFont.sans(16, weight: .semibold))
                            .foregroundStyle(StitchColor.cream)
                            .padding(.horizontal, 20)
                            .frame(height: 44)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(StitchColor.accent).interactive(), in: .capsule)
                    .glassEffectID("add", in: glass)
                    .accessibilityHint("Find people or share an invite")
                }
            }
            .frame(height: 48)
        }
    }

    // MARK: People

    @ViewBuilder
    private var peoplePage: some View {
        if friends.isEmpty {
            VStack(spacing: 20) {
                EmptyPeople()
                VStack(spacing: 8) {
                    Text("No one yet")
                        .font(StitchFont.display(26))
                        .tracking(-0.4)
                        .foregroundStyle(StitchColor.ink)
                    Text("Invite someone to a board.")
                        .font(StitchFont.sans(15, weight: .medium))
                        .foregroundStyle(StitchColor.muted)
                }
                ShareLink(item: FriendSample.inviteURL) {
                    Label("Share invite link", systemImage: "square.and.arrow.up")
                        .font(StitchFont.sans(16, weight: .semibold))
                        .padding(.horizontal, 6)
                        .frame(height: 36)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(StitchColor.accent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -28)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(friends) { person in
                        friendRow(person)
                    }
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func friendRow(_ person: StitchPerson) -> some View {
        Button {
            selected = person
        } label: {
            HStack(spacing: 14) {
                Avatar(person: person, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(StitchFont.sans(17, weight: .medium))
                        .foregroundStyle(StitchColor.ink)
                    Text(person.note)
                        .font(StitchFont.sans(13, weight: .medium))
                        .foregroundStyle(StitchColor.muted)
                }
                Spacer(minLength: 8)
                BoardStack(boards: person.boards)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale(reduceMotion: reduceMotion))
        .accessibilityLabel("\(person.name), \(person.note)")
        .accessibilityHint("Shows boards you share")
    }

    // MARK: Activity

    private var activityPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if !requests.isEmpty {
                    section("Requests") {
                        VStack(spacing: 0) {
                            ForEach(requests) { person in
                                requestRow(person)
                                if person.id != requests.last?.id {
                                    Divider().overlay(StitchColor.line).padding(.leading, 56)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .background(StitchColor.slot, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                }

                if !waiting.isEmpty {
                    section("Waiting on") {
                        ForEach(waiting) { person in
                            waitingRow(person)
                        }
                    }
                }

                section("Recent") {
                    ForEach(FriendSample.recent) { event in
                        eventRow(event)
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    private func requestRow(_ person: StitchPerson) -> some View {
        HStack(spacing: 12) {
            Avatar(person: person, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(StitchFont.sans(16, weight: .medium))
                    .foregroundStyle(StitchColor.ink)
                Text("Wants to be friends")
                    .font(StitchFont.sans(13, weight: .medium))
                    .foregroundStyle(StitchColor.muted)
            }
            Spacer(minLength: 8)
            Button {
                decline(person)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(StitchColor.muted)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Decline \(person.name)")

            Button { accept(person) } label: {
                Text("Accept")
                    .font(StitchFont.sans(15, weight: .semibold))
                    .foregroundStyle(StitchColor.cream)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(StitchColor.accent).interactive(), in: .capsule)
        }
        .padding(.vertical, 12)
    }

    private func waitingRow(_ person: StitchPerson) -> some View {
        HStack(spacing: 12) {
            Avatar(person: person, size: 44)
                .opacity(0.7)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(StitchFont.sans(16, weight: .medium))
                    .foregroundStyle(StitchColor.ink)
                Text("Request sent")
                    .font(StitchFont.sans(13, weight: .medium))
                    .foregroundStyle(StitchColor.muted)
            }
            Spacer(minLength: 8)
            Button("Cancel") {
                withAnimation(motion) { waiting.removeAll { $0.id == person.id } }
            }
            .font(StitchFont.sans(14, weight: .semibold))
            .foregroundStyle(StitchColor.ink)
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
        }
        .padding(.vertical, 10)
    }

    private func eventRow(_ event: FriendEvent) -> some View {
        HStack(spacing: 12) {
            Avatar(person: event.person, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Text(event.person.name).foregroundStyle(StitchColor.ink)) \(event.action) \(Text(event.board.title).foregroundStyle(StitchColor.ink))")
                    .font(StitchFont.sans(15, weight: .medium))
                    .foregroundStyle(StitchColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text(event.time)
                    .font(StitchFont.sans(13, weight: .medium))
                    .foregroundStyle(StitchColor.muted.opacity(0.8))
            }
            Spacer(minLength: 8)
            MiniCover(sticker: event.board.sticker, width: 44, height: 44, radius: 11)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    // MARK: Search

    private var searchPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if trimmedQuery.isEmpty {
                    inviteCard
                } else {
                    if !friendMatches.isEmpty {
                        section("Your friends") {
                            ForEach(friendMatches) { person in
                                friendRow(person)
                            }
                        }
                    }
                    if !strangerMatches.isEmpty {
                        section("On Stitch") {
                            ForEach(strangerMatches) { person in
                                strangerRow(person)
                            }
                        }
                    }
                    if friendMatches.isEmpty && strangerMatches.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No one called “\(trimmedQuery)”")
                                .font(StitchFont.display(22))
                                .foregroundStyle(StitchColor.ink)
                            Text("Send them a link instead.")
                                .font(StitchFont.sans(15, weight: .medium))
                                .foregroundStyle(StitchColor.muted)
                        }
                        inviteCard
                    }
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Invite with a link")
                    .font(StitchFont.display(24))
                    .tracking(-0.4)
                    .foregroundStyle(StitchColor.ink)
                Text("They join as your friend. Nothing is shared until you share it.")
                    .font(StitchFont.sans(14, weight: .medium))
                    .foregroundStyle(StitchColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                ShareLink(item: FriendSample.inviteURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(StitchFont.sans(15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(StitchColor.accent)

                Button(action: copyLink) {
                    Label(copied ? "Copied" : "Copy link", systemImage: copied ? "checkmark" : "link")
                        .font(StitchFont.sans(15, weight: .semibold))
                        .foregroundStyle(StitchColor.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
            }
        }
        .padding(18)
        .background(StitchColor.slot, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func strangerRow(_ person: StitchPerson) -> some View {
        let isWaiting = waiting.contains { $0.id == person.id }
        return HStack(spacing: 14) {
            Avatar(person: person, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(StitchFont.sans(17, weight: .medium))
                    .foregroundStyle(StitchColor.ink)
                Text(person.handle)
                    .font(StitchFont.sans(13, weight: .medium))
                    .foregroundStyle(StitchColor.muted)
            }
            Spacer(minLength: 8)
            if isWaiting {
                Label("Sent", systemImage: "checkmark")
                    .font(StitchFont.sans(15, weight: .semibold))
                    .foregroundStyle(StitchColor.muted)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .glassEffect(.regular, in: .capsule)
            } else {
                Button("Add") { request(person) }
                    .font(StitchFont.sans(15, weight: .semibold))
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .tint(StitchColor.accent)
            }
        }
        .padding(.vertical, 10)
        .animation(motion, value: isWaiting)
    }

    // MARK: Pieces

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(StitchFont.sans(14, weight: .semibold))
                .foregroundStyle(StitchColor.muted)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func pageTransition(fromTrailing: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }
        let x: CGFloat = fromTrailing ? 18 : -18
        return .offset(x: x).combined(with: .opacity)
    }

    // MARK: Actions

    private func openSearch() {
        withAnimation(motion) { searching = true }
        searchFocused = true
    }

    private func closeSearch() {
        searchFocused = false
        withAnimation(motion) {
            searching = false
            query = ""
        }
    }

    private func accept(_ person: StitchPerson) {
        withAnimation(motion) {
            requests.removeAll { $0.id == person.id }
            friends.insert(person, at: 0)
        }
        accepted += 1
    }

    private func remove(_ person: StitchPerson) {
        selected = nil
        withAnimation(motion) { friends.removeAll { $0.id == person.id } }
    }

    private func decline(_ person: StitchPerson) {
        withAnimation(motion) { requests.removeAll { $0.id == person.id } }
    }

    private func request(_ person: StitchPerson) {
        withAnimation(motion) { waiting.append(person) }
        sent += 1
    }

    private func copyLink() {
        UIPasteboard.general.url = FriendSample.inviteURL
        withAnimation(motion) { copied = true }
        sent += 1
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(motion) { copied = false }
        }
    }
}

// MARK: - Components

private struct PageSwitch: View {
    @Binding var page: FriendsPage
    var badge: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(FriendsPage.allCases) { item in
                Button {
                    page = item
                } label: {
                    HStack(spacing: 6) {
                        Text(item.title)
                        if item == .activity && badge > 0 {
                            Text("\(badge)")
                                .font(StitchFont.sans(12, weight: .bold))
                                .foregroundStyle(StitchColor.cream)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(StitchColor.accent, in: Capsule())
                                .accessibilityLabel("\(badge) new")
                        }
                    }
                    .font(StitchFont.sans(15, weight: .semibold))
                    .foregroundStyle(page == item ? StitchColor.ink : StitchColor.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Capsule())
                }
                .buttonStyle(PressScale(reduceMotion: reduceMotion))
                .accessibilityAddTraits(page == item ? [.isSelected] : [])
            }
        }
        .background {
            GeometryReader { geo in
                let tab = geo.size.width / CGFloat(FriendsPage.allCases.count)
                Capsule()
                    .fill(Color.white.opacity(0.42))
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .frame(width: tab, height: geo.size.height)
                    .offset(x: tab * CGFloat(FriendsPage.allCases.firstIndex(of: page) ?? 0))
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .contain)
    }
}

struct Avatar: View {
    var person: StitchPerson
    var size: CGFloat

    var body: some View {
        Circle()
            .fill(person.tone)
            .frame(width: size, height: size)
            .overlay {
                Text(person.name.prefix(1))
                    .font(StitchFont.display(size * 0.46))
                    .foregroundStyle(StitchColor.paper)
            }
            .accessibilityHidden(true)
    }
}

private struct BoardStack: View {
    var boards: [ProfileBoard]

    var body: some View {
        ZStack {
            ForEach(Array(boards.prefix(2).enumerated()), id: \.element.id) { index, board in
                MiniCover(sticker: board.sticker, width: 34, height: 34, radius: 9)
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(StitchColor.cream, lineWidth: 2)
                    }
                    .rotationEffect(.degrees(index == 0 ? 6 : -6))
                    .offset(x: index == 0 ? 0 : -16)
                    .zIndex(Double(-index))
            }
        }
        .frame(width: 52, alignment: .trailing)
        .accessibilityHidden(true)
    }
}

/// Board cover laid out in a 176pt-tall design box, then scaled to fit.
struct MiniCover: View {
    var sticker: String
    var width: CGFloat
    var height: CGFloat
    var radius: CGFloat

    var body: some View {
        let s = height / 176
        ZStack {
            StitchColor.slot
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(StitchColor.coverPhoto)
                    .frame(width: 104, height: 128)
                    .rotationEffect(.degrees(-8))
                    .offset(x: -30, y: 12)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(StitchColor.silk)
                    .frame(width: 80, height: 82)
                    .overlay {
                        Text(sticker)
                            .font(StitchFont.display(22))
                            .foregroundStyle(StitchColor.accent)
                    }
                    .rotationEffect(.degrees(11))
                    .offset(x: 34, y: 2)
            }
            .frame(width: width / s, height: 176)
            .scaleEffect(s)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct FriendSheet: View {
    var person: StitchPerson
    var onStartBoard: () -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Avatar(person: person, size: 56)
                VStack(alignment: .leading, spacing: 0) {
                    Text(person.name)
                        .font(StitchFont.display(30))
                        .tracking(-0.8)
                        .foregroundStyle(StitchColor.ink)
                    Text(person.handle)
                        .font(StitchFont.sans(14, weight: .medium))
                        .foregroundStyle(StitchColor.muted)
                }
                Spacer(minLength: 8)
                Menu {
                    Button("Remove friend", systemImage: "person.badge.minus", role: .destructive, action: onRemove)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(StitchColor.ink)
                        .frame(width: 40, height: 40)
                        .contentShape(Circle())
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("More")
            }
            .padding(.horizontal, 20)

            if person.boards.isEmpty {
                emptyShared
                    .padding(.horizontal, 20)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(person.boards.count == 1 ? "1 board together" : "\(person.boards.count) boards together")
                        .font(StitchFont.sans(14, weight: .semibold))
                        .foregroundStyle(StitchColor.muted)
                        .padding(.horizontal, 20)
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(person.boards) { board in
                                sharedCard(board)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func sharedCard(_ board: ProfileBoard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MiniCover(sticker: board.sticker, width: 156, height: 118, radius: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(board.title)
                    .font(StitchFont.display(18))
                    .foregroundStyle(StitchColor.ink)
                Text(board.owner.map { "\($0)’s board" } ?? "Your board")
                    .font(StitchFont.sans(13, weight: .medium))
                    .foregroundStyle(StitchColor.muted)
            }
            .padding(.horizontal, 2)
        }
        .frame(width: 156)
        .accessibilityElement(children: .combine)
    }

    private var emptyShared: some View {
        VStack(spacing: 18) {
            HStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(StitchColor.dash, style: StrokeStyle(lineWidth: 1.4, dash: [5, 5]))
                        .frame(width: 92, height: 72)
                    HStack(spacing: -12) {
                        Avatar(person: FriendSample.me, size: 34)
                            .overlay { Circle().stroke(StitchColor.cream, lineWidth: 2) }
                        Avatar(person: person, size: 34)
                            .overlay { Circle().stroke(StitchColor.cream, lineWidth: 2) }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nothing shared yet")
                        .font(StitchFont.display(22))
                        .tracking(-0.3)
                        .foregroundStyle(StitchColor.ink)
                    Text("Start a board and let \(person.name) add to it.")
                        .font(StitchFont.sans(14, weight: .medium))
                        .foregroundStyle(StitchColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)

            Button(action: onStartBoard) {
                Label("Start a board together", systemImage: "plus")
                    .font(StitchFont.sans(16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .tint(StitchColor.accent)
        }
    }
}

private struct EmptyPeople: View {
    var body: some View {
        Canvas { context, size in
            let sx = size.width / 168
            let sy = size.height / 120
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * sx, y: y * sy)
            }
            var front = Path()
            front.addEllipse(in: CGRect(x: (62 - 16) * sx, y: (36 - 16) * sy, width: 32 * sx, height: 32 * sy))
            front.move(to: p(34, 104))
            front.addCurve(to: p(62, 66), control1: p(37, 78), control2: p(47, 66))
            front.addCurve(to: p(90, 104), control1: p(77, 66), control2: p(87, 78))
            context.stroke(front, with: .color(StitchColor.ink), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

            var back = Path()
            back.addEllipse(in: CGRect(x: (108 - 14) * sx, y: (40 - 14) * sy, width: 28 * sx, height: 28 * sy))
            back.move(to: p(86, 104))
            back.addCurve(to: p(108, 72), control1: p(88, 82), control2: p(97, 72))
            back.addCurve(to: p(130, 104), control1: p(119, 72), control2: p(128, 82))
            context.stroke(back, with: .color(StitchColor.muted), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
        .frame(width: 168, height: 120)
        .accessibilityHidden(true)
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

// MARK: - Model

struct StitchPerson: Identifiable {
    var name: String
    var boards: [ProfileBoard] = []
    var tone: Color
    var id: String { name }
    var handle: String { "@\(name.lowercased())" }

    var note: String {
        switch boards.count {
        case 0: "Nothing shared yet"
        case 1: boards[0].title
        default: "\(boards.count) boards together"
        }
    }

    func matches(_ query: String) -> Bool {
        FriendLookup.matches(name, query: query) || FriendLookup.matches(handle, query: query)
    }
}

struct FriendEvent: Identifiable {
    var person: StitchPerson
    var action: String
    var board: ProfileBoard
    var time: String
    var id: String { person.id + board.id }
}

private extension StitchColor {
    static let coverPhoto = Color(red: 148 / 255, green: 127 / 255, blue: 106 / 255)
}

enum FriendSample {
    static let inviteURL = URL(string: "https://stitch.app/invite/joni")!

    static let me = StitchPerson(name: "Joni", tone: StitchColor.accent.opacity(0.75))

    static let alex = StitchPerson(
        name: "Alex",
        boards: [ProfileBoard.sampleCollabs[0]],
        tone: Color(red: 196 / 255, green: 181 / 255, blue: 164 / 255)
    )
    static let noor = StitchPerson(
        name: "Noor",
        boards: [ProfileBoard.sampleCollabs[1], ProfileBoard.sampleYours[0]],
        tone: Color(red: 168 / 255, green: 146 / 255, blue: 128 / 255)
    )
    static let theo = StitchPerson(
        name: "Theo",
        tone: Color(red: 214 / 255, green: 201 / 255, blue: 187 / 255)
    )

    static let friends = [alex, noor, theo]
    static let requests = [
        StitchPerson(name: "Mira", tone: Color(red: 184 / 255, green: 163 / 255, blue: 143 / 255)),
    ]
    static let directory = [
        StitchPerson(name: "Lena", tone: Color(red: 176 / 255, green: 154 / 255, blue: 138 / 255)),
        StitchPerson(name: "Sam", tone: Color(red: 154 / 255, green: 140 / 255, blue: 124 / 255)),
        StitchPerson(name: "Idris", tone: Color(red: 196 / 255, green: 176 / 255, blue: 160 / 255)),
    ]
    static let recent = [
        FriendEvent(person: alex, action: "added you to", board: ProfileBoard.sampleCollabs[0], time: "2h ago"),
        FriendEvent(person: noor, action: "edited", board: ProfileBoard.sampleCollabs[1], time: "Yesterday"),
    ]
}

enum FriendLookup {
    static func matches(_ name: String, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return name.localizedStandardContains(trimmed)
    }
}

enum FriendLookupCheck {
    static func run() {
        assert(FriendLookup.matches("Lena", query: "le"))
        assert(!FriendLookup.matches("Lena", query: "  "))
        assert(!FriendLookup.matches("Lena", query: "sam"))
        assert(StitchPerson(name: "Lena", tone: .clear).matches("@len"))
    }
}
