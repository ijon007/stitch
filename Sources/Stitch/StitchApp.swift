import CoreText
import SwiftUI

@main
struct StitchApp: App {
    init() {
        StitchFont.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
        }
    }
}

/// Shows onboarding until it's finished once, then the app.
struct RootView: View {
    @AppStorage("stitch.onboarded") private var onboarded = false

    var body: some View {
        ZStack {
            if onboarded {
                ContentView()
                    .transition(.opacity)
            } else {
                OnboardingView { onboarded = true }
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.35), value: onboarded)
    }
}

enum StitchFont {
    static func register() {
        for name in ["Newsreader-Italic", "InstrumentSans"] {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Newsreader16pt-Italic", size: size).weight(weight)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight) -> Font {
        .custom("Instrument Sans", size: size).weight(weight)
    }
}

enum StitchColor {
    static let ink = Color(red: 26 / 255, green: 24 / 255, blue: 22 / 255)
    static let accent = Color(red: 210 / 255, green: 10 / 255, blue: 46 / 255)
    static let muted = Color(red: 107 / 255, green: 100 / 255, blue: 92 / 255)
    static let cream = Color(red: 247 / 255, green: 243 / 255, blue: 238 / 255)
    static let slot = Color(red: 235 / 255, green: 228 / 255, blue: 219 / 255)
    static let paper = Color(red: 251 / 255, green: 248 / 255, blue: 244 / 255)
    static let line = Color(red: 229 / 255, green: 223 / 255, blue: 214 / 255)
    static let photo = Color(red: 226 / 255, green: 218 / 255, blue: 208 / 255)
    static let silk = Color(red: 243 / 255, green: 230 / 255, blue: 232 / 255)
    static let background = cream
    static let dash = Color(red: 201 / 255, green: 192 / 255, blue: 180 / 255)
    static let swatchStone = Color(red: 196 / 255, green: 183 / 255, blue: 166 / 255)
}

enum AppTab: String, CaseIterable, Identifiable {
    case boards, friends, profile

    var id: String { rawValue }

}
