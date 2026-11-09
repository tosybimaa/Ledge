import EventKit
import SwiftUI

/// This week's events from the Calendar app. Asks for permission the first time the calendar page shows.
@MainActor
final class CalendarModel: ObservableObject {
    static let shared = CalendarModel()

    struct Event: Identifiable {
        let id: String
        let title: String
        let start: Date
        let allDay: Bool
        let color: Color
    }

    @Published private(set) var events: [Event] = []
    @Published private(set) var denied = false

    private let store = EKEventStore()
    private var started = false

    func start() {
        // Without the usage text (a `swift run` build) macOS would stop the app on the request.
        guard !started, Bundle.main.object(forInfoDictionaryKey: "NSCalendarsFullAccessUsageDescription") != nil else { return }
        started = true
        Task {
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            denied = !granted
            guard granted else { return }
            reload()
            NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.reload() }
            }
        }
    }

    private func reload() {
        let start = Calendar.current.startOfDay(for: Date())
        guard let end = Calendar.current.date(byAdding: .day, value: 7, to: start) else { return }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map { Event(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "", start: $0.startDate,
                         allDay: $0.isAllDay, color: Color(nsColor: $0.calendar.color)) }
    }
}
