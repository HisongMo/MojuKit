import CoreGraphics
import Foundation

public enum DynamicValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: DynamicValue])
    case array([DynamicValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: DynamicValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([DynamicValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

public struct DynamicPage: Codable, Equatable {
    public let schemaVersion: String
    public let pageId: String?
    public let pageTitle: String?
    public let backgroundColor: String?
    public let pageParams: [String: DynamicValue]?
    public let onLoad: [DynamicRequest]?
    public let components: [DynamicComponent]
    public let fixedBottomComponents: [DynamicComponent]?
    public let navigationBar: DynamicNavigationBarConfig?

    public init(
        schemaVersion: String,
        pageId: String?,
        pageTitle: String?,
        backgroundColor: String? = nil,
        pageParams: [String: DynamicValue]? = nil,
        onLoad: [DynamicRequest]? = nil,
        components: [DynamicComponent],
        fixedBottomComponents: [DynamicComponent]? = nil,
        navigationBar: DynamicNavigationBarConfig? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.pageId = pageId
        self.pageTitle = pageTitle
        self.backgroundColor = backgroundColor
        self.pageParams = pageParams
        self.onLoad = onLoad
        self.components = components
        self.fixedBottomComponents = fixedBottomComponents
        self.navigationBar = navigationBar
    }
}

public struct DynamicComponent: Codable, Equatable {
    public let id: String?
    public let type: String
    public let text: String?
    public let defaultText: String?
    public let placeholder: String?
    public let imageUrl: String?
    public let placeholderImage: String?
    public let iconName: String?
    public let keyboardType: String?
    public let maxLength: Int?
    public let style: DynamicStyle?
    public let selectedStyle: DynamicStyle?
    public let action: DynamicAction?
    public let children: [DynamicComponent]?
    public let visible: DynamicValue?
    public let stateKey: String?
    public let value: DynamicValue?

    public init(
        id: String? = nil,
        type: String,
        text: String? = nil,
        defaultText: String? = nil,
        placeholder: String? = nil,
        imageUrl: String? = nil,
        placeholderImage: String? = nil,
        iconName: String? = nil,
        keyboardType: String? = nil,
        maxLength: Int? = nil,
        style: DynamicStyle? = nil,
        selectedStyle: DynamicStyle? = nil,
        action: DynamicAction? = nil,
        children: [DynamicComponent]? = nil,
        visible: DynamicValue? = nil,
        stateKey: String? = nil,
        value: DynamicValue? = nil
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.defaultText = defaultText
        self.placeholder = placeholder
        self.imageUrl = imageUrl
        self.placeholderImage = placeholderImage
        self.iconName = iconName
        self.keyboardType = keyboardType
        self.maxLength = maxLength
        self.style = style
        self.selectedStyle = selectedStyle
        self.action = action
        self.children = children
        self.visible = visible
        self.stateKey = stateKey
        self.value = value
    }
}

public struct DynamicStyle: Codable, Equatable {
    public let width: CGFloat?
    public let widthMode: String?
    public let height: CGFloat?
    public let marginTop: CGFloat?
    public let marginBottom: CGFloat?
    public let marginLeft: CGFloat?
    public let marginRight: CGFloat?
    public let paddingTop: CGFloat?
    public let paddingBottom: CGFloat?
    public let paddingLeft: CGFloat?
    public let paddingRight: CGFloat?
    public let backgroundColor: String?
    public let textColor: String?
    public let fontSize: CGFloat?
    public let fontWeight: String?
    public let cornerRadius: CGFloat?
    public let borderWidth: CGFloat?
    public let borderColor: String?
    public let alignment: String?
    public let stackAlignment: String?
    public let distribution: String?
    public let spacing: CGFloat?
    public let contentMode: String?
    public let numberOfLines: Int?
    public let hidden: Bool?

    public init(
        width: CGFloat? = nil,
        widthMode: String? = nil,
        height: CGFloat? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil,
        marginLeft: CGFloat? = nil,
        marginRight: CGFloat? = nil,
        paddingTop: CGFloat? = nil,
        paddingBottom: CGFloat? = nil,
        paddingLeft: CGFloat? = nil,
        paddingRight: CGFloat? = nil,
        backgroundColor: String? = nil,
        textColor: String? = nil,
        fontSize: CGFloat? = nil,
        fontWeight: String? = nil,
        cornerRadius: CGFloat? = nil,
        borderWidth: CGFloat? = nil,
        borderColor: String? = nil,
        alignment: String? = nil,
        stackAlignment: String? = nil,
        distribution: String? = nil,
        spacing: CGFloat? = nil,
        contentMode: String? = nil,
        numberOfLines: Int? = nil,
        hidden: Bool? = nil
    ) {
        self.width = width
        self.widthMode = widthMode
        self.height = height
        self.marginTop = marginTop
        self.marginBottom = marginBottom
        self.marginLeft = marginLeft
        self.marginRight = marginRight
        self.paddingTop = paddingTop
        self.paddingBottom = paddingBottom
        self.paddingLeft = paddingLeft
        self.paddingRight = paddingRight
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.alignment = alignment
        self.stackAlignment = stackAlignment
        self.distribution = distribution
        self.spacing = spacing
        self.contentMode = contentMode
        self.numberOfLines = numberOfLines
        self.hidden = hidden
    }
}

public extension DynamicStyle {
    func merging(_ other: DynamicStyle?) -> DynamicStyle {
        guard let other else { return self }
        return DynamicStyle(
            width: other.width ?? width,
            widthMode: other.widthMode ?? widthMode,
            height: other.height ?? height,
            marginTop: other.marginTop ?? marginTop,
            marginBottom: other.marginBottom ?? marginBottom,
            marginLeft: other.marginLeft ?? marginLeft,
            marginRight: other.marginRight ?? marginRight,
            paddingTop: other.paddingTop ?? paddingTop,
            paddingBottom: other.paddingBottom ?? paddingBottom,
            paddingLeft: other.paddingLeft ?? paddingLeft,
            paddingRight: other.paddingRight ?? paddingRight,
            backgroundColor: other.backgroundColor ?? backgroundColor,
            textColor: other.textColor ?? textColor,
            fontSize: other.fontSize ?? fontSize,
            fontWeight: other.fontWeight ?? fontWeight,
            cornerRadius: other.cornerRadius ?? cornerRadius,
            borderWidth: other.borderWidth ?? borderWidth,
            borderColor: other.borderColor ?? borderColor,
            alignment: other.alignment ?? alignment,
            stackAlignment: other.stackAlignment ?? stackAlignment,
            distribution: other.distribution ?? distribution,
            spacing: other.spacing ?? spacing,
            contentMode: other.contentMode ?? contentMode,
            numberOfLines: other.numberOfLines ?? numberOfLines,
            hidden: other.hidden ?? hidden
        )
    }
}

public struct DynamicRequest: Codable, Equatable {
    public let id: String?
    public let apiKey: String
    public let params: [String: DynamicValue]?
    public let responseKey: String?
    public let showLoading: Bool?
    public let loadingText: String?
    public let successAction: DynamicAction?
    public let failureAction: DynamicAction?
}

public final class DynamicAction: Codable, Equatable {
    public let type: String
    public let target: String?
    public let url: String?
    public let message: String?
    public let params: [String: DynamicValue]?
    public let request: DynamicRequest?
    public let trackEvent: String?
    public let stateKey: String?
    public let value: DynamicValue?
    public let delayMilliseconds: Int?
    public let actions: [DynamicAction]?

    public init(
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

    public static func == (lhs: DynamicAction, rhs: DynamicAction) -> Bool {
        lhs.type == rhs.type &&
            lhs.target == rhs.target &&
            lhs.url == rhs.url &&
            lhs.message == rhs.message &&
            lhs.params == rhs.params &&
            lhs.request == rhs.request &&
            lhs.trackEvent == rhs.trackEvent &&
            lhs.stateKey == rhs.stateKey &&
            lhs.value == rhs.value &&
            lhs.delayMilliseconds == rhs.delayMilliseconds &&
            lhs.actions == rhs.actions
    }
}

public struct DynamicNavigationBarConfig: Codable, Equatable {
    public let backgroundColor: String?
    public let textColor: String?
    public let hidden: Bool?
    public let hideBackButton: Bool?
    public let backButton: DynamicBarButton?
    public let rightButtons: [DynamicBarButton]?

    public init(
        backgroundColor: String? = nil,
        textColor: String? = nil,
        hidden: Bool? = nil,
        hideBackButton: Bool? = nil,
        backButton: DynamicBarButton? = nil,
        rightButtons: [DynamicBarButton]? = nil
    ) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.hidden = hidden
        self.hideBackButton = hideBackButton
        self.backButton = backButton
        self.rightButtons = rightButtons
    }
}

public struct DynamicBarButton: Codable, Equatable {
    public let id: String?
    public let iconName: String?
    public let text: String?
    public let action: DynamicAction?

    public init(
        id: String? = nil,
        iconName: String? = nil,
        text: String? = nil,
        action: DynamicAction? = nil
    ) {
        self.id = id
        self.iconName = iconName
        self.text = text
        self.action = action
    }
}
