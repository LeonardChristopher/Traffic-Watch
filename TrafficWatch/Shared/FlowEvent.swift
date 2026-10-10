import Foundation

struct FlowEvent: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var host: String?
    var remoteAddress: String?
    var port: Int?
    var appBundleID: String?
    var transport: String

    enum CodingKeys: String, CodingKey {
        case id, timestamp, host, remoteAddress, port, appBundleID, transport
    }
}
