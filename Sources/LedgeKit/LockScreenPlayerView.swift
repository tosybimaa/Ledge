import AppKit
import Collaboration
import SwiftUI

/// Lock screen player: small controller first; the thumbnail opens the artwork view, the side buttons add lyrics or hide the player.
/// Positions are fractions of the reference 1440 × 900 pt screen so the preview window can be any size.
struct LockScreenPlayerView: View {
    @ObservedObject var player: PlayerModel
    /// On the real lock screen macOS draws the wallpaper and login itself, and its own clock until the blur covers it.
    var onLockScreen = false
    @ObservedObject private var weather = WeatherModel.shared
    @AppStorage(K.lockFullArt.rawValue) private var fullArt = true
    @AppStorage(K.lockLyrics.rawValue) private var lyricsAllowed = true
    @Environment(\.look) private var look
    @State private var mode = Mode.mini
    @State private var lyricsOn = false

    enum Mode { case mini, artwork, hidden }

    private var artwork: Bool { mode == .artwork }
    private var showsPlayer: Bool { !onLockScreen || player.hasTrack }
    private var motion: Animation { .spring(response: 0.6, dampingFraction: 0.86) }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack(alignment: .top) {
                if onLockScreen {
                    // Artwork view: the whole lock screen blurred, wallpaper and macOS's clock included.
                    BehindWindowBlur()
                        .overlay(Color.black.opacity(0.3))
                        .opacity(artwork ? 1 : 0)
                } else {
                    LinearGradient(colors: [Color(white: 0.26), Color(white: 0.06)], startPoint: .top, endPoint: .bottom)
                }

                if showsPlayer {
                    stage(height: h)
                        .scaleEffect(look.uiScale, anchor: .top)  // Appearance › Interface Size
                }
                header
                    .padding(.top, h * 0.089)
                    .allowsHitTesting(false)  // drawn over the stage; clicks go through to the artwork
                if !onLockScreen {
                    login
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, h * 0.05)
                        .opacity(artwork ? 0 : 1)
                        .offset(y: artwork ? 16 : 0)
                }
            }
            .overlay(alignment: .topLeading) {
                if showsPlayer { sideButtons.padding(29) }
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .animation(motion, value: mode)
        .animation(motion, value: lyricsOn)
    }

    private var header: some View {
        VStack(spacing: 0) {
            // On the lock screen macOS's own clock shows until the blur covers it; this one then takes its place.
            // The space is kept so the weather row lines up under either clock.
            LockClock()
                .opacity(onLockScreen && !artwork ? 0 : 1)
            HStack(spacing: 24) {
                if let temperature = weather.temperature {
                    Label("\(temperature)°", systemImage: weather.symbol)
                }
                if let battery = Battery.status() {
                    Label("\(battery.percent)%", systemImage: battery.charging ? "bolt.fill" : "battery.75percent")
                }
            }
            .ledgeFont(20, .semibold)
            .opacity(artwork ? 0 : 1)
        }
    }

    @ViewBuilder private func stage(height h: CGFloat) -> some View {
        switch mode {
        case .mini:
            MiniPlayerCard(player: player) { if fullArt { mode = .artwork } }
                .padding(.top, h * 0.575)
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
        case .artwork:
            HStack(alignment: .center, spacing: lyricsOn ? 120 : 0) {
                VStack(spacing: 42) {
                    Button {
                        lyricsOn = false
                        mode = .mini
                    } label: {
                        Artwork(size: 386, corner: 16, image: player.artwork)
                            .overlay { GlassArtSheen(corner: 16) }
                            .shadow(color: .black.opacity(0.4), radius: 30, y: 20)
                            .background {
                                // The warm light behind the artwork.
                                RadialGradient(colors: [.orange.opacity(0.4), .clear], center: .center, startRadius: 0, endRadius: 520)
                                    .frame(width: 1100, height: 1100)
                                    .allowsHitTesting(false)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to mini player")
                    GlassPlayerCard(player: player)
                }
                if lyricsOn {
                    LyricsColumn(player: player)
                        .frame(width: 620, alignment: .leading)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.top, h * 0.3)
            .transition(.opacity.combined(with: .scale(scale: 0.94)))
        case .hidden:
            EmptyView()
        }
    }

    private var login: some View {
        VStack(spacing: 10) {
            UserBadge(size: 44)
            Text(NSFullUserName()).ledgeFont(17, .semibold)
            Text("Touch ID or Enter Password").ledgeFont(13, .medium).foregroundStyle(.white.opacity(0.7))
        }
    }

    /// Two 36 pt circles, 29 pt from the corner, 6 pt apart.
    private var sideButtons: some View {
        VStack(spacing: 6) {
            if lyricsAllowed {
                RoundButton(symbol: "quote.bubble", label: "Show lyrics", isOn: artwork && lyricsOn) {
                    if artwork && lyricsOn {
                        lyricsOn = false
                    } else {
                        mode = .artwork
                        lyricsOn = true
                    }
                }
            }
            RoundButton(symbol: "eye.slash", label: "Hide player", isOn: mode == .hidden) {
                lyricsOn = false
                mode = mode == .hidden ? .mini : .hidden
            }
        }
    }
}

/// Drawn like macOS's own lock screen clock (sizes measured from it on a 1440 × 900 screen),
/// so nothing seems to change when the blur covers the real one. System font on purpose: Appearance › Font leaves it alone.
private struct LockClock: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            let date = context.date
            VStack(spacing: -20) {
                // "Mon 9 Nov", without the comma the standard format adds.
                Text([date.formatted(.dateTime.weekday(.abbreviated)), date.formatted(.dateTime.day()),
                      date.formatted(.dateTime.month(.abbreviated))].joined(separator: " "))
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                    .font(.system(size: 130, weight: .bold))
                    .tracking(-4)
                    .foregroundStyle(LinearGradient(colors: [.white.opacity(0.78), .white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// 330 × 178 pt card: 60 pt artwork, 20 pt insets.
struct MiniPlayerCard: View {
    @ObservedObject var player: PlayerModel
    @Environment(\.look) private var look
    var openArtwork: () -> Void

    var body: some View {
        PlayerCardContent(player: player, art: 60, artGap: 21, timeInset: 10, onArtwork: openArtwork)
            .frame(width: 330)
            .lockCardBackground(cornerRadius: look.r(28), border: look.border, glassDarkness: look.glassDarkness)
    }
}

extension View {
    /// Settings › Lock Screen: Glass Card off = solid dark card; Glass Style Clear = see-through, Frosted = darker glass.
    func lockCardBackground(cornerRadius: CGFloat, border: CGFloat, glassDarkness: Double) -> some View {
        modifier(LockCardBackground(cornerRadius: cornerRadius, border: border, glassDarkness: glassDarkness))
    }
}

private struct LockCardBackground: ViewModifier {
    var cornerRadius: CGFloat
    var border: CGFloat
    var glassDarkness: Double
    @AppStorage(K.lockGlassCard.rawValue) private var glassCard = true
    @AppStorage(K.lockGlass.rawValue) private var style = GlassStyle.frosted

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            if glassCard {
                content.glass(in: shape, tint: .black.opacity(style == .clear ? 0.15 : glassDarkness))
            } else {
                content.background(Color(white: 0.09), in: shape)
            }
        }
        .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: border))
    }
}

/// Settings › Lock Screen › Glass Art: a light glass reflection over the big artwork.
private struct GlassArtSheen: View {
    var corner: CGFloat
    @AppStorage(K.lockGlassArt.rawValue) private var on = false
    @Environment(\.look) private var look

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: look.r(corner), style: .continuous)
        shape
            .fill(LinearGradient(colors: [.white.opacity(0.28), .clear, .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(shape.strokeBorder(.white.opacity(0.3), lineWidth: 1))
            .opacity(on ? 1 : 0)
            .allowsHitTesting(false)
    }
}

/// 330 × 133 pt card under the big artwork.
struct GlassPlayerCard: View {
    @ObservedObject var player: PlayerModel
    @Environment(\.look) private var look

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 1) {
                Text(player.title).ledgeFont(12.5, .semibold)
                Text(player.artist).ledgeFont(11).foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .padding(.horizontal, 44)
            ProgressRow(player: player)
                .padding(.horizontal, 8)
                .padding(.top, 13)
            TransportControls(player: player)
                .padding(.top, 13)
        }
        .overlay(alignment: .topTrailing) {
            WaveformBars(playing: player.isPlaying, height: 11, barWidth: 2, spacing: 2)
        }
        .padding(EdgeInsets(top: 16, leading: 20, bottom: 13, trailing: 20))
        .frame(width: 330)
        .lockCardBackground(cornerRadius: look.r(26), border: look.border, glassDarkness: look.glassDarkness * 0.5)
    }
}

/// Current line bright; the others dim, and the far ones blurred.
struct LyricsColumn: View {
    @ObservedObject var player: PlayerModel

    var body: some View {
        // Five lines around the current one; a click jumps the song to that line.
        let window = player.lyrics.indices.filter { abs($0 - player.lyricIndex) <= 2 }
        VStack(alignment: .leading, spacing: 44) {
            if player.lyrics.isEmpty {
                Text(player.hasTrack ? "No synced lyrics for this song" : "Nothing playing")
                    .ledgeFont(30, .semibold)
                    .foregroundStyle(.white.opacity(0.4))
            }
            ForEach(window, id: \.self) { i in
                let distance = abs(i - player.lyricIndex)
                Button { player.seekToLyric(i) } label: {
                    Text(player.lyrics[i])
                        .ledgeFont(36, distance == 0 ? .bold : .semibold)
                        .foregroundStyle(.white.opacity(distance == 0 ? 1 : distance == 1 ? 0.4 : 0.25))
                        .blur(radius: distance == 0 ? 0 : distance == 1 ? 1.5 : 5)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(distance == 0 ? .isSelected : [])
            }
        }
        .animation(.smooth(duration: 0.5), value: player.lyricIndex)
    }
}

struct RoundButton: View {
    var symbol: String
    var label: String
    var isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .ledgeFont(13, .semibold)
                .frame(width: 36, height: 36)
                .background(Circle().fill(.white.opacity(isOn ? 0.26 : 0.1)))
                .overlay(Circle().strokeBorder(.white.opacity(0.2)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .animation(.smooth, value: isOn)
    }
}

/// Initials of the Mac's user in a circle.
/// Blurs whatever is behind the window (here: the lock screen wallpaper).
private struct BehindWindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.appearance = NSAppearance(named: .darkAqua)  // dark blur, not the grey wash of the light variant
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// Your macOS account picture (System Settings › Users & Groups); initials if there is none.
struct UserBadge: View {
    var size: CGFloat

    private static let picture = CBIdentity(name: NSUserName(), authority: .local())?.image

    private var initials: String {
        NSFullUserName().split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }

    var body: some View {
        Group {
            if let picture = Self.picture {
                Image(nsImage: picture).resizable().aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [.blue, .indigo], startPoint: .top, endPoint: .bottom)
                    .overlay(Text(initials).ledgeFont(size * 0.36, .bold).foregroundStyle(.white))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

struct LockScreenPlayerView_Previews: PreviewProvider {
    @MainActor static var previews: some View {
        LockScreenPlayerView(player: PlayerModel(preview: true))
            .withLook()
            .frame(width: 1440, height: 900)
    }
}
