import Foundation

struct Prayer: Identifiable, Equatable {
    let name: String
    let time: Date
    var id: String { name }
}

/// Today's prayer times from aladhan.com (free, no key) for the weather location.
/// shortcut: always the Kemenag (Indonesia) method, method 20; add a picker if you travel to places that use another one.
@MainActor
final class PrayerModel: ObservableObject {
    static let shared = PrayerModel()

    @Published private(set) var prayers: [Prayer] = []
    @Published private(set) var sunrise: Date?

    private var coordinate: (latitude: Double, longitude: Double)?
    private var loadedDay = ""
    private var timer: Timer?

    /// Called by WeatherModel whenever it learns where you are.
    func update(latitude: Double, longitude: Double) {
        coordinate = (latitude, longitude)
        Task { await load() }
        guard timer == nil else { return }
        // A new day needs new times.
        timer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, Self.dayKey(Date()) != self.loadedDay else { return }
                await self.load()
            }
        }
    }

    private func load() async {
        guard let coordinate else { return }
        let day = Date()
        var components = URLComponents(string: "https://api.aladhan.com/v1/timings/\(Self.dayKey(day))")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "method", value: "20"),
        ]
        guard let url = components?.url,
              let result = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: result.0) as? [String: Any],
              let data = json["data"] as? [String: Any],
              let timings = data["timings"] as? [String: String]
        else { return }
        let names = [("Subuh", "Fajr"), ("Dzuhur", "Dhuhr"), ("Ashar", "Asr"), ("Maghrib", "Maghrib"), ("Isya", "Isha")]
        prayers = names.compactMap { pair in
            timings[pair.1].flatMap { Self.time($0, on: day) }.map { Prayer(name: pair.0, time: $0) }
        }
        sunrise = timings["Sunrise"].flatMap { Self.time($0, on: day) }
        loadedDay = Self.dayKey(day)
    }

    nonisolated static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.day, .month, .year], from: date)
        return String(format: "%02d-%02d-%04d", parts.day ?? 1, parts.month ?? 1, parts.year ?? 2000)
    }

    /// "14:56" (or "14:56 (WIB)") as a time on `day`.
    nonisolated static func time(_ text: String, on day: Date, calendar: Calendar = .current) -> Date? {
        let parts = text.prefix(5).split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }

    /// The next prayer after `now`; after Isya, tomorrow's Subuh (today's time plus a day).
    nonisolated static func next(after now: Date, in prayers: [Prayer]) -> Prayer? {
        if let upcoming = prayers.first(where: { $0.time > now }) { return upcoming }
        guard let first = prayers.first else { return nil }
        return Prayer(name: first.name, time: first.time.addingTimeInterval(86_400))
    }

    /// 2 h 44 min, or 12 min.
    nonisolated static func countdown(from now: Date, to time: Date) -> String {
        let minutes = max(0, Int(time.timeIntervalSince(now) / 60))
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }
}
