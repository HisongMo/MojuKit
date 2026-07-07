import Foundation

final class MockDynamicNetworkProvider: DynamicNetworkProviding {
    func request(apiKey: String, params: [String: Any]) async throws -> Any {
        guard DynamicAPIRegistry.endpoint(for: apiKey) != nil else {
            throw DynamicNetworkError.unsupportedAPI
        }

        try await Task.sleep(nanoseconds: 500_000_000)

        switch apiKey {
        case DynamicAPIKey.vipInfo.rawValue:
            return [
                "id": "vip_10001",
                "name": "黄金会员",
                "expireDate": "2026-12-31",
                "bannerUrl": "https://picsum.photos/800/320"
            ]
        case DynamicAPIKey.openVip.rawValue:
            return [
                "success": true,
                "orderId": "order_10001"
            ]
        case DynamicAPIKey.couponList.rawValue:
            return [
                "count": 3
            ]
        case DynamicAPIKey.receiveCoupon.rawValue:
            return [
                "success": true
            ]
        default:
            throw DynamicNetworkError.unsupportedAPI
        }
    }
}
