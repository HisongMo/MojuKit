import Foundation

public enum MojuSchemaValidator {
    private static let supportedMajorVersion = 1

    public static func validate(_ page: MojuPage) throws {
        let major = page.schemaVersion.split(separator: ".").first.flatMap { Int($0) }
        guard major == supportedMajorVersion else {
            throw MojuPageError.unsupportedSchemaVersion
        }

        let count = countComponents(page.components) + countComponents(page.fixedBottomComponents ?? [])
        guard count <= MojuPageLimits.maxComponentCount else {
            throw MojuPageError.tooManyComponents
        }

        let contentDepth = maxDepth(page.components)
        let fixedBottomDepth = maxDepth(page.fixedBottomComponents ?? [])
        guard max(contentDepth, fixedBottomDepth) <= MojuPageLimits.maxRecursionDepth else {
            throw MojuPageError.recursionTooDeep
        }
    }

    public static func decodePage(from data: Data) throws -> MojuPage {
        guard data.count <= MojuPageLimits.maxJSONSize else {
            throw MojuPageError.invalidJSON
        }

        do {
            let page = try JSONDecoder().decode(MojuPage.self, from: data)
            try validate(page)
            return page
        } catch let error as MojuPageError {
            throw error
        } catch {
            throw MojuPageError.invalidJSON
        }
    }

    private static func countComponents(_ components: [MojuComponent]) -> Int {
        components.reduce(0) { result, component in
            result + 1 + countComponents(component.children ?? [])
        }
    }

    private static func maxDepth(_ components: [MojuComponent], currentDepth: Int = 1) -> Int {
        components.reduce(currentDepth) { result, component in
            max(result, maxDepth(component.children ?? [], currentDepth: currentDepth + 1))
        }
    }
}
