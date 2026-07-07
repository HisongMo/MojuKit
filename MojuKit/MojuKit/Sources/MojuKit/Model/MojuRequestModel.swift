import Foundation

public struct MojuRequest: Codable {
    public let id: String?
    public let apiKey: String
    public let params: [String: MojuValue]?
    public let responseKey: String?
    public let showLoading: Bool?
    public let loadingText: String?
    public let successAction: MojuAction?
    public let failureAction: MojuAction?
}

public final class MojuAction: Codable {
    public let type: String
    public let target: String?
    public let url: String?
    public let message: String?
    public let params: [String: MojuValue]?
    public let request: MojuRequest?
    public let trackEvent: String?
    public let stateKey: String?
    public let value: MojuValue?
    public let delayMilliseconds: Int?
    public let actions: [MojuAction]?

    public init(
        type: String,
        target: String? = nil,
        url: String? = nil,
        message: String? = nil,
        params: [String: MojuValue]? = nil,
        request: MojuRequest? = nil,
        trackEvent: String? = nil,
        stateKey: String? = nil,
        value: MojuValue? = nil,
        delayMilliseconds: Int? = nil,
        actions: [MojuAction]? = nil
    ) {
        self.type = type
        self.target = target
        self.url = url
        self.message = message
        self.params = params
        self.request = request
        self.trackEvent = trackEvent
        self.stateKey = stateKey
        self.value = value
        self.delayMilliseconds = delayMilliseconds
        self.actions = actions
    }
}
