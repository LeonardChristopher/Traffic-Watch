import Foundation
import NetworkExtension

enum FilterStatus {
    case disabled
    case enabled
    case failed(String)
}

final class FilterController: ObservableObject {
    static let shared = FilterController()
    @Published var status: FilterStatus = .disabled
    @Published var isEnabled = false

    private init() {}

    func requestSetup() {
        let manager = NEFilterManager.shared()
        manager.loadFromPreferences { [weak self] error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async {
                    self.status = .failed(error.localizedDescription)
                }
                return
            }
            if manager.providerConfiguration == nil {
                let config = NEFilterProviderConfiguration()
                config.username = "TrafficWatch"
                config.organization = "TrafficWatch"
                config.filterBrowsers = false
                config.filterPacketSocket = true
                manager.providerConfiguration = config
            }
            manager.isEnabled = true
            manager.localizedDescription = "TrafficWatch"
            manager.saveToPreferences { [weak self] saveError in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let saveError {
                        self.status = .failed(saveError.localizedDescription)
                        self.isEnabled = false
                    } else {
                        self.status = .enabled
                        self.isEnabled = true
                    }
                }
            }
        }
    }

    func disable() {
        let manager = NEFilterManager.shared()
        manager.loadFromPreferences { [weak self] error in
            guard let self, error == nil else { return }
            manager.isEnabled = false
            manager.saveToPreferences { [weak self] saveError in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isEnabled = false
                    self.status = saveError == nil ? .disabled : .failed(saveError!.localizedDescription)
                }
            }
        }
    }

    func refresh() {
        let manager = NEFilterManager.shared()
        manager.loadFromPreferences { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.status = .failed(error.localizedDescription)
                    self.isEnabled = false
                } else {
                    self.status = manager.isEnabled ? .enabled : .disabled
                    self.isEnabled = manager.isEnabled
                }
            }
        }
    }
}
