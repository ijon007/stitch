import SwiftUI

enum OnboardingStage: Hashable {
    case welcome
    case explain(Int)
}

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var stage: OnboardingStage = .welcome
    @State private var forward = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            StitchColor.cream.ignoresSafeArea()
            screen
                .id(stage)
                .transition(OnboardingMotion.page(forward: forward, reduceMotion: reduceMotion))
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: stage)
    }

    @ViewBuilder
    private var screen: some View {
        switch stage {
        case .welcome:
            OnboardingWelcome { go(.explain(0)) }
        case .explain(let index):
            OnboardingExplainer(
                index: index,
                onBack: { go(index == 0 ? .welcome : .explain(index - 1), forward: false) },
                onNext: {
                    if index < OnboardingExplainer.count - 1 {
                        go(.explain(index + 1))
                    } else {
                        finishExplainers()
                    }
                }
            )
        //STAGES
        }
    }

    private func finishExplainers() {
        onFinish()
    }

    private func go(_ next: OnboardingStage, forward: Bool = true) {
        self.forward = forward
        withAnimation(OnboardingMotion.spring(reduceMotion)) { stage = next }
    }
}

// MARK: - Shared pieces

enum OnboardingMotion {
    /// New screens slide in from the side you're heading; old ones just fade so nothing fights.
    static func page(forward: Bool, reduceMotion: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .offset(x: forward ? 44 : -44).combined(with: .opacity),
            removal: .opacity
        )
    }

    static func spring(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.9)
    }
}

struct OnboardingTopBar: View {
    var progress: Double?
    var onBack: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(StitchColor.ink)
                        .frame(width: 40, height: 40)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Back")
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
            if let progress {
                OnboardingProgress(value: progress)
            } else {
                Spacer()
            }
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }
}

struct OnboardingProgress: View {
    var value: Double

    var body: some View {
        Capsule()
            .fill(StitchColor.line)
            .frame(height: 6)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(StitchColor.accent)
                        .frame(width: max(6, geo.size.width * value))
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement()
            .accessibilityLabel("Progress")
            .accessibilityValue("\(Int(value * 100)) percent")
    }
}

struct OnboardingButton: View {
    var title: String
    var enabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(StitchFont.sans(17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .contentTransition(.opacity)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .tint(StitchColor.accent)
        .disabled(!enabled)
        .padding(.horizontal, 20)
    }
}

struct OnboardingPolaroid: View {
    var tint: Color
    var width: CGFloat = 112

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(tint)
            .frame(width: width - 16, height: width - 16)
            .padding(8)
            .padding(.bottom, 18)
            .background(StitchColor.paper, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(StitchColor.line, lineWidth: 1)
            }
            .shadow(color: StitchColor.ink.opacity(0.08), radius: 10, y: 5)
    }
}

/// Pieces drop onto the board one after another, like being placed by hand.
private struct Landing: ViewModifier {
    var shown: Bool
    var delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || reduceMotion ? 1 : 0.72)
            .opacity(shown ? 1 : 0)
            .animation(
                reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.55, dampingFraction: 0.72).delay(delay),
                value: shown
            )
    }
}

extension View {
    func landing(_ shown: Bool, delay: Double) -> some View {
        modifier(Landing(shown: shown, delay: delay))
    }
}

// MARK: - Welcome

private struct OnboardingWelcome: View {
    var onStart: () -> Void
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            WelcomeCollage(shown: shown)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 10) {
                Text("Stitch")
                    .font(StitchFont.display(56))
                    .tracking(-1.6)
                    .foregroundStyle(StitchColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Moodboards you make together.")
                    .font(StitchFont.sans(17, weight: .medium))
                    .foregroundStyle(StitchColor.muted)
            }
            .multilineTextAlignment(.center)
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 12)
            .animation(OnboardingMotion.spring(reduceMotion).delay(0.35), value: shown)
            .padding(.bottom, 32)

            OnboardingButton(title: "Get started", action: onStart)
                .opacity(shown ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.5), value: shown)
                .padding(.bottom, 12)
        }
        .onAppear { shown = true }
    }
}

private struct WelcomeCollage: View {
    var shown: Bool

    var body: some View {
        ZStack {
            OnboardingPolaroid(tint: StitchColor.photo, width: 128)
                .rotationEffect(.degrees(-9))
                .offset(x: -72, y: -50)
                .landing(shown, delay: 0)
            StickerView(kind: .silk)
                .rotationEffect(.degrees(10))
                .offset(x: 84, y: -96)
                .landing(shown, delay: 0.08)
            OnboardingPolaroid(tint: StitchColor.swatchStone, width: 118)
                .rotationEffect(.degrees(7))
                .offset(x: 74, y: 44)
                .landing(shown, delay: 0.16)
            StickerView(kind: .ring)
                .offset(x: -92, y: 92)
                .landing(shown, delay: 0.24)
            Text("ideas, together")
                .font(StitchFont.display(24))
                .foregroundStyle(StitchColor.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(StitchColor.silk, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .rotationEffect(.degrees(-4))
                .offset(y: 150)
                .landing(shown, delay: 0.32)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Explainers

struct OnboardingExplainer: View {
    static let count = 3

    var index: Int
    var onBack: () -> Void
    var onNext: () -> Void

    @State private var play = false

    private var copy: (title: String, body: String) {
        switch index {
        case 0: ("Collage anything", "Drop in photos and stickers, then pinch, turn and move them until it feels right.")
        case 1: ("Say it in type", "Add words in five fonts, and wrap them in a label, silk or tape.")
        default: ("Make it with friends", "Invite friends onto a board, then share it or save it to Photos.")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTopBar(progress: nil, onBack: onBack)

            ExplainerVisual(index: index, play: play)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            VStack(spacing: 10) {
                Text(copy.title)
                    .font(StitchFont.display(34))
                    .tracking(-0.8)
                    .foregroundStyle(StitchColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(copy.body)
                    .font(StitchFont.sans(16, weight: .medium))
                    .foregroundStyle(StitchColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            PageDots(count: Self.count, index: index)
                .padding(.vertical, 24)

            OnboardingButton(title: "Continue", action: onNext)
                .padding(.bottom, 12)
        }
        .onAppear { play = true }
    }
}

private struct PageDots: View {
    var count: Int
    var index: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? StitchColor.ink : StitchColor.dash)
                    .frame(width: i == index ? 20 : 6, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Page \(index + 1) of \(count)")
    }
}

private struct ExplainerVisual: View {
    var index: Int
    var play: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(StitchColor.slot)
            switch index {
            case 0: collage
            case 1: TypeCycle()
            default: together
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .accessibilityHidden(true)
    }

    private var collage: some View {
        ZStack {
            OnboardingPolaroid(tint: StitchColor.photo, width: 120)
                .rotationEffect(.degrees(-8))
                .offset(x: -60, y: -40)
                .landing(play, delay: 0.05)
            StickerView(kind: .drape)
                .offset(x: 70, y: -70)
                .landing(play, delay: 0.2)
            StickerView(kind: .tag)
                .offset(x: -70, y: 90)
                .landing(play, delay: 0.35)
            OnboardingPolaroid(tint: StitchColor.swatchStone, width: 104)
                .phaseAnimator(reduceMotion ? [false] : [false, true]) { view, on in
                    view
                        .rotationEffect(.degrees(on ? 9 : 2))
                        .scaleEffect(on ? 1.08 : 1)
                } animation: { _ in .spring(response: 1.2, dampingFraction: 0.8) }
                .offset(x: 56, y: 60)
                .landing(play, delay: 0.5)
        }
    }

    private var together: some View {
        ZStack {
            MiniCover(sticker: "silk", width: 170, height: 200, radius: 22)
                .rotationEffect(.degrees(-3))
                .shadow(color: StitchColor.ink.opacity(0.1), radius: 14, y: 6)
                .landing(play, delay: 0)
            ForEach(Array(FriendSample.friends.enumerated()), id: \.element.id) { i, person in
                Avatar(person: person, size: 52)
                    .overlay { Circle().stroke(StitchColor.cream, lineWidth: 3) }
                    .offset(x: [-108, 112, -96][i], y: [-96, -40, 104][i])
                    .landing(play, delay: 0.2 + Double(i) * 0.12)
            }
            HStack(spacing: 10) {
                badge("square.and.arrow.up")
                badge("arrow.down.to.line")
            }
            .offset(x: 84, y: 118)
            .landing(play, delay: 0.6)
        }
    }

    private func badge(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(StitchColor.ink)
            .frame(width: 44, height: 44)
            .glassEffect(.regular, in: .circle)
    }
}

/// Cycles one phrase through every board font and chip style.
private struct TypeCycle: View {
    @State private var step = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let font = BoardFont.allCases[step % BoardFont.allCases.count]
        let style = BoardTextStyle.allCases[step % BoardTextStyle.allCases.count]
        VStack(spacing: 22) {
            Text("make it yours")
                .font(font.font(34))
                .foregroundStyle(style.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(style.fill ?? .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .rotationEffect(.degrees(step.isMultiple(of: 2) ? -3 : 2))
                .contentTransition(.interpolate)
            Text(font.name)
                .font(StitchFont.sans(14, weight: .semibold))
                .foregroundStyle(StitchColor.muted)
                .contentTransition(.opacity)
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.8), value: step)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.3))
                step += 1
            }
        }
    }
}
