import SwiftUI

struct OnboardingAnswers {
    var picks: [String: String] = [:]
    /// Short phrases from each pick, so the loader can talk back in plain words.
    var phrases: [String: String] = [:]
    var name = ""
}

struct QuizOption: Identifiable {
    var title: String
    var symbol: String
    var phrase: String
    var id: String { title }
}

struct QuizQuestion: Identifiable {
    var id: String
    var title: String
    var subtitle: String?
    var options: [QuizOption]
}

enum Quiz {
    static let questions: [QuizQuestion] = [
        QuizQuestion(id: "goal", title: "What brings you to Stitch?", options: [
            QuizOption(title: "Planning outfits", symbol: "tshirt", phrase: "your outfits"),
            QuizOption(title: "Collecting inspiration", symbol: "sparkles", phrase: "your inspiration"),
            QuizOption(title: "Planning an event", symbol: "party.popper", phrase: "your event"),
            QuizOption(title: "Designing a space", symbol: "sofa", phrase: "your space"),
            QuizOption(title: "Just for fun", symbol: "face.smiling", phrase: "fun boards"),
        ]),
        QuizQuestion(id: "content", title: "What would you put on a board?", options: [
            QuizOption(title: "Photos I take", symbol: "camera", phrase: "your photos"),
            QuizOption(title: "Screenshots", symbol: "iphone", phrase: "your screenshots"),
            QuizOption(title: "Stickers and doodles", symbol: "scribble", phrase: "stickers"),
            QuizOption(title: "Words and quotes", symbol: "textformat", phrase: "your words"),
        ]),
        QuizQuestion(id: "who", title: "Who would you make boards with?", options: [
            QuizOption(title: "Just me", symbol: "person", phrase: "just you"),
            QuizOption(title: "Friends", symbol: "person.2", phrase: "your friends"),
            QuizOption(title: "My partner", symbol: "heart", phrase: "the two of you"),
            QuizOption(title: "A team or class", symbol: "person.3", phrase: "your group"),
        ]),
        QuizQuestion(id: "vibe", title: "Pick the vibe that feels like you", options: [
            QuizOption(title: "Soft and romantic", symbol: "heart.circle", phrase: "soft, romantic"),
            QuizOption(title: "Clean and minimal", symbol: "square", phrase: "clean, minimal"),
            QuizOption(title: "Bold and loud", symbol: "bolt", phrase: "bold, loud"),
            QuizOption(title: "Vintage", symbol: "camera.filters", phrase: "vintage"),
        ]),
        QuizQuestion(id: "often", title: "How often does inspiration hit?", options: [
            QuizOption(title: "Every day", symbol: "sun.max", phrase: "daily"),
            QuizOption(title: "A few times a week", symbol: "calendar", phrase: "a few times a week"),
            QuizOption(title: "Once a week", symbol: "calendar.badge.clock", phrase: "weekly"),
            QuizOption(title: "Whenever it strikes", symbol: "wand.and.stars", phrase: "whenever"),
        ]),
        QuizQuestion(id: "struggle", title: "What usually gets in the way?", options: [
            QuizOption(title: "Ideas scattered across apps", symbol: "square.stack", phrase: "one place"),
            QuizOption(title: "Hard to share with people", symbol: "bubble.left.and.bubble.right", phrase: "easy sharing"),
            QuizOption(title: "Tools that feel boring", symbol: "zzz", phrase: "something fun"),
            QuizOption(title: "Never enough time", symbol: "clock", phrase: "quick boards"),
        ]),
        QuizQuestion(id: "commit", title: "Will you make your first board this week?",
                     subtitle: "People who start in their first week keep going.", options: [
            QuizOption(title: "Yes, I’m in", symbol: "hand.thumbsup", phrase: "this week"),
            QuizOption(title: "I’ll give it a go", symbol: "sparkle", phrase: "soon"),
        ]),
    ]

    /// Questions plus the name step.
    static var stepCount: Int { questions.count + 1 }
}

struct OnboardingQuiz: View {
    @Binding var answers: OnboardingAnswers
    var onBack: () -> Void
    var onDone: () -> Void

    @State private var step = 0
    @State private var forward = true
    @State private var advancing = false
    @State private var tapped = 0
    @FocusState private var nameFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var trimmedName: String { answers.name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTopBar(progress: Double(step + 1) / Double(Quiz.stepCount), onBack: back)
                .animation(OnboardingMotion.spring(reduceMotion), value: step)

            ZStack {
                Group {
                    if step < Quiz.questions.count {
                        questionPage(Quiz.questions[step])
                    } else {
                        namePage
                    }
                }
                .id(step)
                .transition(OnboardingMotion.page(forward: forward, reduceMotion: reduceMotion))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .sensoryFeedback(.selection, trigger: tapped)
    }

    private func questionPage(_ question: QuizQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(question.title)
                        .font(StitchFont.display(32))
                        .tracking(-0.8)
                        .foregroundStyle(StitchColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle = question.subtitle {
                        Text(subtitle)
                            .font(StitchFont.sans(15, weight: .medium))
                            .foregroundStyle(StitchColor.muted)
                    }
                }

                VStack(spacing: 10) {
                    ForEach(question.options) { option in
                        optionRow(option, in: question)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }

    private func optionRow(_ option: QuizOption, in question: QuizQuestion) -> some View {
        let isOn = answers.picks[question.id] == option.title
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return Button {
            pick(option, for: question)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: option.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isOn ? StitchColor.cream : StitchColor.accent)
                    .frame(width: 28)
                Text(option.title)
                    .font(StitchFont.sans(17, weight: .medium))
                    .foregroundStyle(isOn ? StitchColor.cream : StitchColor.ink)
                Spacer(minLength: 8)
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(StitchColor.cream)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 58)
            .background(isOn ? StitchColor.ink : StitchColor.paper, in: shape)
            .overlay { shape.stroke(isOn ? Color.clear : StitchColor.line, lineWidth: 1) }
            .contentShape(shape)
        }
        .buttonStyle(QuizPress(reduceMotion: reduceMotion))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private var namePage: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What should we call you?")
                    .font(StitchFont.display(32))
                    .tracking(-0.8)
                    .foregroundStyle(StitchColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("It goes on your boards and invites.")
                    .font(StitchFont.sans(15, weight: .medium))
                    .foregroundStyle(StitchColor.muted)
            }

            TextField("Your name", text: $answers.name)
                .font(StitchFont.display(30))
                .foregroundStyle(StitchColor.ink)
                .textContentType(.givenName)
                .submitLabel(.continue)
                .focused($nameFocused)
                .onSubmit { if !trimmedName.isEmpty { finish() } }
                .padding(.horizontal, 18)
                .frame(height: 64)
                .background(StitchColor.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(nameFocused ? StitchColor.ink : StitchColor.line, lineWidth: nameFocused ? 1.5 : 1)
                }

            Spacer(minLength: 0)

            OnboardingButton(title: "Continue", enabled: !trimmedName.isEmpty, action: finish)
                .padding(.horizontal, -20)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .onAppear { nameFocused = true }
    }

    // MARK: Actions

    private func pick(_ option: QuizOption, for question: QuizQuestion) {
        guard !advancing else { return }
        advancing = true
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            answers.picks[question.id] = option.title
            answers.phrases[question.id] = option.phrase
        }
        tapped += 1
        // A beat to see the pick land before the next question slides in.
        Task {
            try? await Task.sleep(for: .seconds(0.32))
            advance()
            advancing = false
        }
    }

    private func advance() {
        forward = true
        withAnimation(OnboardingMotion.spring(reduceMotion)) { step += 1 }
    }

    private func back() {
        guard !advancing else { return }
        nameFocused = false
        if step == 0 { return onBack() }
        forward = false
        withAnimation(OnboardingMotion.spring(reduceMotion)) { step -= 1 }
    }

    private func finish() {
        answers.name = trimmedName
        nameFocused = false
        onDone()
    }
}

private struct QuizPress: ButtonStyle {
    var reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
