import Foundation

public enum MojuNetworkError: Error {
    case unsupportedAPI
    case forbiddenAPI
    case rejectedByNative
    case invalidResponse
}
