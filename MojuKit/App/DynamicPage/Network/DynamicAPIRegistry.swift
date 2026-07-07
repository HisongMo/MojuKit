import Foundation

enum DynamicAPIKey: String {
    case vipInfo
    case openVip
    case couponList
    case receiveCoupon
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

enum DynamicAPIRiskLevel {
    case normal
    case confirmationRequired
    case forbidden
}

struct DynamicAPIEndpoint {
    let path: String
    let method: HTTPMethod
    let requiresLogin: Bool
    let riskLevel: DynamicAPIRiskLevel
}

enum DynamicAPIRegistry {
    static func endpoint(for apiKey: String) -> DynamicAPIEndpoint? {
        guard let key = DynamicAPIKey(rawValue: apiKey) else {
            return nil
        }

        switch key {
        case .vipInfo:
            return DynamicAPIEndpoint(path: "/api/v1/vip/info", method: .get, requiresLogin: true, riskLevel: .normal)
        case .openVip:
            return DynamicAPIEndpoint(path: "/api/v1/vip/open", method: .post, requiresLogin: true, riskLevel: .confirmationRequired)
        case .couponList:
            return DynamicAPIEndpoint(path: "/api/v1/coupon/list", method: .get, requiresLogin: true, riskLevel: .normal)
        case .receiveCoupon:
            return DynamicAPIEndpoint(path: "/api/v1/coupon/receive", method: .post, requiresLogin: true, riskLevel: .normal)
        }
    }
}
