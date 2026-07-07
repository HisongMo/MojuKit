import Foundation

public enum DynamicPageKitError: Error, LocalizedError, Equatable {
    case invalidJSON
    case unsupportedSchemaVersion
    case tooManyComponents
    case recursionTooDeep
    case invalidDSL

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "JSON 解析失败"
        case .unsupportedSchemaVersion:
            return "不支持的 schemaVersion"
        case .tooManyComponents:
            return "组件数量超过限制"
        case .recursionTooDeep:
            return "组件嵌套层级超过限制"
        case .invalidDSL:
            return "Swift DSL 解析失败"
        }
    }
}

public enum DynamicPageKitLimits {
    public static let maxJSONSize = 1_048_576
    public static let maxComponentCount = 200
    public static let maxRecursionDepth = 10
}

public enum DynamicPageValidator {
    public static func decodePage(from data: Data) throws -> DynamicPage {
        guard data.count <= DynamicPageKitLimits.maxJSONSize else {
            throw DynamicPageKitError.invalidJSON
        }

        do {
            let page = try JSONDecoder().decode(DynamicPage.self, from: data)
            try validate(page)
            return page
        } catch let error as DynamicPageKitError {
            throw error
        } catch {
            throw DynamicPageKitError.invalidJSON
        }
    }

    public static func validate(_ page: DynamicPage) throws {
        let major = page.schemaVersion.split(separator: ".").first.flatMap { Int($0) }
        guard major == 1 else {
            throw DynamicPageKitError.unsupportedSchemaVersion
        }

        let count = countComponents(page.components) + countComponents(page.fixedBottomComponents ?? [])
        guard count <= DynamicPageKitLimits.maxComponentCount else {
            throw DynamicPageKitError.tooManyComponents
        }

        let depth = max(maxDepth(page.components), maxDepth(page.fixedBottomComponents ?? []))
        guard depth <= DynamicPageKitLimits.maxRecursionDepth else {
            throw DynamicPageKitError.recursionTooDeep
        }
    }

    private static func countComponents(_ components: [DynamicComponent]) -> Int {
        components.reduce(0) { result, component in
            result + 1 + countComponents(component.children ?? [])
        }
    }

    private static func maxDepth(_ components: [DynamicComponent], currentDepth: Int = 1) -> Int {
        components.reduce(currentDepth) { result, component in
            max(result, maxDepth(component.children ?? [], currentDepth: currentDepth + 1))
        }
    }
}
