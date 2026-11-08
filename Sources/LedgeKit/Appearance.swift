import SwiftUI

/// Settings › Appearance, handed down the view tree so every surface follows it.
struct Look: Equatable {
    var uiScale = 1.0
    var textScale = 1.0
    var design: Font.Design?
    var border = 1.0
    var radius = 1.0
    /// 0 = clear glass, 1 = dark. Settings shows it as Glass Transparency (the inverse).
    var glassTint = 0.1
    var accent: Color?

    func r(_ base: CGFloat) -> CGFloat { base * radius }
    var glassDarkness: Double { 0.35 + 0.65 * glassTint }
}

enum FontChoice: String, Choice {
    case system = "System", rounded = "Rounded", serif = "Serif", mono = "Monospaced"
    var design: Font.Design? {
        switch self {
        case .system: nil
        case .rounded: .rounded
        case .serif: .serif
        case .mono: .monospaced
        }
    }
}

enum AccentChoice: String, Choice {
    case system = "System", blue = "Blue", purple = "Purple", pink = "Pink", red = "Red"
    case orange = "Orange", yellow = "Yellow", green = "Green", graphite = "Graphite"
    var color: Color? {
        switch self {
        case .system: nil
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .graphite: .gray
        }
    }
}

private struct LookKey: EnvironmentKey {
    static let defaultValue = Look()
}

extension EnvironmentValues {
    var look: Look {
        get { self[LookKey.self] }
        set { self[LookKey.self] = newValue }
    }
}

/// Reads the stored appearance once at a window's root and passes it down.
private struct LookProvider: ViewModifier {
    @AppStorage(K.uiScale.rawValue) private var uiScale = Look().uiScale
    @AppStorage(K.textScale.rawValue) private var textScale = Look().textScale
    @AppStorage(K.fontDesign.rawValue) private var font = FontChoice.system
    @AppStorage(K.borderWidth.rawValue) private var border = Look().border
    @AppStorage(K.cornerRadius.rawValue) private var radius = Look().radius
    @AppStorage(K.glassTint.rawValue) private var glassTint = Look().glassTint
    @AppStorage(K.accentColor.rawValue) private var accent = AccentChoice.system

    func body(content: Content) -> some View {
        let look = Look(uiScale: uiScale, textScale: textScale, design: font.design, border: border,
                        radius: radius, glassTint: glassTint, accent: accent.color)
        content
            .environment(\.look, look)
            .tint(look.accent)
            .animation(.smooth, value: look)
    }
}

/// System font scaled by Text Size and drawn in the chosen font.
private struct LedgeFont: ViewModifier {
    @Environment(\.look) private var look
    var size: CGFloat
    var weight: Font.Weight
    var design: Font.Design?
    var mono: Bool
    var digits: Bool

    func body(content: Content) -> some View {
        let chosen: Font.Design = mono ? .monospaced : (look.design ?? design ?? .default)
        let font = Font.system(size: size * look.textScale, weight: weight, design: chosen)
        return content.font(digits ? font.monospacedDigit() : font)
    }
}

extension View {
    func withLook() -> some View { modifier(LookProvider()) }

    func ledgeFont(_ size: CGFloat, _ weight: Font.Weight = .regular, design: Font.Design? = nil, mono: Bool = false, digits: Bool = false) -> some View {
        modifier(LedgeFont(size: size, weight: weight, design: design, mono: mono, digits: digits))
    }
}
