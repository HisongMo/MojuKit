import Foundation

struct DynamicRequest: Codable {
    let id: String?
    let apiKey: String
    let params: [String: DynamicValue]?
    let responseKey: String?
    let showLoading: Bool?
    let loadingText: String?
    let successAction: DynamicAction?
    let failureAction: DynamicAction?
}

final class DynamicAction: Codable {
    let type: String
    let target: String?
    let url: String?
    let message: String?
    let params: [String: DynamicValue]?
    let request: DynamicRequest?
    let trackEvent: String?
    let stateKey: String?
    let value: DynamicValue?
    let delayMilliseconds: Int?
    let actions: [DynamicAction]?

    init(
        type: String,
        target: String? = nil,
        url: String? = nil,
        message: String? = nil,
        params: [String: DynamicValue]? = nil,
        request: DynamicRequest? = nil,
        trackEvent: String? = nil,
        stateKey: String? = nil,
        value: DynamicValue? = nil,
        delayMilliseconds: Int? = nil,
        actions: [DynamicAction]? = nil
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
