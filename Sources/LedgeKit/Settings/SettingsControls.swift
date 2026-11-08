import ServiceManagement
import SwiftUI

// Measured from the reference settings window: cards are 365 pt wide (20 pt left, 36 pt right incl. scroller),
// rows 50 pt tall with 16 pt side padding, labels 13 pt, section titles and hints 11 pt.

/// Scrolling page body.
struct SettingsScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(EdgeInsets(top: 0, leading: 20, bottom: 24, trailing: 36))
        }
    }
}

/// Glass card with an optional title above and hint below; rows get dividers between them.
struct SettingsCard<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder var content: Content
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title).ledgeFont(11, .semibold).foregroundStyle(.secondary).padding(.leading, 6)
            }
            Group(subviews: content) { rows in
                if !rows.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            if row.id != rows.first?.id { Divider().padding(.horizontal, 16) }
                            row
                                .padding(.horizontal, 16)
                                .padding(.vertical, 11)
                                .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                        }
                    }
                    .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: look.r(14), style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: look.r(14), style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: look.border))
                }
            }
            if let footer { Hint(footer).padding(.horizontal, 6) }
        }
        .padding(.bottom, 24)
    }
}

/// Grey footnote under a card.
struct Hint: View {
    var text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).ledgeFont(11).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

/// Title (optional symbol and accessory) on the left, switch on the right.
struct ToggleRow<Accessory: View>: View {
    var title: String
    var symbol: String?
    @Binding var isOn: Bool
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: 8) {
            if let symbol { Image(systemName: symbol).frame(width: 18) }
            Text(title)
            accessory
            Spacer(minLength: 8)
            Toggle(title, isOn: $isOn).toggleStyle(.switch).labelsHidden()
        }
        .ledgeFont(13, .medium)
    }
}

extension ToggleRow where Accessory == EmptyView {
    init(_ title: String, symbol: String? = nil, isOn: Binding<Bool>) {
        self.init(title: title, symbol: symbol, isOn: isOn) { EmptyView() }
    }
}

/// Title on the left, segmented control on the right.
struct SegmentRow<T: Choice>: View {
    var title: String
    @Binding var selection: T

    var body: some View {
        HStack {
            Text(title).ledgeFont(13, .medium)
            Spacer()
            Picker(title, selection: $selection) {
                ForEach(T.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }
}

/// Title on the left, borderless pop-up menu ("All Displays ⌄") on the right.
struct MenuRow<T: Choice>: View {
    var title: String
    var symbol: String?
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 8) {
            if let symbol { Image(systemName: symbol).frame(width: 18) }
            Text(title)
            Spacer()
            Menu(selection.rawValue) {
                Picker(title, selection: $selection) {
                    ForEach(T.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .fixedSize()
            .foregroundStyle(.secondary)
        }
        .ledgeFont(13, .medium)
    }
}

/// Small "On" / "Off" tag next to a toggle's title.
struct StateBadge: View {
    var on: Bool
    var body: some View {
        Text(on ? "On" : "Off")
            .ledgeFont(9, .semibold)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .foregroundStyle(on ? Color.blue : Color.secondary)
            .background(on ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
            .animation(.smooth, value: on)
    }
}

/// Slider with optional title and bold value (+ grey unit), and labels or symbols at both ends.
struct SettingSlider: View {
    var title: String?
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double?
    var display: String?
    var unit: String?
    var low: String
    var high: String
    var lowSymbol: String?
    var highSymbol: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(title).ledgeFont(13, .medium)
                    Spacer()
                    if let display { Text(display).ledgeFont(15, .bold).monospacedDigit() }
                    if let unit { Text(unit).ledgeFont(12).foregroundStyle(.secondary) }
                }
            }
            HStack(spacing: 10) {
                if let lowSymbol { Image(systemName: lowSymbol).ledgeFont(11).foregroundStyle(.secondary) }
                slider.labelsHidden().accessibilityLabel(title ?? "\(low) to \(high)")
                if let highSymbol { Image(systemName: highSymbol).ledgeFont(13).foregroundStyle(.secondary) }
            }
            if !low.isEmpty || !high.isEmpty {
                HStack {
                    Text(low)
                    Spacer()
                    Text(high)
                }
                .ledgeFont(10, .medium)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var slider: some View {
        if let step {
            Slider(value: $value, in: range, step: step) { Text(title ?? low) }
        } else {
            Slider(value: $value, in: range) { Text(title ?? low) }
        }
    }
}

/// Title and subtitle on the left, capsule button on the right (Update page).
struct ActionRow: View {
    var title: String
    var subtitle: String
    var button: String
    var ok = false
    var action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if ok { Image(systemName: "checkmark.circle.fill") }
                    Text(title)
                }
                .ledgeFont(13, .semibold)
                .foregroundStyle(ok ? Color.green : Color.primary)
                Text(subtitle).ledgeFont(11).foregroundStyle(.secondary)
            }
            Spacer()
            Button(button, action: action)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
        }
    }
}

/// Picker card with a glossy dark box (Source, Battery Style, Accessory Style).
struct ChoiceCards<T: Choice>: View {
    var title: String
    @Binding var selection: T
    var showNames = true
    var symbol: (T) -> String
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).ledgeFont(13, .medium)
            HStack(spacing: 0) {
                ForEach(T.allCases) { option in
                    Button { selection = option } label: {
                        VStack(spacing: 8) {
                            if showNames { Text(option.rawValue).ledgeFont(11, .semibold) }
                            Image(systemName: symbol(option)).ledgeFont(26).frame(height: 40)
                            Circle().frame(width: 4, height: 4).opacity(selection == option ? 1 : 0)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.rawValue)
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
                }
            }
            .frame(height: 110)
            .background(
                LinearGradient(colors: [Color(white: 0.34), Color(white: 0.06), Color(white: 0.04), Color(white: 0.28)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: look.r(18), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: look.r(18), style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: look.border))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
            .animation(.smooth, value: selection)
        }
    }
}

/// Row of equal buttons showing a symbol (Left Button) or the option name (Glass Style).
struct ChoiceButtons<T: Choice>: View {
    var title: String
    @Binding var selection: T
    var symbol: ((T) -> String)?
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).ledgeFont(13, .medium)
            HStack(spacing: 10) {
                ForEach(T.allCases) { option in
                    let selected = selection == option
                    Button { selection = option } label: {
                        Group {
                            if let symbol {
                                Image(systemName: symbol(option)).ledgeFont(17, .semibold)
                            } else {
                                Text(option.rawValue).ledgeFont(12, .medium)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: symbol == nil ? 42 : 48)
                        .background(selected ? Color.white.opacity(0.16) : Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: look.r(12), style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: look.r(12), style: .continuous).strokeBorder(.white.opacity(selected ? 0.4 : 0.08), lineWidth: look.border))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.rawValue)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .animation(.smooth, value: selection)
        }
    }
}

/// Five vertical sliders: Sub, Low, Mid, Pres, Air.
struct EqualizerView: View {
    @AppStorage(K.eqSub.rawValue) private var sub = 0.0
    @AppStorage(K.eqLow.rawValue) private var low = 0.0
    @AppStorage(K.eqMid.rawValue) private var mid = 0.0
    @AppStorage(K.eqPres.rawValue) private var pres = 0.0
    @AppStorage(K.eqAir.rawValue) private var air = 0.0

    var body: some View {
        HStack {
            band("Sub", $sub)
            band("Low", $low)
            band("Mid", $mid)
            band("Pres", $pres)
            band("Air", $air)
        }
        .padding(.vertical, 6)
    }

    private func band(_ name: String, _ value: Binding<Double>) -> some View {
        VStack(spacing: 6) {
            // SwiftUI has no vertical slider; a rotated one keeps keyboard and VoiceOver support.
            Slider(value: value, in: -12...12, step: 1) { Text(name) }
                .labelsHidden()
                .frame(width: 130)
                .rotationEffect(.degrees(-90))
                .frame(width: 30, height: 130)
                .accessibilityLabel("\(name) band")
            Text(value.wrappedValue == 0 ? "0" : String(format: "%+.0f", value.wrappedValue))
                .ledgeFont(10, digits: true)
                .foregroundStyle(.secondary)
            Text(name).ledgeFont(11, .semibold)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 84 pt avatar and the user's name.
struct ProfileHeader: View {
    var body: some View {
        VStack(spacing: 0) {
            UserBadge(size: 84)
            Text(NSFullUserName()).ledgeFont(16, .bold).padding(.top, 11)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 30)
    }
}

/// Reads and writes the real login item, so it is not part of Reset All Settings.
struct LaunchAtLoginToggle: View {
    @State private var on = SMAppService.mainApp.status == .enabled
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ToggleRow("Launch at Login", isOn: Binding(get: { on }, set: { newValue in
                do {
                    try newValue ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    on = newValue
                    failure = nil
                } catch {
                    // Happens when run with `swift run` instead of from a signed .app bundle.
                    failure = error.localizedDescription
                }
            }))
            if let failure { Hint(failure) }
        }
    }
}

/// Where the Apple Style slider will sit on screen.
struct EdgePreview: View {
    var edge: ScreenEdge
    var height: Double

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.3), Color(white: 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing))
            EdgeSlider(symbol: "speaker.wave.2.fill", level: 0.62)
                .scaleEffect(0.56)
                .position(x: edge == .left ? 24 : geo.size.width - 24,
                          y: 16 + 37 + (geo.size.height - 74 - 32) * height)
        }
        .frame(height: 170)
        .animation(.smooth, value: edge)
        .animation(.smooth, value: height)
        .accessibilityElement()
        .accessibilityLabel("Preview: slider on the \(edge.rawValue.lowercased()) edge")
    }
}

/// shortcut: fixed sample data until WeatherKit is wired.
struct WeatherPreview: View {
    private let hours = [("18", "29°"), ("19", "27°"), ("20", "26°"), ("21", "25°"), ("22", "24°")]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your City").ledgeFont(14, .semibold)
                    Text("30°").ledgeFont(38, .regular)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "sun.max.fill").ledgeFont(18).foregroundStyle(.yellow)
                    Text("Mostly Clear")
                    Text("UV 0")
                    Text("H:33° L:21°")
                }
                .ledgeFont(10, .semibold)
            }
            Spacer(minLength: 0)
            HStack {
                ForEach(hours, id: \.0) { item in
                    VStack(spacing: 5) {
                        Text(item.0).ledgeFont(9, .semibold).foregroundStyle(.secondary)
                        Image(systemName: "moon.fill").ledgeFont(13)
                        Text(item.1).ledgeFont(13, .semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
        .frame(height: 205)
        .foregroundStyle(.white)
        .background(LinearGradient(colors: [Color(white: 0.4), Color(white: 0.12), Color(white: 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.bottom, 18)
    }
}

struct LockPreview: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("17:44").ledgeFont(44, .heavy, design: .rounded)
            RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.55)).frame(width: 100, height: 44)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .foregroundStyle(.white.opacity(0.9))
        .background(RadialGradient(colors: [Color(white: 0.42), Color(white: 0.07)], center: UnitPoint(x: 0.7, y: 0.4), startRadius: 0, endRadius: 280),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.bottom, 18)
        .accessibilityElement()
        .accessibilityLabel("Lock screen preview")
    }
}

/// Centered "Coming Soon" page.
struct ComingSoon: View {
    var symbol: String
    var text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).ledgeFont(34, .light).foregroundStyle(.secondary)
            Text("Coming Soon").ledgeFont(16, .semibold).foregroundStyle(.secondary)
            Text(text).ledgeFont(11).foregroundStyle(.tertiary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 80)
    }
}
