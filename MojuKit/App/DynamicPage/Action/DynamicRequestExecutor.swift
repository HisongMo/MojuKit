import Foundation

@MainActor
final class DynamicRequestExecutor {
    var onShowLoading: ((_ text: String?) -> Void)?
    var onHideLoading: (() -> Void)?
    var onRequestFinished: (() -> Void)?
    var onConfirmHighRiskRequest: ((_ apiKey: String, _ params: [String: Any], _ completion: @escaping (Bool) -> Void) -> Void)?

    private let networkProvider: DynamicNetworkProviding
    private let dataStore: DynamicDataStore
    private let templateResolver: DynamicTemplateResolver
    private var executingRequestIds = Set<String>()
    private var runningTasks: [Task<Void, Never>] = []

    init(networkProvider: DynamicNetworkProviding, dataStore: DynamicDataStore) {
        self.networkProvider = networkProvider
        self.dataStore = dataStore
        self.templateResolver = DynamicTemplateResolver(dataStore: dataStore)
    }

    func execute(request: DynamicRequest) async throws -> Any {
        guard let endpoint = DynamicAPIRegistry.endpoint(for: request.apiKey) else {
            DynamicPageLogger.debug("unsupported apiKey: \(request.apiKey)")
            throw DynamicPageError.unsupportedAPI
        }

        guard endpoint.riskLevel != .forbidden else {
            throw DynamicPageError.forbiddenAPI
        }

        let requestId = request.id ?? request.apiKey
        guard !executingRequestIds.contains(requestId) else {
            throw DynamicPageError.tooManyConcurrentRequests
        }
        guard executingRequestIds.count < DynamicPageLimits.maxConcurrentRequests else {
            throw DynamicPageError.tooManyConcurrentRequests
        }

        let resolvedParams = templateResolver.resolveParams(request.params ?? [:])
        let params = resolvedParams.mapValues { $0.anyValue }

        if endpoint.riskLevel == .confirmationRequired {
            let approved = await confirmHighRiskRequest(apiKey: request.apiKey, params: params)
            guard approved else {
                throw DynamicPageError.highRiskRequestRejected
            }
        }

        executingRequestIds.insert(requestId)
        if request.showLoading == true || request.loadingText != nil {
            onShowLoading?(request.loadingText)
        }

        defer {
            executingRequestIds.remove(requestId)
            onHideLoading?()
        }

        do {
            DynamicPageLogger.debug("request start: \(request.apiKey)")
            let response = try await withTimeout(seconds: DynamicPageLimits.requestTimeout) {
                try await self.networkProvider.request(apiKey: request.apiKey, params: params)
            }
            if let responseKey = request.responseKey {
                dataStore.set(response, forKey: responseKey)
            }
            DynamicPageLogger.debug("request success: \(request.apiKey)")
            onRequestFinished?()
            return response
        } catch {
            DynamicPageLogger.debug("request failed: \(request.apiKey)")
            throw DynamicPageError.requestFailed
        }
    }

    func cancelAll() {
        runningTasks.forEach { $0.cancel() }
        runningTasks.removeAll()
        executingRequestIds.removeAll()
    }

    private func confirmHighRiskRequest(apiKey: String, params: [String: Any]) async -> Bool {
        guard let onConfirmHighRiskRequest else {
            return false
        }

        return await withCheckedContinuation { continuation in
            onConfirmHighRiskRequest(apiKey, params) { approved in
                continuation.resume(returning: approved)
            }
        }
    }

    private func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw DynamicPageError.requestFailed
            }

            guard let result = try await group.next() else {
                throw DynamicPageError.requestFailed
            }
            group.cancelAll()
            return result
        }
    }
}
