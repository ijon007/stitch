import SwiftUI

/// "Personalizing" beat: ticks through steps built from the quiz answers.
struct OnboardingBuilding: View {
    var answers: OnboardingAnswers
    var onDone: () -> Void

    @State private var progress: Double = 0
    @State private var done = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var steps: [String] {
        let p = answers.phrases
        return [
            "Matching a \(p["vibe"] ?? "fresh") palette",
            "Picking stickers for \(p["goal"] ?? "your boards")",
            "Getting boards ready for \(p["who"] ?? "you")",
            "Setting up your first board",
        ]
    }

    private var finished: Bool { done == steps.count }

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(StitchColor.line, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(StitchColor.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Group {
                    if finished {
                        Image(systemName: "checkmark")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(StitchColor.accent)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    } else {
                        Text("\(Int(progress * 100))%")
                            .font(StitchFont.display(40))
                            .foregroundStyle(StitchColor.ink)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: progress))
                            .transition(.opacity)
                    }
                }
            }
            .frame(width: 168, height: 168)
            .accessibilityElement()
            .accessibilityLabel("Personalizing")
            .accessibilityValue("\(Int(progress * 100)) percent")

            VStack(spacing: 6) {
                Text(finished ? "Your Stitch is ready" : "Personalizing your Stitch")
                    .font(StitchFont.display(30))
                    .tracking(-0.6)
                    .foregroundStyle(StitchColor.ink)
                    .contentTransition(.opacity)
                if !answers.name.isEmpty {
                    Text("Made for \(answers.name)")
                        .font(StitchFont.sans(15, weight: .medium))
                        .foregroundStyle(StitchColor.muted)
                }
            }
            .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, line in
                    let ticked = index < done
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(StitchColor.dash, lineWidth: 1.5)
                                .opacity(ticked ? 0 : 1)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(StitchColor.accent)
                                .scaleEffect(ticked || reduceMotion ? 1 : 0.4)
                                .opacity(ticked ? 1 : 0)
                        }
                        .frame(width: 22, height: 22)
                        Text(line)
                            .font(StitchFont.sans(16, weight: .medium))
                            .foregroundStyle(ticked ? StitchColor.ink : StitchColor.muted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 44)

            Spacer()
            Spacer()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: done)
        .sensoryFeedback(.success, trigger: finished)
        .task { await run() }
    }

    private func run() async {
        let total = steps.count
        for index in 1...total {
            withAnimation(.easeInOut(duration: 0.9)) { progress = Double(index) / Double(total) }
            try? await Task.sleep(for: .seconds(0.95))
            if Task.isCancelled { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { done = index }
        }
        try? await Task.sleep(for: .seconds(0.9))
        if Task.isCancelled { return }
        onDone()
    }
}
