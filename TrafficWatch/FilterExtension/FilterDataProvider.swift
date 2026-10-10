import Foundation
import Network
import NetworkExtension

final class FilterDataProvider: NEFilterDataProvider {
    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }

    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        var host: String?
        var address: String?
        var port: Int?
        var transport = "TCP"

        if let socketFlow = flow as? NEFilterSocketFlow {
            transport = socketFlow.socketProtocol == .tcp ? "TCP" : "UDP"
            if case .hostPort(let nwHost, let nwPort)? = socketFlow.remoteEndpoint {
                switch nwHost {
                case .name(let hostname, _):
                    host = hostname
                case .ipv4(let addr):
                    address = "\(addr)"
                case .ipv6(let addr):
                    address = "\(addr)"
                @unknown default:
                    break
                }
                port = nwPort.rawValue
            }
        }

        if host == nil, let url = flow.url, let urlHost = url.host {
            host = urlHost
            port = url.port ?? port
        }

        guard host != nil || address != nil else {
            return .allow()
        }

        let appID = flow.metaData?.sourceAppUniqueIdentifier
        let event = FlowEvent(
            host: host,
            remoteAddress: address,
            port: port,
            appBundleID: appID,
            transport: transport
        )
        FlowEventStore.shared.append(event)
        return .allow()
    }
}
