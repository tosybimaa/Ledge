import SwiftUI

/// Pages of the open pill. The player is always first; the others are switched on in Settings › Media › Notch Pages.
enum NotchPage: String {
    case player, lyrics, prayer, calendar
}

/// Lyrics page: the player on the left, the lines around the current one on the right.
struct LyricsPage: View {
    @ObservedObject var player: PlayerModel
    var topInset: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            PlayerCardContent(player: player, art: 56, artGap: 17, timeInset: 4, topInset: topInset)
                .frame(width: 300)
            Rectangle().fill(.white.opacity(0.12)).frame(width: 1)
                .padding(.top, topInset).padding(.bottom, 26)
            NotchLyrics(player: player)
                .padding(EdgeInsets(top: topInset, leading: 20, bottom: 26, trailing: 28))
        }
    }
}

struct NotchLyrics: View {
    @ObservedObject var player: PlayerModel

    var body: some View {
        let lines = player.lyrics.indices.filter { abs($0 - player.lyricIndex) <= 1 }
        VStack(alignment: .leading, spacing: 10) {
            if player.lyrics.isEmpty {
                Text(player.hasTrack ? "No synced lyrics for this song" : "Nothing playing")
                    .ledgeFont(13, .semibold).foregroundStyle(.secondary)
            }
            ForEach(lines, id: \.self) { i in
                let current = i == player.lyricIndex
                Text(player.lyrics[i])
                    .ledgeFont(current ? 15 : 13, current ? .bold : .semibold)
                    .foregroundStyle(.white.opacity(current ? 1 : 0.4))
                    .blur(radius: current ? 0 : 1)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .animation(.smooth(duration: 0.4), value: player.lyricIndex)
    }
}

/// Prayer page: the next prayer and a countdown, and the day as an arc with the sun moving along it.
struct PrayerPage: View {
    @ObservedObject private var prayer = PrayerModel.shared
    @ObservedObject private var weather = WeatherModel.shared
    var topInset: CGFloat

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Prayer").ledgeFont(13, .bold)
                        Text(weather.city).ledgeFont(11).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Text("Next").ledgeFont(11, .semibold).foregroundStyle(.secondary).padding(.top, 8)
                    if let next = PrayerModel.next(after: now, in: prayer.prayers) {
                        Text(next.name).ledgeFont(26, .bold)
                        HStack(spacing: 6) {
                            Text(next.time, format: .dateTime.hour().minute()).ledgeFont(13, .semibold, digits: true)
                            Text("in " + PrayerModel.countdown(from: now, to: next.time)).ledgeFont(12).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Needs your location (Weather on)").ledgeFont(12).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 170, alignment: .leading)
                SunArc(prayers: prayer.prayers, now: now)
            }
            .padding(EdgeInsets(top: topInset, leading: 24, bottom: 24, trailing: 24))
        }
        .foregroundStyle(.white)
    }
}

/// The day from Subuh to Isya as an arc; the part already passed is drawn in the accent color.
struct SunArc: View {
    var prayers: [Prayer]
    var now: Date
    @Environment(\.look) private var look

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height - 30
            if let first = prayers.first?.time, let last = prayers.last?.time, last > first {
                let span = last.timeIntervalSince(first)
                let x: (Date) -> CGFloat = { CGFloat(min(max($0.timeIntervalSince(first) / span, 0), 1)) * width }
                let y: (CGFloat) -> CGFloat = { height - sin($0 / max(width, 1) * .pi) * (height - 8) }
                let arc: (CGFloat) -> Path = { end in
                    Path { path in
                        for step in 0...60 {
                            let px = end * CGFloat(step) / 60
                            let point = CGPoint(x: px, y: y(px))
                            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
                        }
                    }
                }
                ZStack(alignment: .topLeading) {
                    arc(width).stroke(.white.opacity(0.22), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    arc(x(now)).stroke(look.accent ?? Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    ForEach(prayers) { item in
                        let px = x(item.time)
                        Circle().fill(item.time <= now ? (look.accent ?? Color.blue) : Color.white.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .position(x: px, y: y(px))
                        VStack(spacing: 1) {
                            Text(item.name).ledgeFont(9, .semibold)
                            Text(item.time, format: .dateTime.hour().minute()).ledgeFont(9, digits: true).foregroundStyle(.secondary)
                        }
                        .fixedSize()
                        .position(x: px, y: height + 17)
                    }
                    Circle().fill(.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: .white.opacity(0.8), radius: 6)
                        .position(x: x(now), y: y(x(now)))
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Sun position through the day")
    }
}

/// Calendar page: this week with today marked, and your next events.
struct CalendarPage: View {
    @ObservedObject private var calendar = CalendarModel.shared
    @Environment(\.look) private var look
    var topInset: CGFloat

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let today = Calendar.current.startOfDay(for: now)
            let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            let days = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
            let upcoming = calendar.events.filter { $0.allDay ? $0.start >= today : $0.start >= now }.prefix(3)
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("This week").ledgeFont(13, .bold)
                    HStack(spacing: 5) {
                        ForEach(days, id: \.self) { day in
                            let isToday = Calendar.current.isDate(day, inSameDayAs: today)
                            VStack(spacing: 4) {
                                Text(day, format: .dateTime.weekday(.narrow)).ledgeFont(9, .semibold).foregroundStyle(.secondary)
                                Text(day, format: .dateTime.day()).ledgeFont(12, .semibold, digits: true)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(isToday ? (look.accent ?? Color.blue) : Color.clear))
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 7) {
                    if calendar.denied {
                        Text("Allow Calendar in Settings › General › Permissions").ledgeFont(12).foregroundStyle(.secondary)
                    } else if upcoming.isEmpty {
                        Text("No events this week").ledgeFont(12).foregroundStyle(.secondary)
                    }
                    ForEach(Array(upcoming)) { event in
                        HStack(spacing: 7) {
                            Circle().fill(event.color).frame(width: 6, height: 6)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(event.title).ledgeFont(12, .semibold).lineLimit(1)
                                Group {
                                    if event.allDay {
                                        Text(event.start, format: .dateTime.weekday(.abbreviated)) + Text(" · All day")
                                    } else {
                                        Text(event.start, format: .dateTime.weekday(.abbreviated).hour().minute())
                                    }
                                }
                                .ledgeFont(10).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 24)
            }
            .padding(EdgeInsets(top: topInset, leading: 24, bottom: 24, trailing: 24))
        }
        .foregroundStyle(.white)
        .onAppear { CalendarModel.shared.start() }
    }
}

/// Page dots under the open pill; each dot is a button.
struct PageDots: View {
    var pages: [NotchPage]
    @Binding var index: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(pages.indices, id: \.self) { i in
                Button { index = i } label: {
                    Circle().fill(.white.opacity(i == index ? 0.9 : 0.3)).frame(width: 5, height: 5)
                        .frame(width: 12, height: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(pages[i].rawValue.capitalized + " page")
                .accessibilityAddTraits(i == index ? .isSelected : [])
            }
        }
    }
}
