import PhotosUI
import _PhotosUI_SwiftUI
import SwiftUI

enum DrawerTab: String, CaseIterable, Identifiable {
    case photos, stickers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photos: "Photos"
        case .stickers: "Stickers"
        }
    }
}

struct BoardDrawer: View {
    var onAdd: ([BoardItem.Content]) -> Void

    @State private var tab: DrawerTab = .photos
    @State private var picks: [PhotosPickerItem] = []
    @State private var stickers: Set<StickerKind> = []
    @State private var adding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedCount: Int { picks.count + stickers.count }

    var body: some View {
        VStack(spacing: 14) {
            DrawerTabs(tab: $tab)
                .padding(.horizontal, 16)

            Group {
                if tab == .photos {
                    PhotosPicker("Photos", selection: $picks, maxSelectionCount: 24, selectionBehavior: .continuousAndOrdered, matching: .images)
                        .photosPickerStyle(.inline)
                        .photosPickerDisabledCapabilities([.selectionActions, .stagingArea])
                        .photosPickerAccessoryVisibility(.hidden, edges: .all)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    stickerGrid
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom, spacing: 10) {
            Button(action: addSelected) {
                Text("Add")
                    .font(StitchFont.sans(16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .tint(StitchColor.accent)
            .disabled(selectedCount == 0 || adding)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .accessibilityHint(selectedCount == 0 ? "Select photos or stickers first" : "Adds \(selectedCount) to the board")
        }
        .sensoryFeedback(.selection, trigger: tab)
        .sensoryFeedback(.selection, trigger: selectedCount)
    }

    private var stickerGrid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(StickerKind.allCases) { kind in
                    let isOn = stickers.contains(kind)
                    Button {
                        if isOn { stickers.remove(kind) } else { stickers.insert(kind) }
                    } label: {
                        StickerView(kind: kind)
                            .scaleEffect(0.78)
                            .frame(maxWidth: .infinity)
                            .frame(height: 108)
                            .background(StitchColor.slot, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(isOn ? StitchColor.accent : .clear, lineWidth: 2)
                            }
                            .overlay(alignment: .topTrailing) {
                                if isOn {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(StitchColor.accent)
                                        .padding(8)
                                }
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(DrawerPress(reduceMotion: reduceMotion))
                    .accessibilityLabel(kind.label)
                    .accessibilityAddTraits(isOn ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
    }

    private func addSelected() {
        guard !adding else { return }
        adding = true
        let chosen = stickers
        let items = picks
        Task {
            var contents: [BoardItem.Content] = []
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = BoardPhotoLoader.image(from: data) else { continue }
                contents.append(.photo(image, .plain))
            }
            for kind in StickerKind.allCases where chosen.contains(kind) {
                contents.append(.sticker(kind))
            }
            await MainActor.run { onAdd(contents) }
        }
    }
}

enum BoardPhotoLoader {
    static let maxSide: CGFloat = 1600

    /// Downscales library photos so a board of them stays light in memory.
    static func image(from data: Data) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide else { return image }
        let k = maxSide / longest
        return image.preparingThumbnail(of: CGSize(width: image.size.width * k, height: image.size.height * k)) ?? image
    }
}

private struct DrawerTabs: View {
    @Binding var tab: DrawerTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DrawerTab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    Text(item.title)
                        .font(StitchFont.sans(15, weight: .semibold))
                        .foregroundStyle(tab == item ? StitchColor.ink : StitchColor.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .contentShape(Capsule())
                }
                .buttonStyle(DrawerPress(reduceMotion: reduceMotion))
                .accessibilityAddTraits(tab == item ? [.isSelected] : [])
            }
        }
        .background {
            GeometryReader { geo in
                let width = geo.size.width / CGFloat(DrawerTab.allCases.count)
                Capsule()
                    .fill(Color.white.opacity(0.42))
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .frame(width: width, height: geo.size.height)
                    .offset(x: width * CGFloat(DrawerTab.allCases.firstIndex(of: tab) ?? 0))
                    .animation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.32, dampingFraction: 1), value: tab)
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Add")
    }
}

private struct DrawerPress: ButtonStyle {
    var reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 1), value: configuration.isPressed)
    }
}

enum StickerKind: String, CaseIterable, Identifiable {
    case silk, drape, tag, swatches, ring, tape

    var id: String { rawValue }

    var label: String {
        switch self {
        case .silk: "Silk sticker"
        case .drape: "Drape label"
        case .tag: "SS26 tag"
        case .swatches: "Colour swatches"
        case .ring: "Circle"
        case .tape: "Tape"
        }
    }
}

struct StickerView: View {
    var kind: StickerKind

    var body: some View {
        switch kind {
        case .silk:
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(StitchColor.silk)
                .frame(width: 92, height: 92)
                .overlay {
                    Text("silk")
                        .font(StitchFont.display(22))
                        .foregroundStyle(StitchColor.accent)
                }
        case .drape:
            Text("drape")
                .font(StitchFont.display(18))
                .foregroundStyle(StitchColor.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(StitchColor.paper, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(StitchColor.line, lineWidth: 1)
                }
        case .tag:
            VStack(spacing: 8) {
                Circle()
                    .stroke(StitchColor.line, lineWidth: 1)
                    .frame(width: 10, height: 10)
                Text("SS26")
                    .font(StitchFont.sans(11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(StitchColor.muted)
            }
            .padding(.top, 12)
            .padding(.bottom, 10)
            .frame(width: 70, height: 86)
            .background(StitchColor.background, in: RoundedRectangle(cornerRadius: 2, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(StitchColor.line, lineWidth: 1)
            }
        case .swatches:
            HStack(spacing: -2) {
                ForEach([StitchColor.ink, StitchColor.accent, StitchColor.swatchStone], id: \.self) { color in
                    Rectangle().fill(color).frame(width: 34, height: 34)
                }
            }
        case .ring:
            Circle()
                .stroke(StitchColor.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
                .frame(width: 56, height: 56)
        case .tape:
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(StitchColor.accent.opacity(0.28))
                .frame(width: 120, height: 24)
        }
    }
}
