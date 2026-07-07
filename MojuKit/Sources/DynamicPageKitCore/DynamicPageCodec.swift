import Foundation

public enum DynamicPageCodec {
    public static func prettyJSON(from page: DynamicPage) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(page)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    public static func page(from jsonText: String) throws -> DynamicPage {
        guard let data = jsonText.data(using: .utf8) else {
            throw DynamicPageKitError.invalidJSON
        }
        return try DynamicPageValidator.decodePage(from: data)
    }

    public static func swiftDSL(from page: DynamicPage) throws -> String {
        let components = try componentDSL(from: page.components, indentation: "        ")
        let fixedBottomComponents = try componentDSL(from: page.fixedBottomComponents ?? [], indentation: "        ")

        return """
        import DynamicPageKitCore

        let page = DynamicPageSpec(
            schemaVersion: "\(escape(page.schemaVersion))",
            pageId: "\(escape(page.pageId ?? ""))",
            pageTitle: "\(escape(page.pageTitle ?? ""))",
            components: [
        \(components)
            ],
            fixedBottomComponents: [
        \(fixedBottomComponents)
            ]
        )
        """
    }

    public static func jsonFromSwiftDSL(_ swiftText: String) throws -> String {
        if
            let startRange = swiftText.range(of: "DynamicPageSpec(json: \"\"\""),
            let endRange = swiftText.range(of: "\"\"\")", range: startRange.upperBound..<swiftText.endIndex)
        {
            let json = String(swiftText[startRange.upperBound..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try page(from: json)
            return json
        }

        let schemaVersion = fieldValue("schemaVersion", in: swiftText) ?? "1.0"
        let pageId = emptyToNil(fieldValue("pageId", in: swiftText))
        let pageTitle = emptyToNil(fieldValue("pageTitle", in: swiftText))
        let components = try parseComponents(in: arrayBody(named: "components", in: swiftText) ?? "")
        let fixedBottomComponents = try parseComponents(in: arrayBody(named: "fixedBottomComponents", in: swiftText) ?? "")

        let page = DynamicPage(
            schemaVersion: schemaVersion,
            pageId: pageId,
            pageTitle: pageTitle,
            components: components,
            fixedBottomComponents: fixedBottomComponents.isEmpty ? nil : fixedBottomComponents
        )
        try DynamicPageValidator.validate(page)
        return try prettyJSON(from: page)
    }

    private static func componentDSL(from components: [DynamicComponent], indentation: String) throws -> String {
        guard !components.isEmpty else { return "" }

        return try components.map { component in
            switch component.type {
            case "text":
                return "\(indentation).text(\"\(escape(component.text ?? ""))\"),"
            case "button":
                if let action = component.action, action.type == "navigate", let target = action.target, action.params == nil {
                    return "\(indentation).button(\"\(escape(component.text ?? ""))\", action: .navigate(\"\(escape(target))\")),"
                }
                return "\(indentation).button(\"\(escape(component.text ?? ""))\"),"
            case "image":
                return "\(indentation).image(\"\(escape(component.imageUrl ?? ""))\"),"
            case "space":
                return "\(indentation).space(height: \(Int(component.style?.height ?? 12))),"
            default:
                let json = try prettyJSON(from: component)
                return "\(indentation).rawJSON(\"\(escape(json))\"),"
            }
        }
        .joined(separator: "\n")
    }

    private static func prettyJSON(from component: DynamicComponent) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(component)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func parseComponents(in body: String) throws -> [DynamicComponent] {
        var components: [DynamicComponent] = []
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var index = 0

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)

            if line.hasPrefix(".text(") {
                components.append(DynamicComponent(type: "text", text: firstQuotedString(in: line)))
            } else if line.hasPrefix(".button(") {
                let title = firstQuotedString(in: line)
                let target = navigateTarget(in: line)
                let action = target.map { DynamicAction(type: "navigate", target: $0) }
                components.append(DynamicComponent(type: "button", text: title, action: action))
            } else if line.hasPrefix(".image(") {
                components.append(DynamicComponent(type: "image", imageUrl: firstQuotedString(in: line)))
            } else if line.hasPrefix(".space(") {
                let height = numberAfter("height:", in: line) ?? 12
                let style = DynamicStyle(height: height)
                components.append(DynamicComponent(type: "space", style: style))
            } else if line.hasPrefix(".rawJSON(\"\"\"") {
                var rawLines: [String] = []
                index += 1
                while index < lines.count {
                    let rawLine = lines[index]
                    if rawLine.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("\"\"\"") {
                        break
                    }
                    rawLines.append(rawLine)
                    index += 1
                }
                let data = Data(rawLines.joined(separator: "\n").utf8)
                components.append(try JSONDecoder().decode(DynamicComponent.self, from: data))
            } else if line.hasPrefix(".rawJSON("), let json = firstQuotedString(in: line) {
                let data = Data(json.utf8)
                components.append(try JSONDecoder().decode(DynamicComponent.self, from: data))
            }

            index += 1
        }

        return components
    }

    private static func fieldValue(_ name: String, in text: String) -> String? {
        guard
            let nameRange = text.range(of: "\(name):"),
            let value = firstQuotedString(in: String(text[nameRange.upperBound...]))
        else {
            return nil
        }
        return value
    }

    private static func arrayBody(named name: String, in text: String) -> String? {
        guard
            let nameRange = text.range(of: "\(name):"),
            let start = text[nameRange.upperBound...].firstIndex(of: "[")
        else {
            return nil
        }

        var depth = 0
        var isInString = false
        var previous: Character?
        var cursor = start

        while cursor < text.endIndex {
            let character = text[cursor]
            if character == "\"", previous != "\\" {
                isInString.toggle()
            }
            if !isInString {
                if character == "[" {
                    depth += 1
                } else if character == "]" {
                    depth -= 1
                    if depth == 0 {
                        return String(text[text.index(after: start)..<cursor])
                    }
                }
            }
            previous = character
            cursor = text.index(after: cursor)
        }

        return nil
    }

    private static func firstQuotedString(in text: String) -> String? {
        guard let start = text.firstIndex(of: "\"") else { return nil }
        var result = ""
        var cursor = text.index(after: start)
        var isEscaped = false

        while cursor < text.endIndex {
            let character = text[cursor]
            if isEscaped {
                switch character {
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                default: result.append(character)
                }
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else if character == "\"" {
                return result
            } else {
                result.append(character)
            }
            cursor = text.index(after: cursor)
        }

        return nil
    }

    private static func navigateTarget(in line: String) -> String? {
        guard let range = line.range(of: ".navigate(") else { return nil }
        return firstQuotedString(in: String(line[range.upperBound...]))
    }

    private static func numberAfter(_ marker: String, in line: String) -> Double? {
        guard let range = line.range(of: marker) else { return nil }
        let suffix = line[range.upperBound...]
        let numberText = suffix.prefix { character in
            character.isNumber || character == "."
        }
        return Double(numberText)
    }

    private static func emptyToNil(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

public struct DynamicPageSpec {
    public let schemaVersion: String
    public let pageId: String?
    public let pageTitle: String?
    public let components: [DynamicComponent]
    public let fixedBottomComponents: [DynamicComponent]?
    public let json: String?

    public init(json: String) {
        self.schemaVersion = "1.0"
        self.pageId = nil
        self.pageTitle = nil
        self.components = []
        self.fixedBottomComponents = nil
        self.json = json
    }

    public init(
        schemaVersion: String,
        pageId: String? = nil,
        pageTitle: String? = nil,
        components: [DynamicComponent],
        fixedBottomComponents: [DynamicComponent]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.pageId = pageId
        self.pageTitle = pageTitle
        self.components = components
        self.fixedBottomComponents = fixedBottomComponents
        self.json = nil
    }
}

public extension DynamicComponent {
    static func text(_ value: String) -> DynamicComponent {
        DynamicComponent(type: "text", text: value)
    }

    static func button(_ title: String, action: DynamicAction? = nil) -> DynamicComponent {
        DynamicComponent(type: "button", text: title, action: action)
    }

    static func image(_ url: String) -> DynamicComponent {
        DynamicComponent(type: "image", imageUrl: url)
    }

    static func space(height: Double) -> DynamicComponent {
        DynamicComponent(type: "space", style: DynamicStyle(height: height))
    }

    static func rawJSON(_ json: String) -> DynamicComponent {
        guard let data = json.data(using: .utf8),
              let component = try? JSONDecoder().decode(DynamicComponent.self, from: data) else {
            return DynamicComponent(type: "text", text: "Unsupported rawJSON")
        }
        return component
    }
}

public extension DynamicAction {
    static func navigate(_ target: String) -> DynamicAction {
        DynamicAction(type: "navigate", target: target)
    }
}
