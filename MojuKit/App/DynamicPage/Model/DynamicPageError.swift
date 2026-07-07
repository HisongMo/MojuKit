import Foundation

enum DynamicPageError: Error, Equatable {
    case invalidJSON
    case unsupportedSchemaVersion
    case tooManyComponents
    case recursionTooDeep
    case unsupportedComponent
    case unsupportedAction
    case unsupportedAPI
    case invalidURL
    case invalidParameters
    case requestFailed
    case invalidResponse
    case tooManyConcurrentRequests
    case forbiddenAPI
    case highRiskRequestRejected
}

enum DynamicPageLimits {
    static let maxJSONSize = 1_048_576
    static let maxComponentCount = 200
    static let maxRecursionDepth = 10
    static let maxConcurrentRequests = 5
    static let requestTimeout: TimeInterval = 15
    static let maxResponseBytes = 1_048_576
}

enum DynamicPageLogger {
    static func debug(_ message: String) {
        #if DEBUG
        print("[DynamicPage] \(message)")
        #endif
    }
}
