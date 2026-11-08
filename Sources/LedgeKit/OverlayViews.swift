import SwiftUI

/// Short overlays that grow out of the notch when something changes.
enum NotchHUD: Hashable {
    case charging(Int)
    case volume(Double)
    case brightness(Double)
    case focus(Bool)
    case lock(Bool)
    case accessory(String, Int)
    case output(String)

    /// How far the pill pokes out on each side of the notch.
    var sideWidth: CGFloat {
        switch self {
        case .accessory, .output: 120
        default: 64
        }
    }

    /// Volume and brightness level; these go to the screen edge in Sensory › Apple Style.
    var level: Double? {
        switch self {
        case .volume(let value), .brightness(let value): value
        default: nil
        }
    }

    /// How long it stays, from the Overlay Duration sliders.
    var duration: Double {
        switch self {
        case .volume, .brightness: UserDefaults.standard.double(forKey: K.sensoryDuration.rawValue)
        case .charging: UserDefaults.standard.double(forKey: K.batteryDuration.rawValue)
        case .accessory, .output: UserDefaults.standard.double(forKey: K.accessoryDuration.rawValue)
        default: 3
        }
    }
}

struct HUDContent: View {
    let hud: NotchHUD

    var body: some View {
        HStack {
            Image(systemName: symbol).foregroundStyle(tint)
            Spacer()
            trailing
        }
        .ledgeFont(13, .semibold)
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch hud {
        case .charging: "bolt.fill"
        case .volume: "speaker.wave.2.fill"
        case .brightness: "sun.max.fill"
        case .focus: "moon.fill"
        case .lock(let locked): locked ? "lock.fill" : "lock.open.fill"
        case .accessory: "airpodspro"
        case .output: "laptopcomputer"
        }
    }

    private var tint: Color {
        switch hud {
        case .charging: .green
        case .focus: .purple
        default: .white
        }
    }

    @ViewBuilder private var trailing: some View {
        switch hud {
        case .charging(let percent):
            Text("\(percent)%").foregroundStyle(.green)
        case .volume(let level), .brightness(let level):
            ProgressView(value: level).tint(.white).frame(width: 60)
        case .focus(let on):
            Text(on ? "Focus On" : "Focus Off").foregroundStyle(.purple)
        case .lock(let locked):
            Text(locked ? "Locked" : "Unlocked")
        case .accessory(let name, let percent):
            // -1 while the battery level is still being read.
            Text(percent >= 0 ? "\(name) · \(percent)%" : name).lineLimit(1)
        case .output(let name):
            Text(name).lineLimit(1)
        }
    }
}

/// Sensory "Apple Style": a vertical slider on the edge of the screen.
/// shortcut: view only; placing it on the chosen screen edge is part of the system step.
/// The edge panel's content: an EdgeSlider while a volume or brightness overlay is showing.
struct EdgeHUDView: View {
    @ObservedObject var notch: NotchController

    var body: some View {
        ZStack {
            if let hud = notch.edgeHUD, let level = hud.level {
                EdgeSlider(symbol: hud == .brightness(level) ? "sun.max.fill" : "speaker.wave.2.fill", level: level)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(width: 64, height: 160)
        .animation(.smooth(duration: 0.3), value: notch.edgeHUD)
    }
}

struct EdgeSlider: View {
    var symbol: String
    var level: Double

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(.ultraThinMaterial)
            Rectangle().fill(.white).frame(height: 132 * max(0, min(1, level)))
            Image(systemName: symbol).foregroundStyle(.gray).padding(.bottom, 12)
        }
        .frame(width: 40, height: 132)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.25)))
        .animation(.smooth, value: level)
        .accessibilityElement()
        .accessibilityLabel("Level \(Int(level * 100)) percent")
    }
}

struct OverlayViews_Previews: PreviewProvider {
    static let samples: [NotchHUD] = [.charging(100), .volume(0.6), .brightness(0.8), .focus(true), .lock(true), .accessory("AirPods Pro", 82), .output("MacBook Speakers")]

    static var previews: some View {
        VStack(spacing: 16) {
            ForEach(samples, id: \.self) { hud in
                HUDContent(hud: hud)
                    .padding(.horizontal, 14)
                    .frame(width: 200 + hud.sideWidth * 2, height: 32)
                    .background(.black, in: UnevenRoundedRectangle(bottomLeadingRadius: 16, bottomTrailingRadius: 16))
            }
            HStack(spacing: 40) {
                EdgeSlider(symbol: "speaker.wave.2.fill", level: 0.7)
                EdgeSlider(symbol: "sun.max.fill", level: 0.85)
            }
        }
        .padding(30)
        .background(Color(white: 0.12))
    }
}
