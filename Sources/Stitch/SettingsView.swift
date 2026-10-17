import SwiftUI

enum BoardAddPolicy: String, CaseIterable, Identifiable {
    case friends
    case anyone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .friends: "Friends"
        case .anyone: "Anyone"
        }
    }
}

struct SettingsView: View {
    var name: String

    @AppStorage("stitch.notifyCollabs") private var notifyCollabs = true
    @AppStorage("stitch.notifyFriends") private var notifyFriends = true
    @AppStorage("stitch.boardAdds") private var boardAdds = BoardAddPolicy.friends

    private var handle: String {
        "@\(name.lowercased().filter(\.isLetter))"
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Circle()
                        .fill(StitchColor.swatchStone.opacity(0.72))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Circle().stroke(StitchColor.line, lineWidth: 0.5)
                        }
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(StitchFont.sans(17, weight: .medium))
                            .foregroundStyle(StitchColor.ink)
                        Text(handle)
                            .font(StitchFont.sans(13, weight: .medium))
                            .foregroundStyle(StitchColor.muted)
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }

            Section {
                Toggle("Collabs", isOn: $notifyCollabs)
                Toggle("Friend requests", isOn: $notifyFriends)
            } header: {
                Text("Notifications")
            } footer: {
                Text("When you’re added to a board, or someone wants to be friends.")
            }

            Section {
                Picker("Added to boards", selection: $boardAdds) {
                    ForEach(BoardAddPolicy.allCases) { policy in
                        Text(policy.title).tag(policy)
                    }
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text("Friends can always add you. Anyone means people who have your invite link.")
            }
        }
        .listStyle(.insetGrouped)
        .font(StitchFont.sans(17, weight: .regular))
        .foregroundStyle(StitchColor.ink)
        .tint(StitchColor.accent)
        .scrollContentBackground(.hidden)
        .background(StitchColor.cream)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(StitchColor.cream, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        SettingsView(name: "Joni")
    }
}
