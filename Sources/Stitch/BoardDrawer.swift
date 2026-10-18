import SwiftUI

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
