import SwiftUI

/// The pill: closed (artwork + waveform), an overlay, or the open player.
/// Sizes are measured from the reference screenshots (1440 × 900 pt MacBook without a notch).
struct NotchView: View {
    @ObservedObject var player: PlayerModel
    @ObservedObject var notch: NotchController
    /// Physical notch, or nil on Macs without one; the pill then floats as a capsule.
    let notchSize: CGSize?

    @AppStorage(K.expandOnHover.rawValue) private var expandOnHover = true
    @AppStorage(K.hoverDelay.rawValue) private var hoverDelay = 0.0
    @AppStorage(K.notchWidth.rawValue) private var tuneWidth = 0.0
    @AppStorage(K.notchHeight.rawValue) private var tuneHeight = 0.0
    @AppStorage(K.mediaPlayer.rawValue) private var mediaPlayer = true
    @AppStorage(K.liquidGlass.rawValue) private var liquidGlass = true
    @Environment(\.look) private var look

    @State private var hoverTask: Task<Void, Never>?

    private var open: Bool { notch.expanded && mediaPlayer }
    private var floating: Bool { notchSize == nil }
    // Closed capsule without a notch: 74 pt middle + 34 pt each side = 142 × 24 pt.
    private var baseWidth: CGFloat { (notchSize?.width ?? 74) + tuneWidth }
    private var baseHeight: CGFloat { (notchSize?.height ?? 24) + tuneHeight }
    /// Open player content starts 20 pt down, or just under a physical notch.
    private var topInset: CGFloat { floating ? 20 : baseHeight + 8 }

    private var size: CGSize {
        if open { return CGSize(width: floating ? 318 : max(318, baseWidth + 120), height: topInset + 155) }
        let side: CGFloat = notch.hud?.sideWidth ?? (mediaPlayer ? 34 : 0)
        return CGSize(width: baseWidth + side * 2, height: baseHeight)
    }

    private var shape: UnevenRoundedRectangle {
        let bottom: CGFloat = open ? look.r(28) : (floating ? baseHeight / 2 : look.r(12))
        let top: CGFloat = floating ? bottom : 0
        return UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(topLeading: top, bottomLeading: bottom, bottomTrailing: bottom, topTrailing: top),
            style: .continuous)
    }

    var body: some View {
        ZStack(alignment: .top) {
            if open {
                PlayerCardContent(player: player, art: 56, artGap: 17, timeInset: 4, topInset: topInset)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            } else if let hud = notch.hud {
                HUDContent(hud: hud)
                    .padding(.horizontal, 10)
                    .frame(height: size.height)
                    .transition(.opacity)
            } else if mediaPlayer {
                CollapsedPill(player: player, height: baseHeight)
                    .frame(height: size.height)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .background { background }
        .clipShape(shape)
        .overlay { shape.stroke(.white.opacity(floating || (open && liquidGlass) ? 0.12 : 0), lineWidth: look.border) }
        .shadow(color: .black.opacity(open ? 0.4 : 0), radius: 20, y: 8)
        .contentShape(Rectangle())
        // Buttons inside take their own taps; a tap anywhere else opens or closes the player.
        .onTapGesture { notch.expanded.toggle() }
        .onHover(perform: hover)
        .padding(.top, floating ? (open ? 2.5 : 3) : 0)
        // Closed Pill Size before hover, Interface Size once open; both grow from the top centre so they stay lined up.
        .scaleEffect(open ? look.uiScale : look.pillScale, anchor: .top)
        .opacity(notch.isHidden ? 0 : 1)
        .allowsHitTesting(!notch.isHidden)
        .frame(width: NotchController.canvas.width, height: NotchController.canvas.height, alignment: .top)
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: open)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: notch.hud)
        .animation(.smooth(duration: 0.4), value: notch.isHidden)
        .environment(\.colorScheme, .dark)
    }

    /// Black while closed; dark glass (Clear ↔ Dark slider) when open.
    @ViewBuilder private var background: some View {
        let showGlass = open && liquidGlass
        ZStack(alignment: .top) {
            if liquidGlass {
                Color.clear.glass(in: shape, tint: .black.opacity(look.glassDarkness))
            }
            Color.black.opacity(showGlass ? 0 : 1)
            if !floating {
                // The strip beside a physical notch stays black so the pill still reads as part of it.
                LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: baseHeight + 14)
            }
        }
    }

    private func hover(_ inside: Bool) {
        hoverTask?.cancel()
        guard expandOnHover else { return }
        hoverTask = Task { @MainActor in
            // Settings slider 0...10 maps to 0...1 s before the pill opens.
            if inside { try? await Task.sleep(for: .milliseconds(Int(hoverDelay * 100))) }
            guard !Task.isCancelled else { return }
            notch.expanded = inside
        }
    }
}

/// Closed pill: artwork 5 pt in from the left, waveform 7 pt in from the right.
struct CollapsedPill: View {
    @ObservedObject var player: PlayerModel
    var height: CGFloat

    var body: some View {
        HStack {
            Artwork(size: height - 10, corner: (height - 10) * 0.28)
            Spacer()
            WaveformBars(playing: player.isPlaying, height: height * 0.32, barWidth: 2, spacing: 1.25)
        }
        .padding(.leading, 5)
        .padding(.trailing, 7)
    }
}

/// Player layout shared by the open notch (318 × 175) and the lock-screen mini card (330 × 178).
struct PlayerCardContent: View {
    @ObservedObject var player: PlayerModel
    var art: CGFloat
    var artGap: CGFloat
    var timeInset: CGFloat
    var topInset: CGFloat = 20
    var onArtwork: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: artGap) {
                artwork
                VStack(alignment: .leading, spacing: 1) {
                    Text(player.title).ledgeFont(13, .semibold)
                    Text(player.artist).ledgeFont(13).foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .padding(.bottom, 5)
                .padding(.trailing, 30)
                Spacer(minLength: 0)
            }
            .overlay(alignment: .topTrailing) {
                WaveformBars(playing: player.isPlaying, height: 13)
                    .padding(.top, 20)
                    .padding(.trailing, 6)
            }
            ProgressRow(player: player)
                .padding(.horizontal, timeInset)
                .padding(.top, 12)
            TransportControls(player: player)
                .padding(.top, 16)
        }
        .padding(EdgeInsets(top: topInset, leading: 20, bottom: 22, trailing: 20))
        .foregroundStyle(.white)
    }

    @ViewBuilder private var artwork: some View {
        if let onArtwork {
            Button(action: onArtwork) { Artwork(size: art, corner: art * 0.22) }
                .buttonStyle(.plain)
                .accessibilityLabel("Show artwork")
        } else {
            Artwork(size: art, corner: art * 0.22)
        }
    }
}

// MARK: - Pieces shared by the notch and the lock screen

/// Times are 9 pt, the bar is 6 pt thick.
struct ProgressRow: View {
    @ObservedObject var player: PlayerModel
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 7) {
            Text(PlayerModel.clock(player.elapsed))
            Capsule()
                .fill(.white.opacity(0.18))
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule().fill(look.accent ?? Color.white.opacity(0.55)).frame(width: geo.size.width * player.progress)
                    }
                }
                .frame(height: 6)
                .accessibilityElement()
                .accessibilityLabel("Progress")
                .accessibilityValue("\(Int(player.progress * 100)) percent")
            Text("-" + PlayerModel.clock(player.duration - player.elapsed))
        }
        .ledgeFont(9, .semibold, digits: true)
        .foregroundStyle(.secondary)
        .frame(height: 12)
        .animation(.linear(duration: 1), value: player.elapsed)
    }
}

/// Five 36 pt slots spread evenly; icons 20 pt, play/pause 26 pt.
struct TransportControls: View {
    @ObservedObject var player: PlayerModel
    @AppStorage(K.leftButton.rawValue) private var leftButton = LeftButton.like
    @State private var showOutputs = false

    var body: some View {
        HStack(spacing: 0) {
            left.frame(width: 36, height: 36)
            Spacer()
            Button { player.previous() } label: { Image(systemName: "backward.fill").frame(width: 36, height: 36) }
                .accessibilityLabel("Previous track")
            Spacer()
            Button { player.togglePlay() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .ledgeFont(26)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            Spacer()
            Button { player.next() } label: { Image(systemName: "forward.fill").frame(width: 36, height: 36) }
                .accessibilityLabel("Next track")
            Spacer()
            Button { showOutputs.toggle() } label: {
                Image(systemName: "laptopcomputer").foregroundStyle(.secondary).frame(width: 36, height: 36)
            }
            .accessibilityLabel("Audio output")
            .popover(isPresented: $showOutputs, arrowEdge: .bottom) { OutputList(player: player) }
        }
        .buttonStyle(.plain)
        .ledgeFont(20)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var left: some View {
        switch leftButton {
        case .like:
            Button { player.isLiked.toggle() } label: {
                Image(systemName: "heart.fill")
                    .foregroundStyle(player.isLiked ? Color.pink : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(player.isLiked ? "Unlike" : "Like")
        case .none:
            Color.clear
        default:
            // shortcut: shuffle/repeat are visual only until the player API is wired.
            Button {} label: { Image(systemName: leftButton.symbol).foregroundStyle(.secondary).frame(width: 36, height: 36) }
                .accessibilityLabel(leftButton.rawValue)
        }
    }
}

struct OutputList: View {
    @ObservedObject var player: PlayerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Output").ledgeFont(11, .semibold).foregroundStyle(.secondary).padding(.horizontal, 8)
            ForEach(player.outputs, id: \.self) { name in
                Button { player.output = name } label: {
                    HStack {
                        Image(systemName: "laptopcomputer")
                        Text(name)
                        Spacer()
                        Image(systemName: "checkmark").opacity(player.output == name ? 1 : 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(player.output == name ? .isSelected : [])
            }
        }
        .padding(8)
        .frame(width: 220)
        .animation(.smooth, value: player.output)
    }
}

/// shortcut: gradient placeholder until real album art arrives with the player API.
struct Artwork: View {
    var size: CGFloat
    var corner: CGFloat
    @Environment(\.look) private var look

    var body: some View {
        RoundedRectangle(cornerRadius: look.r(corner), style: .continuous)
            .fill(LinearGradient(colors: [.orange, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(Image(systemName: "music.note").ledgeFont(size * 0.4, .semibold).foregroundStyle(.white))
            .accessibilityHidden(true)
    }
}

/// Five bars that move while music plays (about 22 × 13 pt in the player).
struct WaveformBars: View {
    var playing: Bool
    var height: CGFloat
    var barWidth: CGFloat = 2.5
    var spacing: CGFloat = 2.25
    @Environment(\.look) private var look

    var body: some View {
        TimelineView(.animation(paused: !playing)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: spacing) {
                ForEach(0..<5, id: \.self) { i in
                    Capsule().frame(width: barWidth, height: playing ? height * (0.35 + 0.65 * abs(sin(t * 3 + Double(i) * 1.3))) : height * 0.3)
                }
            }
            .frame(height: height)
        }
        .foregroundStyle(look.accent ?? Color.white.opacity(0.8))
        .accessibilityHidden(true)
    }
}

// PreviewProvider instead of #Preview: the macro plugin ships only with Xcode, not the command-line tools.
struct NotchView_Previews: PreviewProvider {
    @MainActor static var previews: some View {
        let player = PlayerModel()
        let notch = NotchController(player: player)
        notch.expanded = true
        return NotchView(player: player, notch: notch, notchSize: nil)
            .withLook()
            .background(.gray)
    }
}
