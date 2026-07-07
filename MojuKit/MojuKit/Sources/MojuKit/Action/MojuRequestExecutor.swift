import Foundation

@MainActor
final class MojuRequestExecutor {
    var onShowLoading: ((_ text: String?) -> Void)?
    var onHideLoading: (() -> Void)?
    var onRequestFinished: (() -> Void)?
    var onConfirmHighRiskRequest: ((_ apiKey: String, _ params: [String: Any], _ completion: @escaping (Bool) -> Void) -> Void)?

    private let networkProvider: MojuNetworkProviding
    private let dataStore: MojuDataStore
    private let templateResolver: MojuTemplateResolver
    private var executingRequestIds = Set<String>()
    private var runningTasks: [Task<Void, Never>] = []

    init(networkProvider: MojuNetworkProviding, dataStore: MojuDataStore) {
        self.networkProvider = networkProvider
        self.dataStore = dataStore
        self.templateResolver = MojuTemplateResolver(dataStore: dataStore)
    }

    func execute(request: MojuRequest) async throws -> Any {
        guard let endpoint = MojuAPIRegistry.endpoint(for: request.apiKey) else {
            MojuPageLogger.debug("unsupported apiKey: \(request.apiKey)")
            throw MojuPageError.unsupportedAPI
        }

        guard endpoint.riskLevel != .forbidden else {
            throw MojuPageError.forbiddenAPI
        }

        let requestId = request.id ?? request.apiKey
        guard !executingRequestIds.contains(requestId) else {
            throw MojuPageError.tooManyConcurrentRequests
        }
        guard executingRequestIds.count < MojuPageLimits.maxConcurrentRequests else {
            throw MojuPageError.tooManyConcurrentRequests
        }

        let resolvedParams = templateResolver.resolveParams(request.params ?? [:])
        let params = resolvedParams.mapValues { $0.anyValue }

        if endpoint.riskLevel == .confirmationRequired {
            let approved = await confirmHighRiskRequest(apiKey: request.apiKey, params: params)
            guard approved else {
                throw MojuPageError.highRiskRequestRejected
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
            MojuPageLogger.debug("request start: \(request.apiKey)")
            let response = try await withTimeout(seconds: MojuPageLimits.requestTimeout) {
                try await self.networkProvider.request(apiKey: request.apiKey, params: params)
            }
            if let responseKey = request.responseKey {
                dataStore.set(response, forKey: responseKey)
            }
            MojuPageLogger.debug("request success: \(request.apiKey)")
            onRequestFinished?()
            return response
        } catch {
            MojuPageLogger.debug("request failed: \(request.apiKey)")
            throw MojuPageError.requestFailed
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
                throw MojuPageError.requestFailed
            }

            guard let result = try await group.next() else {
                throw MojuPageError.requestFailed
            }
            group.cancelAll()
            return result
        }
    }
}
