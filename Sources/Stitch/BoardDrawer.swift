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
    var onPhoto: (UIImage) -> Void
    var onSticker: (StickerKind) -> Void

    @State private var tab: DrawerTab = .photos
    @State private var pick: PhotosPickerItem?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 14) {
            Picker("Add", selection: $tab) {
                ForEach(DrawerTab.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            switch tab {
            case .photos:
                PhotosPicker("Photos", selection: $pick, matching: .images)
                    .photosPickerStyle(.inline)
                    .photosPickerDisabledCapabilities([.selectionActions, .stagingArea])
                    .photosPickerAccessoryVisibility(.hidden, edges: .all)
            case .stickers:
                stickers
            }
        }
        .padding(.top, 22)
        .frame(maxHeight: .infinity, alignment: .top)
        .sensoryFeedback(.selection, trigger: tab)
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                defer { pick = nil }
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = BoardPhotoLoader.image(from: data) else { return }
                onPhoto(image)
            }
        }
    }

    private var stickers: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(StickerKind.allCases) { kind in
                    Button {
                        onSticker(kind)
                    } label: {
                        StickerView(kind: kind)
                            .scaleEffect(0.78)
                            .frame(maxWidth: .infinity)
                            .frame(height: 108)
                            .background(StitchColor.slot, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(DrawerPress(reduceMotion: reduceMotion))
                    .accessibilityLabel(kind.label)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
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
