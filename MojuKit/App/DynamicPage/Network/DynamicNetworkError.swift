import Foundation

enum DynamicNetworkError: Error {
    case unsupportedAPI
    case forbiddenAPI
    case rejectedByNative
    case invalidResponse
}
