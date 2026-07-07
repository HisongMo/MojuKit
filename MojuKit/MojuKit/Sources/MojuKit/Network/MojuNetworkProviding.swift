import Foundation

public protocol MojuNetworkProviding {
    func request(apiKey: String, params: [String: Any]) async throws -> Any
}
