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
    public let forEach: String?
    public let forItem: String?
    public let forIndex: String?
    public let columns: Int?

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
        value: MojuValue? = nil,
        forEach: String? = nil,
        forItem: String? = nil,
        forIndex: String? = nil,
        columns: Int? = nil
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
        self.forEach = forEach
        self.forItem = forItem
        self.forIndex = forIndex
        self.columns = columns
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
    case tableView
    case collectionView
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

    public init(
        backgroundColor: String? = nil,
        textColor: String? = nil,
        hidden: Bool? = nil,
        hideBackButton: Bool? = nil,
        backButton: MojuBarButton? = nil,
        rightButtons: [MojuBarButton]? = nil
    ) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.hidden = hidden
        self.hideBackButton = hideBackButton
        self.backButton = backButton
        self.rightButtons = rightButtons
    }
}

public struct MojuBarButton: Codable {
    public let id: String?
    public let iconName: String?
    public let text: String?
    public let action: MojuAction?

    public init(
        id: String? = nil,
        iconName: String? = nil,
        text: String? = nil,
        action: MojuAction? = nil
    ) {
        self.id = id
        self.iconName = iconName
        self.text = text
        self.action = action
    }
}
