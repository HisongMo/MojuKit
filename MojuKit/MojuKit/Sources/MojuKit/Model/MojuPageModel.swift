import CoreGraphics
import Foundation

public struct MojuPage: Codable {
    public let schemaVersion: String
    public let pageId: String?
    public let pageTitle: String?
    public let backgroundColor: String?
    public let pageParams: [String: MojuValue]?
    public let onLoad: [MojuRequest]?
    public let components: [MojuComponent]
    public let fixedBottomComponents: [MojuComponent]?
    public let navigationBar: MojuNavigationBarConfig?

    public init(
        schemaVersion: String,
        pageId: String?,
        pageTitle: String?,
        backgroundColor: String? = nil,
        pageParams: [String: MojuValue]? = nil,
        onLoad: [MojuRequest]? = nil,
        components: [MojuComponent],
        fixedBottomComponents: [MojuComponent]? = nil,
        navigationBar: MojuNavigationBarConfig? = nil
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

public struct MojuComponent: Codable {
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
    public let style: MojuStyle?
    public let selectedStyle: MojuStyle?
    public let action: MojuAction?
    public let children: [MojuComponent]?
    public let visible: MojuValue?
    public let stateKey: String?
    public let value: MojuValue?

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
        style: MojuStyle? = nil,
        selectedStyle: MojuStyle? = nil,
        action: MojuAction? = nil,
        children: [MojuComponent]? = nil,
        visible: MojuValue? = nil,
        stateKey: String? = nil,
        value: MojuValue? = nil
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

public struct MojuStyle: Codable {
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
}

enum MojuComponentType: String {
    case text
    case image
    case input
    case textarea
    case button
    case space
    case card
    case row
    case icon
    case selectableCard
}

extension MojuStyle {
    func merging(_ override: MojuStyle?) -> MojuStyle {
        guard let override else { return self }
        return MojuStyle(
            width: override.width ?? width,
            widthMode: override.widthMode ?? widthMode,
            height: override.height ?? height,
            marginTop: override.marginTop ?? marginTop,
            marginBottom: override.marginBottom ?? marginBottom,
            marginLeft: override.marginLeft ?? marginLeft,
            marginRight: override.marginRight ?? marginRight,
            paddingTop: override.paddingTop ?? paddingTop,
            paddingBottom: override.paddingBottom ?? paddingBottom,
            paddingLeft: override.paddingLeft ?? paddingLeft,
            paddingRight: override.paddingRight ?? paddingRight,
            backgroundColor: override.backgroundColor ?? backgroundColor,
            textColor: override.textColor ?? textColor,
            fontSize: override.fontSize ?? fontSize,
            fontWeight: override.fontWeight ?? fontWeight,
            cornerRadius: override.cornerRadius ?? cornerRadius,
            borderWidth: override.borderWidth ?? borderWidth,
            borderColor: override.borderColor ?? borderColor,
            alignment: override.alignment ?? alignment,
            stackAlignment: override.stackAlignment ?? stackAlignment,
            distribution: override.distribution ?? distribution,
            spacing: override.spacing ?? spacing,
            contentMode: override.contentMode ?? contentMode,
            numberOfLines: override.numberOfLines ?? numberOfLines,
            hidden: override.hidden ?? hidden
        )
    }
}

public struct MojuNavigationBarConfig: Codable {
    public let backgroundColor: String?
    public let textColor: String?
    public let hidden: Bool?
    public let hideBackButton: Bool?
    public let backButton: MojuBarButton?
    public let rightButtons: [MojuBarButton]?
}

public struct MojuBarButton: Codable {
    public let id: String?
    public let iconName: String?
    public let text: String?
    public let action: MojuAction?
}
