import SwiftUI

struct StartBoardView: View {
    @State private var began = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Stitch")
                    .foregroundStyle(StitchColor.ink.opacity(0.72))
                Text("Start a board")
                    .font(StitchFont.display(34, weight: .medium))
                    .tracking(-1)
                    .foregroundStyle(StitchColor.ink)
            }

            Button {
                began.toggle()
            } label: {
                BoardCanvas()
            }
            .buttonStyle(BoardPress(reduceMotion: reduceMotion))
            .accessibilityLabel("Board")
            .accessibilityHint("Tap the board to begin")

            Text("Tap the board to begin")
                .font(StitchFont.sans(15, weight: .medium))
                .foregroundStyle(StitchColor.muted)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 22)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(StitchColor.cream)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: began)
    }
}

private struct BoardPress: ButtonStyle {
    var reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 1), value: configuration.isPressed)
    }
}

private struct BoardCanvas: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            StitchColor.slot
            GhostCollage()
            PlusBadge()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(StitchColor.dash, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PlusBadge: View {
    var body: some View {
        Circle()
            .fill(StitchColor.accent)
            .frame(width: 32, height: 32)
            .overlay {
                Path { path in
                    path.move(to: CGPoint(x: 7, y: 2.5))
                    path.addLine(to: CGPoint(x: 7, y: 11.5))
                    path.move(to: CGPoint(x: 2.5, y: 7))
                    path.addLine(to: CGPoint(x: 11.5, y: 7))
                }
                .stroke(StitchColor.background, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 14, height: 14)
            }
            .accessibilityHidden(true)
    }
}

/// Ghost collage laid out in the 350×595 design box, then scaled to the canvas.
private struct GhostCollage: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / 350, geo.size.height / 595)
            ZStack(alignment: .topLeading) {
                polaroid(width: 118, height: 148, photo: 102, photoHeight: 116, radius: 4)
                    .opacity(0.55)
                    .rotationEffect(.degrees(-9))
                    .offset(x: 22, y: 36)
                silk
                    .opacity(0.75)
                    .rotationEffect(.degrees(11))
                    .offset(x: 210, y: 72)
                tape(width: 148, height: 22, opacity: 0.18)
                    .rotationEffect(.degrees(-12))
                    .offset(x: 32, y: 148)
                miniPolaroid
                    .opacity(0.5)
                    .rotationEffect(.degrees(7))
                    .offset(x: 18, y: 248)
                polaroid(width: 152, height: 98, photo: 138, photoHeight: 84, radius: 3)
                    .opacity(0.52)
                    .rotationEffect(.degrees(6))
                    .offset(x: 158, y: 198)
                tape(width: 16, height: 86, opacity: 0.14)
                    .rotationEffect(.degrees(-18))
                    .offset(x: 198, y: 228)
                Circle()
                    .stroke(StitchColor.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-12))
                    .offset(x: 258, y: 318)
                drape
                    .opacity(0.75)
                    .rotationEffect(.degrees(4))
                    .offset(x: 104, y: 388)
                tag
                    .opacity(0.65)
                    .rotationEffect(.degrees(-8))
                    .offset(x: 252, y: 468)
                swatches
                    .opacity(0.75)
                    .rotationEffect(.degrees(-5))
                    .offset(x: 22, y: 528)
            }
            .scaleEffect(s, anchor: .topLeading)
            .frame(width: 350 * s, height: 595 * s, alignment: .topLeading)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func polaroid(width: CGFloat, height: CGFloat, photo: CGFloat, photoHeight: CGFloat, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(StitchColor.paper)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(StitchColor.photo)
                    .padding(.horizontal, (width - photo) / 2)
                    .padding(.top, 8)
                    .frame(height: photoHeight)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(StitchColor.line, lineWidth: 1)
            }
            .frame(width: width, height: height)
    }

    private var miniPolaroid: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(StitchColor.paper)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Color(red: 221 / 255, green: 212 / 255, blue: 201 / 255))
                    .frame(width: 60, height: 64)
                    .padding(.top, 5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(StitchColor.line, lineWidth: 1)
            }
            .frame(width: 72, height: 90)
    }

    private var silk: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(StitchColor.silk)
            .frame(width: 92, height: 92)
            .overlay {
                Text("silk")
                    .font(StitchFont.display(22))
                    .foregroundStyle(StitchColor.accent)
            }
    }

    private func tape(width: CGFloat, height: CGFloat, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(StitchColor.accent.opacity(opacity))
            .frame(width: width, height: height)
    }

    private var drape: some View {
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
    }

    private var swatches: some View {
        HStack(spacing: -2) {
            swatch(StitchColor.ink)
            swatch(StitchColor.accent)
            swatch(StitchColor.swatchStone)
        }
    }

    private func swatch(_ color: Color) -> some View {
        Rectangle().fill(color).frame(width: 34, height: 34)
    }

    private var tag: some View {
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
    }
}
