import SwiftUI
import UIKit

struct FriendsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var requests = FriendSample.requests
    @State private var friends = FriendSample.friends
    @State private var accepted = 0
    @State private var addOpen = false
    @State private var dragX: CGFloat = 0
    @State private var dragging = false
    @State private var query = ""
    @State private var linkCopied = false
    @State private var copied = 0
    @State private var selected: StitchPerson?

    private var settle: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 1)
    }

    private var coverAnimation: Animation? {
        if dragging { return nil }
        return reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 1)
    }

    private var searchResults: [StitchPerson] {
        FriendSample.directory.filter { person in
            FriendLookup.matches(person.name, query: query)
                && !friends.contains { $0.id == person.id }
                && !requests.contains { $0.id == person.id }
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                listLayer
                AddFriendScreen(
                    query: $query,
                    results: searchResults,
                    linkCopied: linkCopied,
                    reduceMotion: reduceMotion,
                    onClose: { addOpen = false },
                    onCopy: copyLink,
                    onAdd: addFriend
                )
                .offset(x: coverX(geo.size.width))
                .opacity(reduceMotion && !addOpen ? 0 : 1)
                .allowsHitTesting(addOpen)
                .simultaneousGesture(coverDrag(width: geo.size.width))
            }
            .animation(coverAnimation, value: addOpen)
            .animation(coverAnimation, value: dragX)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(StitchColor.cream)
        .sheet(item: $selected) { person in
            SharedBoardsSheet(person: person)
                .presentationDetents([.height(person.boards.isEmpty ? 188 : 268)])
                .presentationDragIndicator(.visible)
                .presentationBackground(StitchColor.cream.opacity(0.94))
        }
        .sensoryFeedback(.success, trigger: accepted)
        .sensoryFeedback(.success, trigger: copied)
        .onAppear(perform: FriendLookupCheck.run)
    }

    private var listLayer: some View {
        Group {
            if requests.isEmpty && friends.isEmpty {
                empty
            } else {
                populated
            }
        }
    }

    private var populated: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if !requests.isEmpty {
                VStack(spacing: 10) {
                    ForEach(requests) { person in
                        requestCard(person)
                    }
                }
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(friends) { person in
                        friendRow(person)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Friends")
                .font(StitchFont.display(34))
                .tracking(-1)
                .foregroundStyle(StitchColor.ink)
            Spacer(minLength: 12)
            Button("Add") { addOpen = true }
                .font(StitchFont.sans(14, weight: .semibold))
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(StitchColor.accent)
                .accessibilityHint("Invite someone")
        }
    }

    private func requestCard(_ person: StitchPerson) -> some View {
        HStack(spacing: 12) {
            avatar(person, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(person.name) asked to join")
                    .font(StitchFont.sans(15, weight: .medium))
                    .foregroundStyle(StitchColor.ink)
                Text("Request")
                    .font(StitchFont.sans(13, weight: .medium))
                    .foregroundStyle(StitchColor.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Accept") { accept(person) }
                .font(StitchFont.sans(14, weight: .semibold))
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(StitchColor.accent)
        }
        .padding(14)
        .background(StitchColor.slot, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func friendRow(_ person: StitchPerson) -> some View {
        Button {
            selected = person
        } label: {
            HStack(spacing: 12) {
                avatar(person, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(StitchFont.sans(16, weight: .medium))
                        .foregroundStyle(StitchColor.ink)
                    Text(person.note)
                        .font(StitchFont.sans(13, weight: .medium))
                        .foregroundStyle(StitchColor.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale(reduceMotion: reduceMotion))
        .accessibilityHint("Shows boards you share")
    }

    private func avatar(_ person: StitchPerson, size: CGFloat) -> some View {
        Circle()
            .fill(person.tone)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private func accept(_ person: StitchPerson) {
        withAnimation(settle) {
            requests.removeAll { $0.id == person.id }
            var joined = person
            joined.boards = []
            friends.insert(joined, at: 0)
            accepted += 1
        }
    }

    private func addFriend(_ person: StitchPerson) {
        withAnimation(settle) {
            friends.append(person)
            query = ""
            addOpen = false
        }
    }

    private func copyLink() {
        UIPasteboard.general.string = "https://stitch.app/invite/joni"
        linkCopied = true
        copied += 1
        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            linkCopied = false
        }
    }

    private func coverX(_ width: CGFloat) -> CGFloat {
        if reduceMotion { return 0 }
        return (addOpen ? 0 : width) + dragX
    }

    private func coverDrag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard !reduceMotion else { return }
                let travel = value.translation
                guard abs(travel.width) > abs(travel.height) else { return }
                dragging = true
                if travel.width < 0 {
                    dragX = -rubberband(overshoot: -travel.width, dimension: width)
                } else {
                    dragX = travel.width
                }
            }
            .onEnded { value in
                guard dragging else { return }
                let projected = dragX + project(value.velocity.width)
                if projected > width * 0.33 {
                    addOpen = false
                }
                dragX = 0
                dragging = false
            }
    }
}

private struct AddFriendScreen: View {
    @Binding var query: String
    var results: [StitchPerson]
    var linkCopied: Bool
    var reduceMotion: Bool
    var onClose: () -> Void
    var onCopy: () -> Void
    var onAdd: (StitchPerson) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(StitchColor.ink)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.small)
                .accessibilityLabel("Close")

                Spacer(minLength: 0)

                Text("Add")
                    .font(StitchFont.sans(17, weight: .semibold))
                    .foregroundStyle(StitchColor.ink)

                Spacer(minLength: 0)

                Color.clear.frame(width: 36, height: 36)
            }

            Text("Send a link. They join as a friend.")
                .font(StitchFont.sans(15, weight: .medium))
                .foregroundStyle(StitchColor.muted)
                .padding(.top, 32)

            Button(action: onCopy) {
                Label(linkCopied ? "Copied" : "Copy invite link", systemImage: linkCopied ? "checkmark" : "link")
                    .font(StitchFont.sans(16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .tint(StitchColor.accent)
            .padding(.top, 20)
            .animation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.3, dampingFraction: 1), value: linkCopied)

            Text("or find them")
                .font(StitchFont.sans(13, weight: .medium))
                .foregroundStyle(StitchColor.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

            TextField("Name or username", text: $query)
                .font(StitchFont.sans(15, weight: .medium))
                .foregroundStyle(StitchColor.ink)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(StitchColor.slot, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 20)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if results.isEmpty {
                    Text("No one with that name.")
                        .font(StitchFont.sans(15, weight: .medium))
                        .foregroundStyle(StitchColor.muted)
                        .padding(.top, 18)
                } else {
                    VStack(spacing: 0) {
                        ForEach(results) { person in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(person.tone)
                                    .frame(width: 44, height: 44)
                                Text(person.name)
                                    .font(StitchFont.sans(16, weight: .medium))
                                    .foregroundStyle(StitchColor.ink)
                                Spacer(minLength: 8)
                                Button("Add") { onAdd(person) }
                                    .font(StitchFont.sans(14, weight: .semibold))
                                    .buttonStyle(.glassProminent)
                                    .buttonBorderShape(.capsule)
                                    .controlSize(.small)
                                    .tint(StitchColor.accent)
                            }
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(.top, 8)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(StitchColor.cream)
    }
}

private struct SharedBoardsSheet: View {
    var person: StitchPerson

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(StitchFont.display(28))
                    .tracking(-0.6)
                    .foregroundStyle(StitchColor.ink)
                Text(person.note)
                    .font(StitchFont.sans(15, weight: .medium))
                    .foregroundStyle(StitchColor.muted)
            }
            if person.boards.isEmpty {
                Text("Boards you share will land here.")
                    .font(StitchFont.sans(15, weight: .medium))
                    .foregroundStyle(StitchColor.muted)
                    .padding(.top, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(person.boards, id: \.self) { board in
                        Text(board)
                            .font(StitchFont.sans(16, weight: .medium))
                            .foregroundStyle(StitchColor.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

struct StitchPerson: Identifiable {
    var name: String
    var boards: [String]
    var tone: Color
    var id: String { name }

    var note: String {
        switch boards.count {
        case 0: "Nothing shared yet"
        case 1: boards[0]
        default: "\(boards.count) boards together"
        }
    }
}

private enum FriendSample {
    static let requests = [
        StitchPerson(name: "Mira", boards: [], tone: Color(red: 184 / 255, green: 163 / 255, blue: 143 / 255)),
    ]
    static let friends = [
        StitchPerson(name: "Alex", boards: ["Night set", "Linen study"], tone: Color(red: 196 / 255, green: 181 / 255, blue: 164 / 255)),
        StitchPerson(name: "Noor", boards: ["Silk season"], tone: Color(red: 168 / 255, green: 146 / 255, blue: 128 / 255)),
        StitchPerson(name: "Theo", boards: [], tone: Color(red: 221 / 255, green: 210 / 255, blue: 198 / 255)),
    ]
    static let directory = [
        StitchPerson(name: "Lena", boards: [], tone: Color(red: 176 / 255, green: 154 / 255, blue: 138 / 255)),
        StitchPerson(name: "Sam", boards: [], tone: Color(red: 154 / 255, green: 140 / 255, blue: 124 / 255)),
        StitchPerson(name: "Idris", boards: [], tone: Color(red: 206 / 255, green: 190 / 255, blue: 174 / 255)),
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
    }
}

private func rubberband(overshoot: CGFloat, dimension: CGFloat, constant: CGFloat = 0.55) -> CGFloat {
    (overshoot * dimension * constant) / (dimension + constant * abs(overshoot))
}

private func project(_ velocity: CGFloat) -> CGFloat {
    let deceleration = 0.998
    return (velocity / 1000) * deceleration / (1 - deceleration)
}
