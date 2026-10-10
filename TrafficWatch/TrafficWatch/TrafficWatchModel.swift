import Foundation
import SwiftUI

struct FlowRow: Identifiable, Equatable {
    let id: UUID
    let destination: String
    let transport: String
    let app: String?
    let timestamp: Date
    var organization: String?
    var lookupFailed = false

    var timeText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

@MainActor
final class TrafficWatchModel: ObservableObject {
    static var shared: TrafficWatchModel?

    @Published var rows: [FlowRow] = []
    @Published var monitoring: Bool {
        didSet {
            if monitoring {
                FilterController.shared.requestSetup()
            } else {
                FilterController.shared.disable()
            }
        }
    }

    private let lookup = OrganizationLookup.shared
    private var inFlight = Set<UUID>()
    private var observerInstalled = false

    init() {
        monitoring = FilterController.shared.isEnabled
        FilterController.shared.refresh()
        Self.shared = self
        reload()
        installDarwinObserver()
    }

    func clear() {
        FlowEventStore.shared.clear()
        rows = []
    }

    private func installDarwinObserver() {
        guard !observerInstalled else { return }
        observerInstalled = true
        let center = CFNotificationCenterGetDarwinNotificationCenter()
        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { _, _, _, _, _ in
                Task { @MainActor in
                    TrafficWatchModel.shared?.reload()
                }
            },
            FlowEventStore.newEventsNotification as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func reload() {
        let events = FlowEventStore.shared.readEvents()
        var newRowIDs = Set<UUID>()
        for event in events {
            newRowIDs.insert(event.id)
            if rows.contains(where: { $0.id == event.id }) { continue }
            guard let destination = event.host ?? event.remoteAddress else { continue }
            rows.append(FlowRow(
                id: event.id,
                destination: destination,
                transport: event.transport,
                app: event.appBundleID,
                timestamp: event.timestamp
            ))
            lookupOrg(for: destination, rowID: event.id)
        }
        rows.removeAll(where: { !newRowIDs.contains($0.id) })
        rows.sort { $0.timestamp > $1.timestamp }
    }

    private func lookupOrg(for destination: String, rowID: UUID) {
        guard !inFlight.contains(rowID) else { return }
        inFlight.insert(rowID)
        lookup.lookup(host: destination) { [weak self] info in
            Task { @MainActor in
                guard let self else { return }
                self.inFlight.remove(rowID)
                if let index = self.rows.firstIndex(where: { $0.id == rowID }) {
                    self.rows[index].organization = info?.name
                    self.rows[index].lookupFailed = info == nil
                }
            }
        }
    }
}
