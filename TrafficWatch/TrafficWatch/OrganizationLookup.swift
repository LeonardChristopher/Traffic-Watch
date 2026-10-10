import Foundation

struct OrganizationInfo: Codable, Equatable {
    let name: String
    let network: String?
    let country: String?
    let source: String
}

final class OrganizationLookup {
    static let shared = OrganizationLookup()
    private let cache: NSCache<NSString, OrganizationInfo>
    private let session: URLSession

    private init() {
        cache = NSCache()
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        session = URLSession(configuration: config)
    }

    func lookup(host: String, completion: @escaping (OrganizationInfo?) -> Void) {
        if let ipv4 = ipv4Address(from: host) {
            lookupIP(ipv4, completion: completion)
            return
        }
        resolveHost(host) { [weak self] address in
            guard let self, let address else {
                completion(nil)
                return
            }
            self.lookupIP(address) { info in
                var enriched = info
                if info == nil {
                    enriched = OrganizationInfo(
                        name: host,
                        network: nil,
                        country: nil,
                        source: "hostname"
                    )
                }
                completion(enriched)
            }
        }
    }

    private func lookupIP(_ address: String, completion: @escaping (OrganizationInfo?) -> Void) {
        if let cached = cache.object(forKey: address as NSString) {
            completion(cached)
            return
        }
        guard let url = URL(string: "https://rdap.org/ip/\(address)") else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.setValue("application/rdap+json", forHTTPHeaderField: "Accept")
        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self,
                  error == nil,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(nil)
                return
            }
            let info = self.parseRDAP(json, address: address)
            if let info {
                self.cache.setObject(info, forKey: address as NSString)
            }
            completion(info)
        }.resume()
    }

    private func parseRDAP(_ json: [String: Any], address: String) -> OrganizationInfo? {
        var name: String?
        var range: String?
        var country: String?

        if let start = json["startAddress"] as? String, let end = json["endAddress"] as? String {
            range = "\(start) – \(end)"
        }

        for entity in (json["entities"] as? [[String: Any]]) ?? [] {
            if let vcardArray = entity["vcardArray"] as? [Any],
               let vcard = vcardArray.last as? [[String: Any]] {
                for entry in vcard {
                    if let key = entry.first as? String, key == "fn",
                       let value = entry.dropFirst(2).first as? String {
                        if name == nil {
                            name = value
                        }
                    }
                }
            }
            if name == nil, let roles = entity["roles"] as? [String],
               roles.contains("registrant") || roles.contains("administrative") {
                name = entity["handle"] as? String
            }
        }

        if name == nil {
            name = json["name"] as? String
        }
        country = json["country"] as? String

        guard let orgName = name, !orgName.isEmpty else {
            return nil
        }
        return OrganizationInfo(
            name: orgName,
            network: range,
            country: country,
            source: "RDAP"
        )
    }

    private func ipv4Address(from host: String) -> String? {
        var addr = in_addr()
        if inet_pton(AF_INET, host, &addr) == 1 {
            return host
        }
        return nil
    }

    private func resolveHost(_ host: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            var hints = addrinfo()
            hints.ai_family = AF_INET
            var result: UnsafeMutablePointer<addrinfo>?
            if getaddrinfo(host, nil, &hints, &result) == 0, let result {
                var first = result
                var found: String?
                while let info = first {
                    if info.pointee.ai_family == AF_INET,
                       let sa = info.pointee.ai_addr,
                       sa.pointee.sa_family == UInt8(AF_INET) {
                        var addr = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
                        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                        if inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil {
                            found = String(cString: buffer)
                            break
                        }
                    }
                    first = UnsafeMutablePointer(info.pointee.ai_next)
                }
                freeaddrinfo(result)
                completion(found)
            } else {
                completion(nil)
            }
        }
    }
}
