import Foundation

final class FlowEventStore {
    static let shared = FlowEventStore()
    static let newEventsNotification = "com.trafficwatch.newEvents"

    private let defaults: UserDefaults?
    private let key = "flowEvents"
    private let maxEvents = 400
    private let queue = DispatchQueue(label: "com.trafficwatch.floweventstore")

    private init() {
        defaults = UserDefaults(suiteName: FlowEventStore.appGroupID)
    }

    static let appGroupID = "group.com.trafficwatch.shared"

    func append(_ event: FlowEvent) {
        queue.sync {
            var events = readEventsLocked()
            events.insert(event, at: 0)
            if events.count > maxEvents {
                events.removeLast(events.count - maxEvents)
            }
            writeEventsLocked(events)
        }
        postDarwinNotification()
    }

    func readEvents() -> [FlowEvent] {
        queue.sync { readEventsLocked() }
    }

    func clear() {
        queue.sync { writeEventsLocked([]) }
        postDarwinNotification()
    }

    private func readEventsLocked() -> [FlowEvent] {
        guard let data = defaults?.data(forKey: key) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([FlowEvent].self, from: data)) ?? []
    }

    private func writeEventsLocked(_ events: [FlowEvent]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(events) else { return }
        defaults?.set(data, forKey: key)
    }

    private func postDarwinNotification() {
        let center = CFNotificationCenterGetDarwinNotificationCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(rawValue: Self.newEventsNotification), nil, nil, true)
    }
}
