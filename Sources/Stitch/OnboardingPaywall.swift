import SwiftUI

enum PaywallPlan: String, CaseIterable, Identifiable {
    case yearly, weekly

    var id: String { rawValue }
}

/// Visual-only paywall: no StoreKit yet, every way out finishes onboarding.
struct OnboardingPaywall: View {
    var name: String
    var onClose: () -> Void
    var onSubscribe: () -> Void

    @State private var plan: PaywallPlan = .yearly
    @State private var showClose = false
    @State private var offering = false
    @State private var offered = false
    @State private var claimed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(StitchColor.muted)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .opacity(showClose ? 1 : 0)
                .accessibilityLabel("Close")
                Spacer()
                Button("Restore", action: onSubscribe)
                    .font(StitchFont.sans(15, weight: .semibold))
                    .foregroundStyle(StitchColor.muted)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .frame(height: 52)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(name.isEmpty ? "Unlock all of Stitch" : "\(name), unlock all of Stitch")
                            .font(StitchFont.display(34))
                            .tracking(-0.8)
                            .foregroundStyle(StitchColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text("Everything you picked, with nothing held back.")
                            .font(StitchFont.sans(16, weight: .medium))
                            .foregroundStyle(StitchColor.muted)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        feature("square.stack", "Unlimited boards")
                        feature("face.smiling", "Every sticker and font")
                        feature("person.2", "Collab with any number of friends")
                        feature("photo", "Full-resolution exports")
                    }

                    if plan == .yearly {
                        TrialTimeline()
                            .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 8)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 10) {
                planRow(.yearly, title: "Yearly", price: "$29.99 / year", detail: "7 days free, then $0.58 a week", badge: "SAVE 81%")
                planRow(.weekly, title: "Weekly", price: "$2.99 / week", detail: "No free trial", badge: nil)

                OnboardingButton(title: plan == .yearly ? "Start my free trial" : "Continue", action: onSubscribe)
                    .padding(.horizontal, -20)
                    .padding(.top, 6)

                Label(plan == .yearly ? "No payment due now" : "Cancel anytime",
                      systemImage: plan == .yearly ? "checkmark.shield" : "arrow.uturn.backward")
                    .font(StitchFont.sans(13, weight: .semibold))
                    .foregroundStyle(StitchColor.muted)
                    .contentTransition(.opacity)

                HStack(spacing: 16) {
                    Link("Terms", destination: URL(string: "https://stitch.app/terms")!)
                    Link("Privacy", destination: URL(string: "https://stitch.app/privacy")!)
                }
                .font(StitchFont.sans(12, weight: .medium))
                .foregroundStyle(StitchColor.muted.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .background(StitchColor.cream)
        .animation(OnboardingMotion.spring(reduceMotion), value: plan)
        .sensoryFeedback(.selection, trigger: plan)
        .task {
            // The X shows after a beat, so the offer is read first.
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut(duration: 0.3)) { showClose = true }
        }
        .sheet(isPresented: $offering, onDismiss: { claimed ? onSubscribe() : onClose() }) {
            OnboardingOffer(onClaim: { claimed = true })
                .presentationDetents([.height(480)])
                .presentationDragIndicator(.visible)
                .presentationBackground(StitchColor.cream)
        }
    }

    /// The first close turns into the one-time offer; after that it really closes.
    private func close() {
        if offered { return onClose() }
        offered = true
        offering = true
    }

    private func feature(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(StitchColor.accent)
                .frame(width: 36, height: 36)
                .background(StitchColor.silk, in: Circle())
            Text(title)
                .font(StitchFont.sans(16, weight: .medium))
                .foregroundStyle(StitchColor.ink)
        }
    }

    private func planRow(_ option: PaywallPlan, title: String, price: String, detail: String, badge: String?) -> some View {
        let isOn = plan == option
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return Button {
            plan = option
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isOn ? StitchColor.accent : StitchColor.dash)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(StitchFont.sans(17, weight: .semibold))
                        .foregroundStyle(StitchColor.ink)
                    Text(detail)
                        .font(StitchFont.sans(13, weight: .medium))
                        .foregroundStyle(StitchColor.muted)
                }
                Spacer(minLength: 8)
                Text(price)
                    .font(StitchFont.sans(15, weight: .semibold))
                    .foregroundStyle(StitchColor.ink)
            }
            .padding(.horizontal, 16)
            .frame(height: 68)
            .background(StitchColor.paper, in: shape)
            .overlay { shape.stroke(isOn ? StitchColor.accent : StitchColor.line, lineWidth: isOn ? 2 : 1) }
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(StitchFont.sans(11, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(StitchColor.cream)
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(StitchColor.accent, in: Capsule())
                        .offset(x: -14, y: -10)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(price), \(detail)")
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

private struct TrialTimeline: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("How your free trial works")
                .font(StitchFont.sans(14, weight: .semibold))
                .foregroundStyle(StitchColor.muted)
                .padding(.bottom, 14)
            row("lock.open.fill", "Today", "Full access to everything.", last: false)
            row("bell.fill", "Day 5", "We’ll remind you before your trial ends.", last: false)
            row("star.fill", "Day 7", "You’re billed $29.99. Cancel anytime before.", last: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func row(_ symbol: String, _ title: String, _ detail: String, last: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(StitchColor.cream)
                    .frame(width: 30, height: 30)
                    .background(StitchColor.accent, in: Circle())
                if !last {
                    Rectangle()
                        .fill(StitchColor.accent.opacity(0.25))
                        .frame(width: 3, height: 26)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(StitchFont.sans(16, weight: .semibold))
                    .foregroundStyle(StitchColor.ink)
                Text(detail)
                    .font(StitchFont.sans(14, weight: .medium))
                    .foregroundStyle(StitchColor.muted)
            }
            .padding(.top, 4)
        }
    }
}
