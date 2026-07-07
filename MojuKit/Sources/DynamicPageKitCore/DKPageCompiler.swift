import CoreGraphics
import Foundation

public struct DKPageSource: Equatable {
    public var dkmlText: String
    public var dkssText: String
    public var jsText: String
    public var configJSONText: String

    public init(dkmlText: String, dkssText: String, jsText: String, configJSONText: String) {
        self.dkmlText = dkmlText
        self.dkssText = dkssText
        self.jsText = jsText
        self.configJSONText = configJSONText
    }
}

public struct DKCompileResult {
    public let page: DynamicPage?
    public let diagnostics: [String]

    public init(page: DynamicPage?, diagnostics: [String]) {
        self.page = page
        self.diagnostics = diagnostics
    }
}

public struct DKPageConfig: Codable, Equatable {
    public var schemaVersion: String
    public var pageId: String?
    public var pageTitle: String?
    public var backgroundColor: String?
    public var pageParams: [String: DynamicValue]?
    public var onLoad: [DynamicRequest]?
    public var navigationBar: DynamicNavigationBarConfig?

    public init(
        schemaVersion: String = "1.0",
        pageId: String? = nil,
        pageTitle: String? = nil,
        backgroundColor: String? = nil,
        pageParams: [String: DynamicValue]? = nil,
        onLoad: [DynamicRequest]? = nil,
        navigationBar: DynamicNavigationBarConfig? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.pageId = pageId
        self.pageTitle = pageTitle
        self.backgroundColor = backgroundColor
        self.pageParams = pageParams
        self.onLoad = onLoad
        self.navigationBar = navigationBar
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion) ?? "1.0"
        pageId = try container.decodeIfPresent(String.self, forKey: .pageId)
        pageTitle = try container.decodeIfPresent(String.self, forKey: .pageTitle)
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
        pageParams = try container.decodeIfPresent([String: DynamicValue].self, forKey: .pageParams)
        onLoad = try container.decodeIfPresent([DynamicRequest].self, forKey: .onLoad)
        navigationBar = try container.decodeIfPresent(DynamicNavigationBarConfig.self, forKey: .navigationBar)
    }
}

public enum DKPageCompiler {
    public static func compile(_ source: DKPageSource) -> DKCompileResult {
        var diagnostics: [String] = []

        let config: DKPageConfig
        do {
            config = try parseConfig(source.configJSONText)
        } catch {
            return DKCompileResult(page: nil, diagnostics: ["JSON 配置解析失败：\(error.localizedDescription)"])
        }

        let styleSheet = DKSSParser.parse(source.dkssText)
        diagnostics.append(contentsOf: styleSheet.diagnostics)

        let methods = DKJSParser.parse(source.jsText)
        diagnostics.append(contentsOf: methods.diagnostics)

        let root: DKMLNode
        do {
            root = try DKMLParser.parse(source.dkmlText)
        } catch {
            return DKCompileResult(page: nil, diagnostics: diagnostics + ["DKML 解析失败：\(error.localizedDescription)"])
        }

        let rootStyle = styleSheet.styles(for: root.classNames)
        let fixedBottomNodes = root.children.filter { $0.attributes["slot"] == "fixedBottom" }
        let components = root.children
            .filter { $0.attributes["slot"] != "fixedBottom" }
            .compactMap {
                compileNode($0, styleSheet: styleSheet, methods: methods.methods, diagnostics: &diagnostics)
            }
        let fixedBottomComponents = fixedBottomNodes.compactMap {
            compileNode($0, styleSheet: styleSheet, methods: methods.methods, diagnostics: &diagnostics)
        }

        let page = DynamicPage(
            schemaVersion: config.schemaVersion,
            pageId: config.pageId,
            pageTitle: config.pageTitle,
            backgroundColor: config.backgroundColor ?? rootStyle?.backgroundColor,
            pageParams: config.pageParams,
            onLoad: config.onLoad,
            components: components,
            fixedBottomComponents: fixedBottomComponents.isEmpty ? nil : fixedBottomComponents,
            navigationBar: config.navigationBar
        )

        do {
            try DynamicPageValidator.validate(page)
            return DKCompileResult(page: page, diagnostics: diagnostics.isEmpty ? ["编译通过"] : diagnostics)
        } catch {
            return DKCompileResult(page: nil, diagnostics: diagnostics + ["DynamicPage 校验失败：\(error.localizedDescription)"])
        }
    }

    public static func decompile(page: DynamicPage) -> DKPageSource {
        let config = DKPageConfig(
            schemaVersion: page.schemaVersion,
            pageId: page.pageId,
            pageTitle: page.pageTitle,
            backgroundColor: page.backgroundColor,
            pageParams: page.pageParams,
            onLoad: page.onLoad,
            navigationBar: page.navigationBar
        )
        let configText = (try? prettyJSON(from: config)) ?? "{}"
        var styleLines: [String] = []
        var classCounter = 0
        var jsMethods: [String: String] = [:]

        let componentsStr = page.components
            .map { decompileComponent($0, counter: &classCounter, styleLines: &styleLines, jsMethods: &jsMethods) }
            .joined(separator: "\n")

        let fixedBottomStr = (page.fixedBottomComponents ?? [])
            .map { decompileComponent($0, counter: &classCounter, styleLines: &styleLines, jsMethods: &jsMethods, extraAttr: "slot=\"fixedBottom\"") }
            .joined(separator: "\n")

        let innerDKML: String
        if fixedBottomStr.isEmpty {
            innerDKML = componentsStr
        } else {
            innerDKML = componentsStr + (componentsStr.isEmpty ? "" : "\n") + fixedBottomStr
        }

        let dkml = """
        <page class="page">
        \(innerDKML)
        </page>
        """

        if styleLines.isEmpty {
            styleLines.append(".page {\n  background-color: \(page.backgroundColor ?? "#FFFFFF");\n}")
        }

        var jsMethodsText = ""
        if !jsMethods.isEmpty {
            jsMethodsText = "\n" + jsMethods.map { name, code in
                "    \(name)() {\n      \(code)\n    }"
            }.joined(separator: ",\n\n") + "\n  "
        }

        let jsText = """
        Page({
          data: {},
        
          methods: {\(jsMethodsText)}
        })
        """

        return DKPageSource(
            dkmlText: dkml,
            dkssText: styleLines.joined(separator: "\n\n"),
            jsText: jsText,
            configJSONText: configText
        )
    }


    public static func defaultSource(pageId: String) -> DKPageSource {
        DKPageSource(
            dkmlText: """
            <page class="page">
              <text class="title">Hello DynamicPageKit</text>
              <button class="primary-button" bindtap="goNext">查看详情</button>
            </page>
            """,
            dkssText: """
            .page {
              background-color: #FFFFFF;
            }

            .title {
              margin: 24 16 12 16;
              font-size: 20;
              font-weight: semibold;
              text-color: #111111;
            }

            .primary-button {
              height: 44;
              margin: 12 16 0 16;
              background-color: #2F80ED;
              text-color: #FFFFFF;
              corner-radius: 8;
            }
            """,
            jsText: """
            Page({
              data: {},

              methods: {
                goNext() {
                  dk.navigate("Detail")
                }
              }
            })
            """,
            configJSONText: """
            {
              "schemaVersion" : "1.0",
              "pageId" : "\(pageId)",
              "pageTitle" : "新页面"
            }
            """
        )
    }

    private static func compileNode(
        _ node: DKMLNode,
        styleSheet: DKStyleSheet,
        methods: [String: DynamicAction],
        diagnostics: inout [String]
    ) -> DynamicComponent? {
        let style = styleSheet.styles(for: node.classNames)
        let action: DynamicAction?
        if let methodName = node.attributes["bindtap"] {
            action = methods[methodName]
            if action == nil {
                diagnostics.append("DKML bindtap=\"\(methodName)\" 没有找到可编译的 JS method")
            }
        } else {
            action = nil
        }
        let visible = node.attributes["dk:if"].map { DynamicValue.string($0) }
        let children = node.children.compactMap {
            compileNode($0, styleSheet: styleSheet, methods: methods, diagnostics: &diagnostics)
        }

        switch node.name {
        case "page":
            return nil
        case "view":
            return DynamicComponent(type: "card", style: style, action: action, children: children, visible: visible)
        case "text":
            return DynamicComponent(type: "text", text: node.textContent, style: style, action: action, visible: visible)
        case "image":
            return DynamicComponent(type: "image", imageUrl: node.attributes["src"], placeholderImage: node.attributes["placeholder"], style: style, action: action, visible: visible)
        case "input":
            return DynamicComponent(
                type: "input",
                text: node.attributes["value"],
                defaultText: node.attributes["default"] ?? node.attributes["default-text"],
                placeholder: node.attributes["placeholder"],
                keyboardType: node.attributes["keyboard-type"] ?? node.attributes["keyboardType"],
                maxLength: (node.attributes["max-length"] ?? node.attributes["maxLength"]).flatMap(Int.init),
                style: style,
                action: action,
                visible: visible,
                stateKey: node.attributes["state-key"]
            )
        case "textarea":
            return DynamicComponent(
                type: "textarea",
                text: node.attributes["value"],
                defaultText: node.attributes["default"] ?? node.attributes["default-text"] ?? (node.textContent.isEmpty ? nil : node.textContent),
                placeholder: node.attributes["placeholder"],
                keyboardType: node.attributes["keyboard-type"] ?? node.attributes["keyboardType"],
                maxLength: (node.attributes["max-length"] ?? node.attributes["maxLength"]).flatMap(Int.init),
                style: style,
                action: action,
                visible: visible,
                stateKey: node.attributes["state-key"]
            )
        case "button":
            return DynamicComponent(type: "button", text: node.textContent, style: style, action: action, visible: visible)
        case "card":
            return DynamicComponent(type: "card", style: style, action: action, children: children, visible: visible)
        case "row":
            return DynamicComponent(type: "row", style: style, action: action, children: children, visible: visible)
        case "column":
            return DynamicComponent(type: "card", style: style, action: action, children: children, visible: visible)
        case "icon":
            let iconName = node.attributes["name"] ?? node.attributes["icon"]
            return DynamicComponent(type: "icon", iconName: iconName, style: style, action: action, visible: visible)
        case "space":
            return DynamicComponent(type: "space", style: style, visible: visible)
        case "selectable-card":
            return DynamicComponent(
                type: "selectableCard",
                style: style,
                action: action,
                children: children,
                visible: visible,
                stateKey: node.attributes["state-key"],
                value: node.attributes["value"].map(DynamicValue.string)
            )
        default:
            return DynamicComponent(type: "text", text: "Unsupported DKML tag: \(node.name)", style: style)
        }
    }

    private static func parseConfig(_ text: String) throws -> DKPageConfig {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return DKPageConfig() }
        return try JSONDecoder().decode(DKPageConfig.self, from: Data(trimmed.utf8))
    }

    private static func prettyJSON<T: Encodable>(from value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func decompileComponent(
        _ component: DynamicComponent,
        counter: inout Int,
        styleLines: inout [String],
        jsMethods: inout [String: String],
        extraAttr: String? = nil
    ) -> String {
        let className = "component-\(counter)"
        counter += 1
        if let style = component.style, let styleText = decompileStyle(style, className: className) {
            styleLines.append(styleText)
        }
        let extraAttrStr = extraAttr.map { " \($0)" } ?? ""

        let bindtapAttr: String
        if let action = component.action {
            let sanitizedId = component.id?.replacingOccurrences(of: "-", with: "_")
            let methodName = sanitizedId.map { "onTap_\($0)" } ?? "onTap_component_\(counter)"
            jsMethods[methodName] = decompileAction(action)
            bindtapAttr = " bindtap=\"\(methodName)\""
        } else {
            bindtapAttr = ""
        }

        switch component.type {
        case "text":
            return "  <text class=\"\(className)\"\(extraAttrStr)\(bindtapAttr)>\(escapeXML(component.text ?? ""))</text>"
        case "button":
            return "  <button class=\"\(className)\"\(extraAttrStr)\(bindtapAttr)>\(escapeXML(component.text ?? ""))</button>"
        case "image":
            return "  <image class=\"\(className)\"\(extraAttrStr)\(bindtapAttr) src=\"\(escapeXML(component.imageUrl ?? ""))\" />"
        case "input":
            return "  <input class=\"\(className)\"\(extraAttrStr)\(bindtapAttr)\(inputAttributes(component)) />"
        case "textarea":
            return "  <textarea class=\"\(className)\"\(extraAttrStr)\(bindtapAttr)\(inputAttributes(component))>\(escapeXML(component.defaultText ?? ""))</textarea>"
        case "icon":
            return "  <icon class=\"\(className)\"\(extraAttrStr)\(bindtapAttr) name=\"\(escapeXML(component.iconName ?? ""))\" />"
        case "row":
            let children = (component.children ?? []).map {
                decompileComponent($0, counter: &counter, styleLines: &styleLines, jsMethods: &jsMethods)
            }.joined(separator: "\n")
            return "  <row class=\"\(className)\"\(extraAttrStr)\(bindtapAttr)>\n\(children)\n  </row>"
        default:
            let children = (component.children ?? []).map {
                decompileComponent($0, counter: &counter, styleLines: &styleLines, jsMethods: &jsMethods)
            }.joined(separator: "\n")
            if children.isEmpty {
                return "  <view class=\"\(className)\"\(extraAttrStr)\(bindtapAttr)></view>"
            }
            return "  <view class=\"\(className)\"\(extraAttrStr)\(bindtapAttr)>\n\(children)\n  </view>"
        }
    }

    private static func inputAttributes(_ component: DynamicComponent) -> String {
        var attributes: [String] = []
        if let stateKey = component.stateKey {
            attributes.append("state-key=\"\(escapeXML(stateKey))\"")
        }
        if let placeholder = component.placeholder {
            attributes.append("placeholder=\"\(escapeXML(placeholder))\"")
        }
        if let text = component.text {
            attributes.append("value=\"\(escapeXML(text))\"")
        }
        if let keyboardType = component.keyboardType {
            attributes.append("keyboard-type=\"\(escapeXML(keyboardType))\"")
        }
        if let maxLength = component.maxLength {
            attributes.append("max-length=\"\(maxLength)\"")
        }
        return attributes.isEmpty ? "" : " " + attributes.joined(separator: " ")
    }

    private static func decompileAction(_ action: DynamicAction) -> String {
        switch action.type {
        case "sequence":
            return (action.actions ?? []).map(decompileAction).filter { !$0.isEmpty }.joined(separator: "\n")
        case "delay":
            let milliseconds = action.delayMilliseconds ?? 0
            let delayedBody = (action.actions ?? []).map(decompileAction).filter { !$0.isEmpty }.joined(separator: "\n")
            if delayedBody.isEmpty {
                return "dk.delay(\(milliseconds))"
            }
            return "dk.delay(\(milliseconds), () => { \(delayedBody) })"
        case "nativeNavigate":
            if let target = action.target {
                let paramsStr = action.params.map { params in
                    ", " + dynamicObjectLiteral(params)
                } ?? ""
                return "dk.navigateNative(\"\(target)\"\(paramsStr))"
            }
            return ""
        case "navigate":
            if action.target == "back" {
                return "dk.back()"
            } else if let target = action.target {
                return "dk.navigate(\"\(target)\")"
            }
            return ""
        case "toast":
            return "dk.toast(\"\(action.message ?? "")\")"
        case "track":
            return "dk.track(\"\(action.trackEvent ?? "")\")"
        case "setState":
            if let stateKey = action.stateKey, let value = action.value {
                let valueStr: String
                switch value {
                case .string(let s): valueStr = "\"\(s)\""
                case .bool(let b): valueStr = "\(b)"
                case .int(let i): valueStr = "\(i)"
                case .double(let d): valueStr = "\(d)"
                default: valueStr = "null"
                }
                return "dk.setState(\"\(stateKey)\", \(valueStr))"
            }
            return ""
        case "request":
            if let request = action.request {
                var options: [String] = []
                if let params = request.params, !params.isEmpty {
                    options.append("\"params\": \(dynamicObjectLiteral(params))")
                }
                if let responseKey = request.responseKey {
                    options.append("\"responseKey\": \"\(responseKey)\"")
                }
                if let showLoading = request.showLoading {
                    options.append("\"showLoading\": \(showLoading)")
                }
                if let loadingText = request.loadingText {
                    options.append("\"loadingText\": \"\(loadingText)\"")
                }
                if let successAction = request.successAction {
                    options.append("\"success\": () => { \(decompileAction(successAction)) }")
                }
                if let failureAction = request.failureAction {
                    options.append("\"fail\": () => { \(decompileAction(failureAction)) }")
                }
                let optionsStr = options.isEmpty ? "" : ", { \(options.joined(separator: ", ")) }"
                return "dk.request(\"\(request.apiKey)\"\(optionsStr))"
            }
            return ""
        case "showModal":
            if let target = action.target {
                var paramsStr = ""
                if let params = action.params, !params.isEmpty {
                    paramsStr = ", " + dynamicObjectLiteral(params)
                }
                return "dk.showModal(\"\(target)\"\(paramsStr))"
            }
            return ""
        default:
            return ""
        }
    }

    private static func dynamicObjectLiteral(_ params: [String: DynamicValue]) -> String {
        let entries = params.compactMap { key, value -> String? in
            let valStr: String
            switch value {
            case .string(let s): valStr = "\"\(s)\""
            case .bool(let b): valStr = "\(b)"
            case .int(let i): valStr = "\(i)"
            case .double(let d): valStr = "\(d)"
            default: return nil
            }
            return "\"\(key)\": \(valStr)"
        }.joined(separator: ", ")
        return "{ \(entries) }"
    }

    private static func decompileStyle(_ style: DynamicStyle, className: String) -> String? {
        var lines: [String] = []
        if let widthMode = style.widthMode {
            append("width", widthMode, to: &lines)
        } else {
            append("width", style.width, to: &lines)
        }
        append("height", style.height, to: &lines)
        if [style.marginTop, style.marginRight, style.marginBottom, style.marginLeft].contains(where: { $0 != nil }) {
            lines.append("  margin: \(format(style.marginTop)) \(format(style.marginRight)) \(format(style.marginBottom)) \(format(style.marginLeft));")
        }
        if [style.paddingTop, style.paddingRight, style.paddingBottom, style.paddingLeft].contains(where: { $0 != nil }) {
            lines.append("  padding: \(format(style.paddingTop)) \(format(style.paddingRight)) \(format(style.paddingBottom)) \(format(style.paddingLeft));")
        }
        append("background-color", style.backgroundColor, to: &lines)
        append("text-color", style.textColor, to: &lines)
        append("font-size", style.fontSize, to: &lines)
        append("font-weight", style.fontWeight, to: &lines)
        append("corner-radius", style.cornerRadius, to: &lines)
        append("border-width", style.borderWidth, to: &lines)
        append("border-color", style.borderColor, to: &lines)
        append("alignment", style.alignment, to: &lines)
        append("stack-alignment", style.stackAlignment, to: &lines)
        append("distribution", style.distribution, to: &lines)
        append("spacing", style.spacing, to: &lines)
        append("content-mode", style.contentMode, to: &lines)
        append("number-of-lines", style.numberOfLines, to: &lines)
        guard !lines.isEmpty else { return nil }
        return ".\(className) {\n\(lines.joined(separator: "\n"))\n}"
    }

    private static func append(_ name: String, _ value: CGFloat?, to lines: inout [String]) {
        guard let value else { return }
        lines.append("  \(name): \(format(value));")
    }

    private static func append(_ name: String, _ value: Int?, to lines: inout [String]) {
        guard let value else { return }
        lines.append("  \(name): \(value);")
    }

    private static func append(_ name: String, _ value: String?, to lines: inout [String]) {
        guard let value else { return }
        lines.append("  \(name): \(value);")
    }

    private static func format(_ value: CGFloat?) -> String {
        guard let value else { return "0" }
        return value.rounded() == value ? "\(Int(value))" : "\(value)"
    }

    private static func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func defaultJSText() -> String {
        """
        Page({
          data: {},
          methods: {}
        })
        """
    }
}

public struct DKMLNode: Equatable {
    public var name: String
    public var attributes: [String: String]
    public var children: [DKMLNode]
    public var text: String

    public var classNames: [String] {
        attributes["class"]?.split(separator: " ").map(String.init) ?? []
    }

    public var textContent: String {
        let combined = (text + children.map(\.textContent).joined()).trimmingCharacters(in: .whitespacesAndNewlines)
        return combined
    }
}

public enum DKMLParser {
    public static func parse(_ text: String) throws -> DKMLNode {
        let parser = Parser(text: text)
        return try parser.parse()
    }

    private final class Parser {
        private let chars: [Character]
        private var index = 0

        init(text: String) {
            chars = Array(text)
        }

        func parse() throws -> DKMLNode {
            skipWhitespace()
            let node = try parseNode()
            return node
        }

        private func parseNode() throws -> DKMLNode {
            try consume("<")
            guard !peek("/") else { throw DKError("unexpected closing tag") }
            let name = readName()
            var attributes: [String: String] = [:]

            while !isAtEnd, !peek(">"), !peek("/>") {
                skipWhitespace()
                if peek(">") || peek("/>") { break }
                let key = readAttributeName()
                guard !key.isEmpty else {
                    throw DKError("expected attribute name")
                }
                skipWhitespace()
                var value = ""
                if peek("=") {
                    try consume("=")
                    skipWhitespace()
                    value = try readQuotedValue()
                }
                attributes[key] = value
                skipWhitespace()
            }

            if peek("/>") {
                try consume("/>")
                return DKMLNode(name: name, attributes: attributes, children: [], text: "")
            }

            try consume(">")
            var children: [DKMLNode] = []
            var text = ""
            while !isAtEnd {
                if peek("</") {
                    try consume("</")
                    let closingName = readName()
                    guard closingName == name else {
                        throw DKError("tag \(name) closed by \(closingName)")
                    }
                    skipWhitespace()
                    try consume(">")
                    break
                } else if peek("<") {
                    children.append(try parseNode())
                } else {
                    text += readText()
                }
            }
            return DKMLNode(name: name, attributes: attributes, children: children, text: text)
        }

        private var isAtEnd: Bool { index >= chars.count }

        private func skipWhitespace() {
            while !isAtEnd, chars[index].isWhitespace {
                index += 1
            }
        }

        private func peek(_ value: String) -> Bool {
            let valueChars = Array(value)
            guard index + valueChars.count <= chars.count else { return false }
            return Array(chars[index..<index + valueChars.count]) == valueChars
        }

        private func consume(_ value: String) throws {
            guard peek(value) else { throw DKError("expected \(value)") }
            index += value.count
        }

        private func readName() -> String {
            readWhile { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        }

        private func readAttributeName() -> String {
            readWhile { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == ":" }
        }

        private func readQuotedValue() throws -> String {
            guard !isAtEnd, chars[index] == "\"" || chars[index] == "'" else {
                throw DKError("expected quoted attribute value")
            }
            let quote = chars[index]
            index += 1
            let value = readWhile { $0 != quote }
            if !isAtEnd { index += 1 }
            return value
        }

        private func readText() -> String {
            readWhile { $0 != "<" }
        }

        private func readWhile(_ predicate: (Character) -> Bool) -> String {
            var value = ""
            while !isAtEnd, predicate(chars[index]) {
                value.append(chars[index])
                index += 1
            }
            return value
        }
    }
}

public struct DKStyleSheet {
    public var rules: [String: DynamicStyle]
    public var diagnostics: [String]

    public func styles(for classNames: [String]) -> DynamicStyle? {
        classNames.reduce(nil) { partial, className in
            guard let next = rules[className] else { return partial }
            return partial?.merging(next) ?? next
        }
    }
}

public enum DKSSParser {
    public static func parse(_ text: String) -> DKStyleSheet {
        var rules: [String: DynamicStyle] = [:]
        var diagnostics: [String] = []
        let pattern = #"(?s)\.([A-Za-z0-9_-]+)\s*\{(.*?)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return DKStyleSheet(rules: [:], diagnostics: ["DKSS 正则初始化失败"])
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        regex.enumerateMatches(in: text, range: nsRange) { match, _, _ in
            guard
                let match,
                let classRange = Range(match.range(at: 1), in: text),
                let bodyRange = Range(match.range(at: 2), in: text)
            else { return }
            let className = String(text[classRange])
            let declarations = parseDeclarations(String(text[bodyRange]))
            rules[className] = style(from: declarations, diagnostics: &diagnostics)
        }
        return DKStyleSheet(rules: rules, diagnostics: diagnostics)
    }

    private static func parseDeclarations(_ body: String) -> [String: String] {
        body.split(separator: ";").reduce(into: [:]) { result, item in
            let parts = item.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if parts.count == 2 {
                result[parts[0]] = parts[1]
            }
        }
    }

    private static func style(from declarations: [String: String], diagnostics: inout [String]) -> DynamicStyle {
        let margin = boxValues(declarations["margin"])
        let padding = boxValues(declarations["padding"])
        let widthValue = declarations["width"]
        return DynamicStyle(
            width: number(widthValue),
            widthMode: widthMode(widthValue),
            height: number(declarations["height"]),
            marginTop: number(declarations["margin-top"]) ?? margin.top,
            marginBottom: number(declarations["margin-bottom"]) ?? margin.bottom,
            marginLeft: number(declarations["margin-left"]) ?? margin.left,
            marginRight: number(declarations["margin-right"]) ?? margin.right,
            paddingTop: number(declarations["padding-top"]) ?? padding.top,
            paddingBottom: number(declarations["padding-bottom"]) ?? padding.bottom,
            paddingLeft: number(declarations["padding-left"]) ?? padding.left,
            paddingRight: number(declarations["padding-right"]) ?? padding.right,
            backgroundColor: declarations["background-color"],
            textColor: declarations["text-color"] ?? declarations["color"],
            fontSize: number(declarations["font-size"]),
            fontWeight: declarations["font-weight"],
            cornerRadius: number(declarations["corner-radius"]) ?? number(declarations["border-radius"]),
            borderWidth: number(declarations["border-width"]),
            borderColor: declarations["border-color"],
            alignment: declarations["alignment"] ?? declarations["text-align"],
            stackAlignment: declarations["stack-alignment"],
            distribution: declarations["distribution"],
            spacing: number(declarations["spacing"]),
            contentMode: declarations["content-mode"],
            numberOfLines: declarations["number-of-lines"].flatMap(Int.init),
            hidden: declarations["hidden"].map { $0 == "true" || $0 == "1" }
        )
    }

    private static func number(_ value: String?) -> CGFloat? {
        guard var value else { return nil }
        value = value.replacingOccurrences(of: "px", with: "")
        guard let double = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return CGFloat(double)
    }

    private static func widthMode(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "fit-content", "hug-content", "content":
            return "fit-content"
        default:
            return nil
        }
    }

    private static func boxValues(_ value: String?) -> (top: CGFloat?, right: CGFloat?, bottom: CGFloat?, left: CGFloat?) {
        guard let value else { return (nil, nil, nil, nil) }
        let values = value.split(separator: " ").compactMap { number(String($0)) }
        switch values.count {
        case 1:
            return (values[0], values[0], values[0], values[0])
        case 2:
            return (values[0], values[1], values[0], values[1])
        case 3:
            return (values[0], values[1], values[2], values[1])
        default:
            return (values[safe: 0], values[safe: 1], values[safe: 2], values[safe: 3])
        }
    }
}

public struct DKJSParseResult {
    public var methods: [String: DynamicAction]
    public var diagnostics: [String]
}

public enum DKJSParser {
    public static func parse(_ text: String) -> DKJSParseResult {
        var methods: [String: DynamicAction] = [:]
        var diagnostics: [String] = []

        for (name, body) in methodBodies(in: text) {
            if let action = action(from: body) {
                methods[name] = action
            } else if !["Page", "methods"].contains(name) {
                diagnostics.append("JS method \(name) 暂未识别为可编译 action")
            }
        }

        return DKJSParseResult(methods: methods, diagnostics: diagnostics)
    }

    private static func action(from body: String) -> DynamicAction? {
        let calls = topLevelDKCalls(in: body)
        if calls.count > 1 {
            let actions = calls.compactMap(actionFromSingleCall)
            return actions.isEmpty ? nil : DynamicAction(type: "sequence", actions: actions)
        }
        if calls.count == 1 {
            return actionFromSingleCall(calls[0])
        }
        return actionFromSingleCall(body)
    }

    private static func actionFromSingleCall(_ body: String) -> DynamicAction? {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let delayArgs = arguments(function: "dk.delay", in: body)
        if trimmedBody.hasPrefix("dk.delay"), !delayArgs.isEmpty {
            let milliseconds = Int(delayArgs[0].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let delayedActions: [DynamicAction]?
            if delayArgs.count > 1 {
                let callbackSource = delayArgs.dropFirst().joined(separator: ",")
                let callback = callbackBody(from: callbackSource) ?? callbackSource
                if let delayedAction = action(from: callback) {
                    delayedActions = delayedAction.type == "sequence" ? delayedAction.actions : [delayedAction]
                } else {
                    delayedActions = nil
                }
            } else {
                delayedActions = nil
            }
            return DynamicAction(type: "delay", delayMilliseconds: milliseconds, actions: delayedActions)
        }

        let args = arguments(function: "dk.request", in: body)
        if !args.isEmpty {
            let apiKey = args[0].trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            var params: [String: DynamicValue]? = nil
            var responseKey: String? = nil
            var showLoading: Bool? = nil
            var loadingText: String? = nil
            var successAction: DynamicAction? = nil
            var failureAction: DynamicAction? = nil
            if args.count > 1 {
                let options = args[1]
                let fields = objectFields(in: options)
                params = objectValue(named: "params", in: fields)
                responseKey = stringValue(named: "responseKey", in: fields)
                showLoading = boolValue(named: "showLoading", in: fields)
                loadingText = stringValue(named: "loadingText", in: fields)
                if let successBody = extractCallback(named: "success", in: options) {
                    successAction = action(from: successBody)
                }
                if let failureBody = extractCallback(named: "fail", in: options) ?? extractCallback(named: "failure", in: options) {
                    failureAction = action(from: failureBody)
                }
            }
            let request = DynamicRequest(
                id: nil,
                apiKey: apiKey,
                params: params,
                responseKey: responseKey,
                showLoading: showLoading,
                loadingText: loadingText,
                successAction: successAction,
                failureAction: failureAction
            )
            return DynamicAction(type: "request", request: request)
        }

        if let target = firstArgument(function: "dk.navigateNative", in: body) {
            return DynamicAction(type: "nativeNavigate", target: target, params: objectArgument(after: target, in: body))
        }
        if let target = firstArgument(function: "dk.navigate", in: body) {
            return DynamicAction(type: "navigate", target: target, params: objectArgument(after: target, in: body))
        }
        if body.contains("dk.back") {
            return DynamicAction(type: "navigate", target: "back")
        }
        if let message = firstArgument(function: "dk.toast", in: body) {
            return DynamicAction(type: "toast", message: message)
        }
        if let event = firstArgument(function: "dk.track", in: body) {
            return DynamicAction(type: "track", trackEvent: event)
        }
        if let stateKey = firstArgument(function: "dk.setState", in: body) {
            let value = secondArgument(function: "dk.setState", in: body).map(DynamicValue.string)
            return DynamicAction(type: "setState", stateKey: stateKey, value: value)
        }
        if let target = firstArgument(function: "dk.showModal", in: body) {
            return DynamicAction(type: "showModal", target: target, params: objectArgument(after: target, in: body))
        }
        return nil
    }

    private static func callbackBody(from text: String) -> String? {
        let chars = Array(text)
        var index = 0
        skipWhitespace(chars, &index)

        if matches(chars, at: index, token: "function") {
            index += "function".count
            skipWhitespace(chars, &index)
            if index < chars.count, chars[index] == "(" {
                skipBalanced(chars, &index, open: "(", close: ")")
                skipWhitespace(chars, &index)
            }
        } else if index < chars.count, chars[index] == "(" {
            skipBalanced(chars, &index, open: "(", close: ")")
            skipWhitespace(chars, &index)
        }

        if index + 2 <= chars.count, chars[index] == "=", chars[index + 1] == ">" {
            index += 2
            skipWhitespace(chars, &index)
        }

        guard index < chars.count else { return nil }
        if chars[index] == "{" {
            let bodyStart = index + 1
            skipBalanced(chars, &index, open: "{", close: "}")
            let bodyEnd = max(bodyStart, index - 1)
            return String(chars[bodyStart..<bodyEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let body = String(chars[index...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? nil : body
    }

    private static func topLevelDKCalls(in body: String) -> [String] {
        let chars = Array(body)
        var index = 0
        var calls: [String] = []
        var quote: Character?
        var isEscaping = false

        while index < chars.count {
            let character = chars[index]
            if let activeQuote = quote {
                if isEscaping {
                    isEscaping = false
                } else if character == "\\" {
                    isEscaping = true
                } else if character == activeQuote {
                    quote = nil
                }
                index += 1
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
                index += 1
                continue
            }

            guard matches(chars, at: index, token: "dk.") else {
                index += 1
                continue
            }

            let callStart = index
            index += 3
            guard index < chars.count, isIdentifierStart(chars[index]) else {
                index = callStart + 1
                continue
            }
            while index < chars.count, isIdentifierPart(chars[index]) {
                index += 1
            }
            skipWhitespace(chars, &index)
            guard index < chars.count, chars[index] == "(" else {
                index = callStart + 1
                continue
            }
            skipBalanced(chars, &index, open: "(", close: ")")
            calls.append(String(chars[callStart..<index]))
        }

        return calls
    }

    private static func extractCallback(named name: String, in text: String) -> String? {
        let chars = Array(text)
        var startIdx = 0
        
        while startIdx < chars.count {
            // Find occurrences of the name starting at startIdx
            let substring = String(chars[startIdx...])
            guard let range = substring.range(of: name) else {
                return nil
            }
            let relativeLower = substring.distance(from: substring.startIndex, to: range.lowerBound)
            let relativeUpper = substring.distance(from: substring.startIndex, to: range.upperBound)
            
            let nameStartOffset = startIdx + relativeLower
            let nameEndOffset = startIdx + relativeUpper
            
            // Verify word boundary
            let beforeWordOk = nameStartOffset == 0 || !isIdentifierPart(chars[nameStartOffset - 1])
            let afterWordOk = nameEndOffset == chars.count || !isIdentifierPart(chars[nameEndOffset])
            
            if beforeWordOk && afterWordOk {
                var idx = nameEndOffset
                skipWhitespace(chars, &idx)
                
                // Must be followed by ":" or "(" or "{" or "=>" or "function"
                var isValidProperty = false
                if idx < chars.count {
                    let nextChar = chars[idx]
                    if nextChar == ":" || nextChar == "(" || nextChar == "{" {
                        isValidProperty = true
                    } else if idx + 8 <= chars.count, String(chars[idx..<idx+8]) == "function" {
                        isValidProperty = true
                    }
                }
                
                if isValidProperty {
                    if idx < chars.count, chars[idx] == ":" {
                        idx += 1
                        skipWhitespace(chars, &idx)
                    }
                    
                    if idx < chars.count, chars[idx] == "(" {
                        skipBalanced(chars, &idx, open: "(", close: ")")
                        skipWhitespace(chars, &idx)
                    }
                    
                    if idx + 8 <= chars.count, String(chars[idx..<idx+8]) == "function" {
                        idx += 8
                        skipWhitespace(chars, &idx)
                        if idx < chars.count, chars[idx] == "(" {
                            skipBalanced(chars, &idx, open: "(", close: ")")
                            skipWhitespace(chars, &idx)
                        }
                    }
                    
                    if idx + 2 <= chars.count, chars[idx] == "=", chars[idx+1] == ">" {
                        idx += 2
                        skipWhitespace(chars, &idx)
                    }
                    
                    guard idx < chars.count, chars[idx] == "{" else {
                        startIdx = nameEndOffset
                        continue
                    }
                    
                    let bodyStart = idx + 1
                    skipBalanced(chars, &idx, open: "{", close: "}")
                    let bodyEnd = max(bodyStart, idx - 1)
                    return String(chars[bodyStart..<bodyEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            startIdx = nameEndOffset
        }
        return nil
    }

    private static func methodBodies(in text: String) -> [(String, String)] {
        if let methodsObject = objectBody(named: "methods", in: text) {
            return methodBodiesFromObject(methodsObject)
        }

        var result: [(String, String)] = []
        let chars = Array(text)
        var index = 0

        while index < chars.count {
            guard isIdentifierStart(chars[index]) else {
                index += 1
                continue
            }

            let nameStart = index
            while index < chars.count, isIdentifierPart(chars[index]) {
                index += 1
            }
            let name = String(chars[nameStart..<index])
            skipWhitespace(chars, &index)
            guard index < chars.count, chars[index] == "(" else {
                index = nameStart + 1
                continue
            }

            var lookahead = index
            skipBalanced(chars, &lookahead, open: "(", close: ")")
            skipWhitespace(chars, &lookahead)
            guard lookahead < chars.count, chars[lookahead] == "{" else {
                index = nameStart + 1
                continue
            }

            index = lookahead
            let bodyStart = index + 1
            skipBalanced(chars, &index, open: "{", close: "}")
            let bodyEnd = max(bodyStart, index - 1)
            result.append((name, String(chars[bodyStart..<bodyEnd])))
        }

        return result
    }

    private static func objectBody(named name: String, in text: String) -> String? {
        guard let nameRange = text.range(of: name) else { return nil }
        var cursor = nameRange.upperBound
        while cursor < text.endIndex, text[cursor].isWhitespace {
            cursor = text.index(after: cursor)
        }
        guard cursor < text.endIndex, text[cursor] == ":" else { return nil }
        cursor = text.index(after: cursor)
        while cursor < text.endIndex, text[cursor].isWhitespace {
            cursor = text.index(after: cursor)
        }
        guard cursor < text.endIndex, text[cursor] == "{" else { return nil }

        let chars = Array(text)
        let startOffset = text.distance(from: text.startIndex, to: cursor)
        var index = startOffset
        let bodyStart = index + 1
        skipBalanced(chars, &index, open: "{", close: "}")
        let bodyEnd = max(bodyStart, index - 1)
        return String(chars[bodyStart..<bodyEnd])
    }

    private static func methodBodiesFromObject(_ objectText: String) -> [(String, String)] {
        var result: [(String, String)] = []
        let chars = Array(objectText)
        var index = 0

        while index < chars.count {
            skipWhitespaceAndCommas(chars, &index)
            guard index < chars.count, isIdentifierStart(chars[index]) else {
                index += 1
                continue
            }

            let nameStart = index
            while index < chars.count, isIdentifierPart(chars[index]) {
                index += 1
            }
            let name = String(chars[nameStart..<index])
            skipWhitespace(chars, &index)

            if index < chars.count, chars[index] == "(" {
                var lookahead = index
                skipBalanced(chars, &lookahead, open: "(", close: ")")
                skipWhitespace(chars, &lookahead)
                guard lookahead < chars.count, chars[lookahead] == "{" else {
                    index = max(index + 1, lookahead)
                    continue
                }
                index = lookahead
                let bodyStart = index + 1
                skipBalanced(chars, &index, open: "{", close: "}")
                let bodyEnd = max(bodyStart, index - 1)
                result.append((name, String(chars[bodyStart..<bodyEnd])))
                continue
            }

            guard index < chars.count, chars[index] == ":" else {
                index = nameStart + 1
                continue
            }
            index += 1
            skipWhitespace(chars, &index)

            if matches(chars, at: index, token: "function") {
                index += "function".count
                skipWhitespace(chars, &index)
                if index < chars.count, chars[index] == "(" {
                    skipBalanced(chars, &index, open: "(", close: ")")
                }
                skipWhitespace(chars, &index)
                guard index < chars.count, chars[index] == "{" else { continue }
                let bodyStart = index + 1
                skipBalanced(chars, &index, open: "{", close: "}")
                let bodyEnd = max(bodyStart, index - 1)
                result.append((name, String(chars[bodyStart..<bodyEnd])))
                continue
            }

            if index < chars.count, chars[index] == "(" {
                skipBalanced(chars, &index, open: "(", close: ")")
                skipWhitespace(chars, &index)
            } else if index < chars.count, isIdentifierStart(chars[index]) {
                while index < chars.count, isIdentifierPart(chars[index]) {
                    index += 1
                }
                skipWhitespace(chars, &index)
            }

            guard index + 1 < chars.count, chars[index] == "=", chars[index + 1] == ">" else { continue }
            index += 2
            skipWhitespace(chars, &index)
            if index < chars.count, chars[index] == "{" {
                let bodyStart = index + 1
                skipBalanced(chars, &index, open: "{", close: "}")
                let bodyEnd = max(bodyStart, index - 1)
                result.append((name, String(chars[bodyStart..<bodyEnd])))
            } else {
                let bodyStart = index
                while index < chars.count, chars[index] != "," {
                    index += 1
                }
                result.append((name, String(chars[bodyStart..<index])))
            }
        }

        return result
    }

    private static func firstArgument(function: String, in text: String) -> String? {
        arguments(function: function, in: text).first
    }

    private static func secondArgument(function: String, in text: String) -> String? {
        arguments(function: function, in: text).dropFirst().first
    }

    private static func arguments(function: String, in text: String) -> [String] {
        guard let range = text.range(of: "\(function)(") else { return [] }
        var cursor = range.upperBound
        var args: [String] = []
        var currentRaw = ""
        var depth = 1
        var quote: Character?
        var isEscaping = false

        func appendCurrentArgument() {
            let raw = currentRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.isEmpty {
                args.append(raw)
            }
            currentRaw = ""
        }

        while cursor < text.endIndex {
            let character = text[cursor]

            if let activeQuote = quote {
                if isEscaping {
                    currentRaw.append(character)
                    isEscaping = false
                } else if character == "\\" {
                    isEscaping = true
                } else if character == activeQuote {
                    quote = nil
                } else {
                    currentRaw.append(character)
                }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == "(" || character == "{" || character == "[" {
                depth += 1
                currentRaw.append(character)
            } else if character == ")" {
                depth -= 1
                if depth == 0 {
                    appendCurrentArgument()
                    break
                }
                currentRaw.append(character)
            } else if character == "}" || character == "]" {
                depth = max(1, depth - 1)
                currentRaw.append(character)
            } else if character == ",", depth == 1 {
                appendCurrentArgument()
            } else {
                currentRaw.append(character)
            }

            cursor = text.index(after: cursor)
        }
        return args
    }

    private static func objectArgument(after first: String, in text: String) -> [String: DynamicValue]? {
        guard let openRange = text.range(of: "{") else {
            return nil
        }
        let chars = Array(text)
        let openOffset = text.distance(from: text.startIndex, to: openRange.lowerBound)
        var closeOffset = openOffset
        skipBalanced(chars, &closeOffset, open: "{", close: "}")
        guard closeOffset > openOffset + 1 else { return nil }
        let body = String(chars[(openOffset + 1)..<(closeOffset - 1)])
        let parsedParams = dynamicObjectValues(fromBody: body)
        if !parsedParams.isEmpty {
            return parsedParams
        }
        
        var params: [String: DynamicValue] = [:]
        body.split(separator: ",").forEach { item in
            let parts = item.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                let value = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                params[key] = .string(value)
            }
        }
        return params.isEmpty ? nil : params
    }

    private static func objectFields(in text: String) -> [String: String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: String
        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            body = String(trimmed.dropFirst().dropLast())
        } else {
            body = trimmed
        }

        var fields: [String: String] = [:]
        splitTopLevel(body, separator: ",").forEach { item in
            let parts = splitTopLevel(item, separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return }
            let key = unquote(parts[0].trimmingCharacters(in: .whitespacesAndNewlines))
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return }
            fields[key] = value
        }
        return fields
    }

    private static func objectValue(named name: String, in fields: [String: String]) -> [String: DynamicValue]? {
        guard let raw = fields[name] else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), trimmed.hasSuffix("}") else { return nil }
        let body = String(trimmed.dropFirst().dropLast())
        let value = dynamicObjectValues(fromBody: body)
        return value.isEmpty ? nil : value
    }

    private static func dynamicObjectValues(fromBody body: String) -> [String: DynamicValue] {
        var values: [String: DynamicValue] = [:]
        objectFields(in: body).forEach { key, rawValue in
            values[key] = dynamicValue(from: rawValue)
        }
        return values
    }

    private static func dynamicValue(from rawValue: String) -> DynamicValue {
        let raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let unquoted = unquote(raw)
        if raw.hasPrefix("{{"), raw.hasSuffix("}}") {
            return .string(unquoted)
        }
        if raw == "true" { return .bool(true) }
        if raw == "false" { return .bool(false) }
        if let intValue = Int(raw) { return .int(intValue) }
        if let doubleValue = Double(raw) { return .double(doubleValue) }
        if raw.hasPrefix("{"), raw.hasSuffix("}") {
            let body = String(raw.dropFirst().dropLast())
            return .object(dynamicObjectValues(fromBody: body))
        }
        return .string(unquoted)
    }

    private static func stringValue(named name: String, in fields: [String: String]) -> String? {
        fields[name].map { unquote($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private static func boolValue(named name: String, in fields: [String: String]) -> Bool? {
        guard let raw = fields[name]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return nil }
        switch raw {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    private static func unquote(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.count >= 2,
           let first = result.first,
           let last = result.last,
           (first == "\"" || first == "'"),
           first == last {
            result.removeFirst()
            result.removeLast()
        }
        return result
    }

    private static func splitTopLevel(_ text: String, separator: Character, maxSplits: Int = Int.max) -> [String] {
        var result: [String] = []
        var current = ""
        var depth = 0
        var quote: Character?
        var isEscaping = false
        var splits = 0

        for character in text {
            if let activeQuote = quote {
                current.append(character)
                if isEscaping {
                    isEscaping = false
                } else if character == "\\" {
                    isEscaping = true
                } else if character == activeQuote {
                    quote = nil
                }
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
                current.append(character)
            } else if character == "{" || character == "[" || character == "(" {
                depth += 1
                current.append(character)
            } else if character == "}" || character == "]" || character == ")" {
                depth = max(0, depth - 1)
                current.append(character)
            } else if character == separator, depth == 0, splits < maxSplits {
                result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
                splits += 1
            } else {
                current.append(character)
            }
        }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            result.append(tail)
        }
        return result
    }

    private static func isIdentifierStart(_ char: Character) -> Bool {
        char.isLetter || char == "_"
    }

    private static func isIdentifierPart(_ char: Character) -> Bool {
        char.isLetter || char.isNumber || char == "_"
    }

    private static func skipWhitespace(_ chars: [Character], _ index: inout Int) {
        while index < chars.count, chars[index].isWhitespace {
            index += 1
        }
    }

    private static func skipWhitespaceAndCommas(_ chars: [Character], _ index: inout Int) {
        while index < chars.count, chars[index].isWhitespace || chars[index] == "," {
            index += 1
        }
    }

    private static func matches(_ chars: [Character], at index: Int, token: String) -> Bool {
        let tokenChars = Array(token)
        guard index + tokenChars.count <= chars.count else { return false }
        return Array(chars[index..<(index + tokenChars.count)]) == tokenChars
    }

    private static func skipBalanced(_ chars: [Character], _ index: inout Int, open: Character, close: Character) {
        var depth = 0
        var inString: Character?
        while index < chars.count {
            let char = chars[index]
            if let quote = inString {
                if char == quote {
                    inString = nil
                }
            } else if char == "\"" || char == "'" {
                inString = char
            } else if char == open {
                depth += 1
            } else if char == close {
                depth -= 1
                index += 1
                if depth == 0 {
                    return
                }
                continue
            }
            index += 1
        }
    }
}

public struct DKError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? {
        message
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
