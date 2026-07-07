import Foundation

protocol DynamicNetworkProviding {
    func request(apiKey: String, params: [String: Any]) async throws -> Any
}
