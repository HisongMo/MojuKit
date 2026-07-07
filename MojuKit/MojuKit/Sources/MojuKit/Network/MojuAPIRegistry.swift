import Foundation

enum MojuAPIKey: String {
    case vipInfo
    case openVip
    case couponList
    case receiveCoupon
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

enum MojuAPIRiskLevel {
    case normal
    case confirmationRequired
    case forbidden
}

struct MojuAPIEndpoint {
    let path: String
    let method: HTTPMethod
    let requiresLogin: Bool
    let riskLevel: MojuAPIRiskLevel
}

enum MojuAPIRegistry {
    static func endpoint(for apiKey: String) -> MojuAPIEndpoint? {
        guard let key = MojuAPIKey(rawValue: apiKey) else {
            return MojuAPIEndpoint(path: "", method: .post, requiresLogin: false, riskLevel: .normal)
        }

        switch key {
        case .vipInfo:
            return MojuAPIEndpoint(path: "/api/v1/vip/info", method: .get, requiresLogin: true, riskLevel: .normal)
        case .openVip:
            return MojuAPIEndpoint(path: "/api/v1/vip/open", method: .post, requiresLogin: true, riskLevel: .confirmationRequired)
        case .couponList:
            return MojuAPIEndpoint(path: "/api/v1/coupon/list", method: .get, requiresLogin: true, riskLevel: .normal)
        case .receiveCoupon:
            return MojuAPIEndpoint(path: "/api/v1/coupon/receive", method: .post, requiresLogin: true, riskLevel: .normal)
        }
    }
}
