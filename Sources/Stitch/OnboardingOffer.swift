import SwiftUI

/// One-time discount shown once when someone closes the paywall.
struct OnboardingOffer: View {
    var onClaim: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var deadline = Date.now.addingTimeInterval(10 * 60)

    var body: some View {
        VStack(spacing: 18) {
            Text("ONE-TIME OFFER")
                .font(StitchFont.sans(13, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(StitchColor.accent)

            Text("50% off your first year")
                .font(StitchFont.display(32))
                .tracking(-0.8)
                .foregroundStyle(StitchColor.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("$29.99")
                    .font(StitchFont.sans(18, weight: .medium))
                    .strikethrough()
                    .foregroundStyle(StitchColor.muted)
                Text("$14.99 / year")
                    .font(StitchFont.sans(22, weight: .bold))
                    .foregroundStyle(StitchColor.ink)
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let left = max(0, Int(deadline.timeIntervalSince(context.date)))
                Label(String(format: "%02d:%02d", left / 60, left % 60), systemImage: "timer")
                    .font(StitchFont.sans(17, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(StitchColor.ink)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: left)
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .glassEffect(.regular, in: .capsule)
                    .accessibilityLabel("\(left / 60) minutes left")
            }

            Text("This price is gone once you close this.")
                .font(StitchFont.sans(14, weight: .medium))
                .foregroundStyle(StitchColor.muted)

            OnboardingButton(title: "Claim 50% off") {
                onClaim()
                dismiss()
            }
            .padding(.horizontal, -20)

            Button("No thanks") { dismiss() }
                .font(StitchFont.sans(15, weight: .semibold))
                .foregroundStyle(StitchColor.muted)
                .buttonStyle(.plain)
                .frame(height: 36)
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(StitchColor.cream)
    }
}
