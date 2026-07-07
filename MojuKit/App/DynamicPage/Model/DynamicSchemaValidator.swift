import Foundation

enum DynamicSchemaValidator {
    private static let supportedMajorVersion = 1

    static func validate(_ page: DynamicPage) throws {
        let major = page.schemaVersion.split(separator: ".").first.flatMap { Int($0) }
        guard major == supportedMajorVersion else {
            throw DynamicPageError.unsupportedSchemaVersion
        }

        let count = countComponents(page.components) + countComponents(page.fixedBottomComponents ?? [])
        guard count <= DynamicPageLimits.maxComponentCount else {
            throw DynamicPageError.tooManyComponents
        }

        let contentDepth = maxDepth(page.components)
        let fixedBottomDepth = maxDepth(page.fixedBottomComponents ?? [])
        guard max(contentDepth, fixedBottomDepth) <= DynamicPageLimits.maxRecursionDepth else {
            throw DynamicPageError.recursionTooDeep
        }
    }

    static func decodePage(from data: Data) throws -> DynamicPage {
        guard data.count <= DynamicPageLimits.maxJSONSize else {
            throw DynamicPageError.invalidJSON
        }

        do {
            let page = try JSONDecoder().decode(DynamicPage.self, from: data)
            try validate(page)
            return page
        } catch let error as DynamicPageError {
            throw error
        } catch {
            throw DynamicPageError.invalidJSON
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
