import CoreGraphics
import Foundation

struct DynamicPage: Codable {
    let schemaVersion: String
    let pageId: String?
    let pageTitle: String?
    let backgroundColor: String?
    let pageParams: [String: DynamicValue]?
    let onLoad: [DynamicRequest]?
    let components: [DynamicComponent]
    let fixedBottomComponents: [DynamicComponent]?
    let navigationBar: DynamicNavigationBarConfig?

    init(
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

struct DynamicComponent: Codable {
    let id: String?
    let type: String
    let text: String?
    let defaultText: String?
    let placeholder: String?
    let imageUrl: String?
    let placeholderImage: String?
    let iconName: String?
    let keyboardType: String?
    let maxLength: Int?
    let style: DynamicStyle?
    let selectedStyle: DynamicStyle?
    let action: DynamicAction?
    let children: [DynamicComponent]?
    let visible: DynamicValue?
    let stateKey: String?
    let value: DynamicValue?
    let forEach: String?
    let forItem: String?
    let forIndex: String?
    let columns: Int?

    init(
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
        value: DynamicValue? = nil,
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

struct DynamicStyle: Codable {
    let width: CGFloat?
    let widthMode: String?
    let height: CGFloat?
    let marginTop: CGFloat?
    let marginBottom: CGFloat?
    let marginLeft: CGFloat?
    let marginRight: CGFloat?
    let paddingTop: CGFloat?
    let paddingBottom: CGFloat?
    let paddingLeft: CGFloat?
    let paddingRight: CGFloat?
    let backgroundColor: String?
    let textColor: String?
    let fontSize: CGFloat?
    let fontWeight: String?
    let cornerRadius: CGFloat?
    let borderWidth: CGFloat?
    let borderColor: String?
    let alignment: String?
    let stackAlignment: String?
    let distribution: String?
    let spacing: CGFloat?
    let contentMode: String?
    let numberOfLines: Int?
    let hidden: Bool?
}

enum DynamicComponentType: String {
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

extension DynamicStyle {
    func merging(_ override: DynamicStyle?) -> DynamicStyle {
        guard let override else { return self }
        return DynamicStyle(
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

struct DynamicNavigationBarConfig: Codable {
    let backgroundColor: String?
    let textColor: String?
    let hidden: Bool?
    let hideBackButton: Bool?
    let backButton: DynamicBarButton?
    let rightButtons: [DynamicBarButton]?
}

struct DynamicBarButton: Codable {
    let id: String?
    let iconName: String?
    let text: String?
    let action: DynamicAction?
}
