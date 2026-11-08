import CoreLocation
import Foundation

/// Weather from open-meteo.com (free, no key). Location from Location Services, or from your IP address
/// (ipapi.co) when Settings › Weather › Precise Location is off. Refreshes every 30 minutes.
@MainActor
final class WeatherModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherModel()

    struct Hour: Identifiable {
        let id = UUID()
        let label: String
        let symbol: String
        let temperature: Int
    }

    @Published private(set) var city = ""
    @Published private(set) var temperature: Int?
    @Published private(set) var symbol = "cloud.fill"
    @Published private(set) var condition = ""
    @Published private(set) var high: Int?
    @Published private(set) var low: Int?
    @Published private(set) var uv: Int?
    @Published private(set) var hours: [Hour] = []

    private let location = CLLocationManager()
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        location.delegate = self
        refresh()
        Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        guard UserDefaults.standard.object(forKey: K.weather.rawValue) as? Bool ?? true else { return }
        if UserDefaults.standard.object(forKey: K.preciseLocation.rawValue) as? Bool ?? true {
            location.requestWhenInUseAuthorization()
            location.requestLocation()
        } else {
            Task { await loadFromIP() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let place = locations.last else { return }
        Task { @MainActor in
            await load(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
            if let mark = try? await CLGeocoder().reverseGeocodeLocation(place).first {
                city = mark.locality ?? mark.name ?? ""
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location refused or unavailable: fall back to the IP estimate.
        Task { @MainActor in await loadFromIP() }
    }

    private func loadFromIP() async {
        guard let url = URL(string: "https://ipapi.co/json/"),
              let result = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: result.0) as? [String: Any],
              let latitude = json["latitude"] as? Double,
              let longitude = json["longitude"] as? Double
        else { return }
        city = json["city"] as? String ?? ""
        await load(latitude: latitude, longitude: longitude)
    }

    private func load(latitude: Double, longitude: Double) async {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,uv_index_max"),
            URLQueryItem(name: "forecast_hours", value: "6"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = components?.url,
              let result = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: result.0) as? [String: Any],
              let current = json["current"] as? [String: Any],
              let temp = current["temperature_2m"] as? Double,
              let code = current["weather_code"] as? Int
        else { return }
        let day = (current["is_day"] as? Int ?? 1) == 1
        temperature = Int(temp.rounded())
        symbol = Self.symbol(code: code, day: day)
        condition = Self.condition(code: code)
        if let daily = json["daily"] as? [String: Any] {
            high = (daily["temperature_2m_max"] as? [Double])?.first.map { Int($0.rounded()) }
            low = (daily["temperature_2m_min"] as? [Double])?.first.map { Int($0.rounded()) }
            uv = (daily["uv_index_max"] as? [Double])?.first.map { Int($0.rounded()) }
        }
        if let hourly = json["hourly"] as? [String: Any],
           let times = hourly["time"] as? [String],
           let temps = hourly["temperature_2m"] as? [Double],
           let codes = hourly["weather_code"] as? [Int] {
            let days = hourly["is_day"] as? [Int] ?? []
            let count = min(times.count, temps.count, codes.count)
            // Index 0 is the current hour; show the next five.
            hours = count < 2 ? [] : (1..<count).prefix(5).map { i in
                Hour(label: String(times[i].suffix(5).prefix(2)),
                     symbol: Self.symbol(code: codes[i], day: (days.indices.contains(i) ? days[i] : 1) == 1),
                     temperature: Int(temps[i].rounded()))
            }
        }
    }

    /// WMO weather code to an SF Symbol.
    nonisolated static func symbol(code: Int, day: Bool) -> String {
        switch code {
        case 0: day ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: day ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...57: "cloud.drizzle.fill"
        case 61...67: "cloud.rain.fill"
        case 71...77, 85, 86: "cloud.snow.fill"
        case 80...82: "cloud.heavyrain.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }

    nonisolated static func condition(code: Int) -> String {
        switch code {
        case 0: "Clear"
        case 1: "Mostly Clear"
        case 2: "Partly Cloudy"
        case 3: "Cloudy"
        case 45, 48: "Fog"
        case 51...57: "Drizzle"
        case 61...67: "Rain"
        case 71...77, 85, 86: "Snow"
        case 80...82: "Showers"
        case 95...99: "Thunderstorm"
        default: ""
        }
    }
}
