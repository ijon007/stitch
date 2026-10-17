import SwiftUI
import UIKit

struct FriendsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var requests = FriendSample.requests
    @State private var friends = FriendSample.friends
    @State private var accepted = 0

    private var settle: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 1)
    }

    var body: some View {
        Group {
            if requests.isEmpty && friends.isEmpty {
                empty
            } else {
                populated
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(StitchColor.cream)
        .sensoryFeedback(.success, trigger: accepted)
        .onAppear(perform: FriendLookupCheck.run)
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
            Button("Add", action: {})
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
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func friendRow(_ person: StitchPerson) -> some View {
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
