import DynamicPageKitCore
import Foundation

private struct CLIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private struct CompilePageOutput: Encodable {
    let success: Bool
    let pageName: String
    let pageId: String?
    let jsonText: String
    let page: DynamicPage?
    let diagnostics: [String]
}

private struct CompileProjectOutput: Encodable {
    struct Page: Encodable {
        let name: String
        let pageId: String?
        let path: String
        let jsonText: String
        let diagnostics: [String]
    }

    let success: Bool
    let activePage: String?
    let activePageJSON: String?
    let pages: [Page]
    let diagnostics: [String]
}

private struct DecompileJSONOutput: Encodable {
    let success: Bool
    let outDir: String
}

private enum CLI {
    static func run() throws {
        var args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else {
            throw CLIError(message: usage)
        }
        args.removeFirst()

        switch command {
        case "compile-page":
            let pageDir = try requiredValue("--page-dir", in: args)
            let output = try compilePage(pageDirectory: URL(fileURLWithPath: pageDir, isDirectory: true))
            try printJSON(output)
        case "compile-project":
            let projectDir = try requiredValue("--project-dir", in: args)
            let active = value("--active", in: args)
            let output = try compileProject(projectDirectory: URL(fileURLWithPath: projectDir, isDirectory: true), active: active)
            try printJSON(output)
        case "decompile-json":
            let jsonPath = try requiredValue("--json", in: args)
            let outputPath = try requiredValue("--out-dir", in: args)
            try decompileJSON(jsonURL: URL(fileURLWithPath: jsonPath), outputDirectory: URL(fileURLWithPath: outputPath, isDirectory: true))
            try printJSON(DecompileJSONOutput(success: true, outDir: outputPath))
        case "format":
            let kind = try requiredValue("--kind", in: args)
            let file = try requiredValue("--file", in: args)
            let text = try String(contentsOfFile: file, encoding: .utf8)
            print(format(kind: kind, text: text), terminator: "")
        default:
            throw CLIError(message: "未知命令：\(command)\n\(usage)")
        }
    }

    private static var usage: String {
        """
        DynamicPageKitCLI
          compile-page --page-dir <dir>
          compile-project --project-dir <dir> --active <pageName>
          decompile-json --json <file> --out-dir <dir>
          format --kind dkml|dkss|js|json --file <file>
        """
    }

    private static func compilePage(pageDirectory: URL) throws -> CompilePageOutput {
        let source = try source(in: pageDirectory)
        let result = DKPageCompiler.compile(source)
        let jsonText = result.page.flatMap { try? DynamicPageCodec.prettyJSON(from: $0) } ?? ""
        return CompilePageOutput(
            success: result.page != nil,
            pageName: pageDirectory.lastPathComponent,
            pageId: result.page?.pageId,
            jsonText: jsonText,
            page: result.page,
            diagnostics: result.diagnostics
        )
    }

    private static func compileProject(projectDirectory: URL, active: String?) throws -> CompileProjectOutput {
        let pagesRoot = FileManager.default.fileExists(atPath: projectDirectory.appendingPathComponent("pages").path)
            ? projectDirectory.appendingPathComponent("pages", isDirectory: true)
            : projectDirectory
        let directories = try pageDirectories(in: pagesRoot)
        let pages = directories.compactMap { directory -> CompileProjectOutput.Page? in
            guard let output = try? compilePage(pageDirectory: directory), !output.jsonText.isEmpty else { return nil }
            return CompileProjectOutput.Page(
                name: output.pageName,
                pageId: output.pageId,
                path: directory.path,
                jsonText: output.jsonText,
                diagnostics: output.diagnostics
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        let activePage = active.flatMap { target in page(named: target, in: pages) } ?? pages.first
        return CompileProjectOutput(
            success: activePage != nil,
            activePage: activePage?.name,
            activePageJSON: activePage?.jsonText,
            pages: pages,
            diagnostics: activePage == nil ? ["没有找到可编译页面"] : ["编译通过"]
        )
    }

    private static func decompileJSON(jsonURL: URL, outputDirectory: URL) throws {
        let jsonText = try String(contentsOf: jsonURL, encoding: .utf8)
        let page = try DynamicPageCodec.page(from: jsonText)
        let source = DKPageCompiler.decompile(page: page)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        try source.dkmlText.write(to: outputDirectory.appendingPathComponent("index.dkml"), atomically: true, encoding: .utf8)
        try source.dkssText.write(to: outputDirectory.appendingPathComponent("index.dkss"), atomically: true, encoding: .utf8)
        try source.jsText.write(to: outputDirectory.appendingPathComponent("index.js"), atomically: true, encoding: .utf8)
        try source.configJSONText.write(to: outputDirectory.appendingPathComponent("index.json"), atomically: true, encoding: .utf8)
    }

    private static func source(in pageDirectory: URL) throws -> DKPageSource {
        try DKPageSource(
            dkmlText: String(contentsOf: pageDirectory.appendingPathComponent("index.dkml"), encoding: .utf8),
            dkssText: String(contentsOf: pageDirectory.appendingPathComponent("index.dkss"), encoding: .utf8),
            jsText: String(contentsOf: pageDirectory.appendingPathComponent("index.js"), encoding: .utf8),
            configJSONText: String(contentsOf: pageDirectory.appendingPathComponent("index.json"), encoding: .utf8)
        )
    }

    private static func pageDirectories(in root: URL) throws -> [URL] {
        var directories: [URL] = []
        if FileManager.default.fileExists(atPath: root.appendingPathComponent("index.dkml").path) {
            directories.append(root)
        }
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return directories
        }
        for item in enumerator {
            guard let url = item as? URL else { continue }
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("index.dkml").path), !directories.contains(url) {
                directories.append(url)
            }
        }
        return directories
    }

    private static func page(named target: String, in pages: [CompileProjectOutput.Page]) -> CompileProjectOutput.Page? {
        let normalizedTarget = normalize(target)
        return pages.first {
            normalize($0.name) == normalizedTarget || normalize($0.pageId ?? "") == normalizedTarget
        } ?? pages.first {
            normalize($0.name).contains(normalizedTarget) || normalizedTarget.contains(normalize($0.name))
        }
    }

    private static func format(kind: String, text: String) -> String {
        switch kind {
        case "dkml": return CodeFormatter.formatDKML(text)
        case "dkss": return CodeFormatter.formatDKSS(text)
        case "js": return CodeFormatter.formatJS(text)
        case "json":
            guard let data = text.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
                  let result = String(data: pretty, encoding: .utf8) else {
                return text
            }
            return result + "\n"
        default:
            return text
        }
    }

    private static func requiredValue(_ name: String, in args: [String]) throws -> String {
        guard let value = value(name, in: args) else {
            throw CLIError(message: "缺少参数 \(name)")
        }
        return value
    }

    private static func value(_ name: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: name), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "_", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
    }

    private static func printJSON<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        FileHandle.standardOutput.write(data)
        print()
    }
}

private enum CodeFormatter {
    static func formatDKML(_ text: String) -> String {
        let tokens = text
            .replacingOccurrences(of: "><", with: ">\n<")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var indent = 0
        var lines: [String] = []
        for token in tokens {
            if token.hasPrefix("</") { indent = max(0, indent - 1) }
            lines.append(String(repeating: "  ", count: indent) + token)
            if token.hasPrefix("<"), !token.hasPrefix("</"), !token.hasSuffix("/>"), !token.contains("</") {
                indent += 1
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func formatDKSS(_ text: String) -> String {
        let prepared = text
            .replacingOccurrences(of: "{", with: "{\n")
            .replacingOccurrences(of: "}", with: "\n}\n")
            .replacingOccurrences(of: ";", with: ";\n")
        var indent = 0
        var lines: [String] = []
        for rawLine in prepared.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if line == "}" {
                indent = max(0, indent - 1)
                lines.append(line)
                lines.append("")
                continue
            }
            lines.append(String(repeating: "  ", count: indent) + line)
            if line.hasSuffix("{") { indent += 1 }
        }
        while lines.last == "" { lines.removeLast() }
        return lines.joined(separator: "\n") + "\n"
    }

    static func formatJS(_ text: String) -> String {
        var lines: [String] = []
        var current = ""
        var indent = 0
        var quote: Character?
        var isEscaping = false
        func flush() {
            let line = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.isEmpty { lines.append(String(repeating: "  ", count: max(0, indent)) + line) }
            current = ""
        }
        for character in text {
            if let activeQuote = quote {
                current.append(character)
                if isEscaping { isEscaping = false }
                else if character == "\\" { isEscaping = true }
                else if character == activeQuote { quote = nil }
                continue
            }
            switch character {
            case "\"", "'":
                quote = character
                current.append(character)
            case "{":
                current.append(character)
                flush()
                indent += 1
            case "}":
                flush()
                indent = max(0, indent - 1)
                current.append(character)
            case ",", "\n":
                if character == "," { current.append(character) }
                flush()
            default:
                current.append(character)
            }
        }
        flush()
        return lines.joined(separator: "\n") + "\n"
    }
}

do {
    try CLI.run()
} catch {
    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    let data = (try? JSONSerialization.data(withJSONObject: ["success": false, "diagnostics": [message]], options: [.prettyPrinted])) ?? Data(message.utf8)
    FileHandle.standardError.write(data)
    FileHandle.standardError.write(Data("\n".utf8))
    exit(1)
}
