import UIKit

@MainActor
final class MojuActionHandler {
    var onNavigate: ((_ target: String, _ params: [String: MojuValue]?) -> Void)?
    var onNativeNavigate: ((_ target: String, _ params: [String: MojuValue]?) -> Void)?
    var onTrackEvent: ((_ eventName: String, _ params: [String: MojuValue]?) -> Void)?
    var onShowToast: ((_ message: String) -> Void)?
    var onShowModal: ((_ target: String, _ params: [String: MojuValue]?) -> Void)?
    var onStateChanged: (() -> Void)?

    private let dataStore: MojuDataStore
    private let requestExecutor: MojuRequestExecutor
    private let templateResolver: MojuTemplateResolver

    init(dataStore: MojuDataStore, requestExecutor: MojuRequestExecutor) {
        self.dataStore = dataStore
        self.requestExecutor = requestExecutor
        self.templateResolver = MojuTemplateResolver(dataStore: dataStore)
    }

    func handle(_ action: MojuAction, resolver: MojuTemplateResolver? = nil) async {
        let activeResolver = resolver ?? self.templateResolver
        switch action.type {
        case "sequence":
            for childAction in action.actions ?? [] {
                await handle(childAction, resolver: activeResolver)
            }

        case "delay":
            let milliseconds = max(0, action.delayMilliseconds ?? 0)
            if milliseconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
            }
            for childAction in action.actions ?? [] {
                await handle(childAction, resolver: activeResolver)
            }

        case "navigate":
            guard let target = action.target else { return }
            let resolvedTarget = activeResolver.resolveString(target)
            let params = action.params.map { activeResolver.resolveParams($0) }
            onNavigate?(resolvedTarget, params)

        case "nativeNavigate":
            guard let target = action.target else { return }
            let resolvedTarget = activeResolver.resolveString(target)
            let params = action.params.map { activeResolver.resolveParams($0) }
            onNativeNavigate?(resolvedTarget, params)

        case "openUrl":
            guard let rawURL = action.url else { return }
            openURL(activeResolver.resolveString(rawURL))

        case "toast":
            let message = action.message.map { activeResolver.resolveString($0) } ?? ""
            showToast(message)

        case "request":
            guard let request = action.request else { return }
            do {
                _ = try await requestExecutor.execute(request: request, resolver: activeResolver)
                if let successAction = request.successAction {
                    await handle(successAction, resolver: activeResolver)
                }
            } catch {
                if let failureAction = request.failureAction {
                    await handle(failureAction, resolver: activeResolver)
                }
            }

        case "track":
            guard let eventName = action.trackEvent else { return }
            let params = action.params.map { activeResolver.resolveParams($0) }
            onTrackEvent?(eventName, params)

        case "setState":
            guard let stateKey = action.stateKey, let value = action.value else { return }
            dataStore.set(activeResolver.resolveValue(value).anyValue, forKey: stateKey)
            onStateChanged?()

        case "showModal":
            guard let target = action.target else { return }
            let resolvedTarget = activeResolver.resolveString(target)
            let params = action.params.map { activeResolver.resolveParams($0) }
            onShowModal?(resolvedTarget, params)

        default:
            MojuPageLogger.debug("unsupported action: \(action.type)")
        }
    }

    private func openURL(_ rawURL: String) {
        guard
            let url = URL(string: rawURL),
            ["http", "https"].contains(url.scheme?.lowercased())
        else {
            MojuPageLogger.debug("invalid url: \(rawURL)")
            return
        }
        UIApplication.shared.open(url)
    }

    private func showToast(_ message: String) {
        guard !message.isEmpty else { return }
        onShowToast?(message)
    }
}
