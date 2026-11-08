import Collaboration
import SwiftUI

/// Lock screen player: small controller first; the thumbnail opens the artwork view, the side buttons add lyrics or hide the player.
/// Positions are fractions of the reference 1440 × 900 pt screen so the preview window can be any size.
struct LockScreenPlayerView: View {
    @ObservedObject var player: PlayerModel
    @ObservedObject private var weather = WeatherModel.shared
    @Environment(\.look) private var look
    @State private var mode = Mode.mini
    @State private var lyricsOn = false

    enum Mode { case mini, artwork, hidden }

    private var artwork: Bool { mode == .artwork }
    private var motion: Animation { .spring(response: 0.6, dampingFraction: 0.86) }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack(alignment: .top) {
                LinearGradient(colors: [Color(white: 0.26), Color(white: 0.06)], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [.orange.opacity(0.4), .clear], center: UnitPoint(x: 0.25, y: 0.55), startRadius: 0, endRadius: 700)
                    .opacity(artwork ? 1 : 0)

                header.padding(.top, h * 0.085)
                stage(height: h)
                    .scaleEffect(look.uiScale, anchor: .top)  // Appearance › Interface Size
                login
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, h * 0.05)
                    .opacity(artwork ? 0 : 1)
                    .offset(y: artwork ? 16 : 0)
            }
            .overlay(alignment: .topLeading) { sideButtons.padding(29) }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .animation(motion, value: mode)
        .animation(motion, value: lyricsOn)
    }

    private var header: some View {
        VStack(spacing: 0) {
            TimelineView(.everyMinute) { context in
                VStack(spacing: 0) {
                    Text(context.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .ledgeFont(24, .medium)
                    Text(context.date, format: .dateTime.hour().minute())
                        .ledgeFont(128, .heavy, design: .rounded)
                        .monospacedDigit()
                }
            }
            .foregroundStyle(.white.opacity(0.8))
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
            MiniPlayerCard(player: player) { mode = .artwork }
                .padding(.top, h * 0.575)
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
        case .artwork:
            HStack(alignment: .center, spacing: lyricsOn ? 166 : 0) {
                VStack(spacing: 42) {
                    Button {
                        lyricsOn = false
                        mode = .mini
                    } label: {
                        Artwork(size: 386, corner: 16, image: player.artwork).shadow(color: .black.opacity(0.4), radius: 30, y: 20)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to mini player")
                    GlassPlayerCard(player: player)
                }
                if lyricsOn {
                    LyricsColumn(player: player)
                        .frame(width: 540, alignment: .leading)
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
            RoundButton(symbol: "quote.bubble", label: "Show lyrics", isOn: artwork && lyricsOn) {
                if artwork && lyricsOn {
                    lyricsOn = false
                } else {
                    mode = .artwork
                    lyricsOn = true
                }
            }
            RoundButton(symbol: "eye.slash", label: "Hide player", isOn: mode == .hidden) {
                lyricsOn = false
                mode = mode == .hidden ? .mini : .hidden
            }
        }
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
            .glass(in: RoundedRectangle(cornerRadius: look.r(28), style: .continuous), tint: .black.opacity(look.glassDarkness))
            .overlay(RoundedRectangle(cornerRadius: look.r(28), style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: look.border))
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
        .glass(in: RoundedRectangle(cornerRadius: look.r(26), style: .continuous), tint: .white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: look.r(26), style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: look.border))
    }
}

/// Current line bright; the others dim, and the far ones blurred.
struct LyricsColumn: View {
    @ObservedObject var player: PlayerModel

    var body: some View {
        // Five lines around the current one; a click jumps the song to that line.
        let window = player.lyrics.indices.filter { abs($0 - player.lyricIndex) <= 2 }
        VStack(alignment: .leading, spacing: 40) {
            if player.lyrics.isEmpty {
                Text(player.hasTrack ? "No synced lyrics for this song" : "Nothing playing")
                    .ledgeFont(24, .semibold)
                    .foregroundStyle(.white.opacity(0.4))
            }
            ForEach(window, id: \.self) { i in
                let distance = abs(i - player.lyricIndex)
                Button { player.seekToLyric(i) } label: {
                    Text(player.lyrics[i])
                        .ledgeFont(30, distance == 0 ? .bold : .semibold)
                        .foregroundStyle(.white.opacity(distance == 0 ? 1 : distance == 1 ? 0.4 : 0.25))
                        .blur(radius: distance >= 2 ? 2 : 0)
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
