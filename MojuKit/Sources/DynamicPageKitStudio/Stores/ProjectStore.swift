import AppKit
import DynamicPageKitCore
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ProjectStore: ObservableObject {
    @Published var projectURL: URL?
    @Published var documents: [DynamicPageDocument] = []
    @Published var selectedDocumentID: DynamicPageDocument.ID?
    @Published var selectedPreviewComponentIndex: Int?
    @Published var previewNavigationStack: [DynamicPageDocument.ID] = []
    @Published var statusText = "打开一个包含 pages 的项目文件夹开始编辑"
    @Published var externalChangeMessage: String?
    @Published var editorMode: EditorMode = .dkml
    @Published var projectPathText = "/Users/wangleihaoshuaio/Developer/Demo/MojuKit"

    let previewServer = PreviewServer()
    let simulatorPreview = SimulatorPreviewController()
    private var compileTask: Task<Void, Never>?
    private let lastProjectPathKey = "DynamicPageKitStudio.lastProjectPath"

    init() {
        if let lastProjectPath = UserDefaults.standard.string(forKey: lastProjectPathKey),
           !lastProjectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            projectPathText = lastProjectPath
        }
    }

    enum EditorMode: String, CaseIterable, Identifiable {
        case dkml = "DKML"
        case dkss = "DKSS"
        case js = "JS"
        case config = "JSON"
        case compiled = "Compiled"
        case diagnostics = "诊断"

        var id: String { rawValue }
    }

    var selectedDocument: DynamicPageDocument? {
        guard let selectedDocumentID else { return nil }
        return documents.first { $0.id == selectedDocumentID }
    }

    var selectedPage: DynamicPage? {
        activePreviewDocument?.compiledPage ?? selectedDocument?.compiledPage
    }

    var activePreviewDocument: DynamicPageDocument? {
        guard let id = previewNavigationStack.last else { return nil }
        return documents.first { $0.id == id }
    }

    var canPreviewGoBack: Bool {
        !previewNavigationStack.isEmpty
    }

    var selectedPreviewComponent: DynamicComponent? {
        guard
            let selectedPreviewComponentIndex,
            let page = selectedPage,
            page.components.indices.contains(selectedPreviewComponentIndex)
        else {
            return nil
        }
        return page.components[selectedPreviewComponentIndex]
    }

    func startPreviewServer() {
        previewServer.start()
    }

    func loadDefaultProjectIfNeeded() {
        guard projectURL == nil else { return }
        loadProjectPath(projectPathText)
        if projectURL == nil {
            loadDevelopmentProjectFromBundle()
        }
    }

    func startSimulatorPreview() {
        startPreviewServer()
        publishSelectedIfValid()
        simulatorPreview.start(projectURL: projectURL)
    }

    func relaunchSimulatorHost() {
        simulatorPreview.relaunchHost()
    }

    func refreshSimulatorPreview() {
        compileSelectedNow()
        statusText = "已刷新 Simulator 预览"
    }

    func openProjectFolder() {
        loadProjectPath(projectPathText)
    }

    func loadProjectPath(_ path: String) {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            statusText = "请输入项目文件夹路径"
            return
        }

        let expandedPath = (trimmedPath as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            statusText = "路径不是有效文件夹：\(expandedPath)"
            return
        }

        loadProject(at: URL(fileURLWithPath: expandedPath, isDirectory: true))
    }

    func loadDevelopmentProjectFromBundle() {
        let bundleURL = Bundle.main.bundleURL
        let buildURL = bundleURL.deletingLastPathComponent()
        let studioAppURL = buildURL.deletingLastPathComponent()
        let projectURL = studioAppURL.deletingLastPathComponent()

        if projectURL.lastPathComponent == "MojuKit" || FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("Package.swift").path) {
            loadProject(at: projectURL)
            return
        }

        let defaultURL = URL(fileURLWithPath: projectPathText, isDirectory: true)
        guard FileManager.default.fileExists(atPath: defaultURL.appendingPathComponent("Package.swift").path) else {
            statusText = "无法从 App 位置推断当前工程，请粘贴项目路径加载"
            return
        }

        loadProject(at: defaultURL)
    }

    func loadProject(at url: URL) {
        do {
            let pagesURL = url.appendingPathComponent("pages", isDirectory: true)
            let scanRoot = FileManager.default.fileExists(atPath: pagesURL.path) ? pagesURL : url
            let loadedDocuments = try scanDocuments(in: scanRoot)

            projectURL = url
            projectPathText = url.path(percentEncoded: false)
            UserDefaults.standard.set(projectPathText, forKey: lastProjectPathKey)
            documents = loadedDocuments
            selectedDocumentID = loadedDocuments.first?.id
            selectedPreviewComponentIndex = nil
            previewNavigationStack = []
            statusText = loadedDocuments.isEmpty
                ? "没有找到页面文件：请选择包含 pages/、index.dkml 的文件夹，或导入旧版 JSON"
                : "已加载 \(loadedDocuments.count) 个页面"
            publishSelectedIfValid()
        } catch {
            statusText = "项目加载失败：\(error.localizedDescription)"
        }
    }

    func importJSON() {
        statusText = "请在“新建页面”中选择“从 JSON 导入”，或拖入 JSON 路径"
    }

    func importJSONPath(_ path: String) {
        guard let projectURL else {
            statusText = "请先打开项目文件夹，再导入 JSON"
            return
        }

        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            statusText = "请输入 JSON 文件路径"
            return
        }

        let expandedPath = (trimmedPath as NSString).expandingTildeInPath
        let sourceURL = URL(fileURLWithPath: expandedPath)
        guard FileManager.default.fileExists(atPath: sourceURL.path), sourceURL.pathExtension.lowercased() == "json" else {
            statusText = "路径不是有效 JSON 文件：\(expandedPath)"
            return
        }

        do {
            let jsonText = try String(contentsOf: sourceURL, encoding: .utf8)
            let page = try DynamicPageCodec.page(from: jsonText)
            let pagesURL = projectURL.appendingPathComponent("pages", isDirectory: true)
            try FileManager.default.createDirectory(at: pagesURL, withIntermediateDirectories: true)
            let directory = uniquePageDirectory(in: pagesURL, preferredName: sourceURL.deletingPathExtension().lastPathComponent)
            let source = DKPageCompiler.decompile(page: page)
            let document = try makeDocument(pageDirectoryURL: directory, displayName: directory.lastPathComponent, source: source, writeIfNeeded: true)
            documents.append(document)
            selectedDocumentID = document.id
            selectedPreviewComponentIndex = nil
            previewNavigationStack = []
            statusText = "已导入并转换为四文件结构：\(document.displayName)"
            publishSelectedIfValid()
        } catch {
            statusText = "导入失败：\(error.localizedDescription)"
        }
    }

    func createPage() {
        createPage(named: "NewPage")
    }

    func createPage(named preferredName: String) {
        guard let projectURL else {
            statusText = "请先打开项目文件夹，再新建页面"
            return
        }

        do {
            let pagesURL = projectURL.appendingPathComponent("pages", isDirectory: true)
            try FileManager.default.createDirectory(at: pagesURL, withIntermediateDirectories: true)
            let sanitizedName = sanitizedPageDirectoryName(preferredName)
            let directory = uniquePageDirectory(in: pagesURL, preferredName: sanitizedName)
            let source = DKPageCompiler.defaultSource(pageId: directory.lastPathComponent)
            let document = try makeDocument(pageDirectoryURL: directory, displayName: directory.lastPathComponent, source: source, writeIfNeeded: true)
            documents.append(document)
            selectedDocumentID = document.id
            selectedPreviewComponentIndex = nil
            previewNavigationStack = []
            statusText = "已创建 \(document.displayName)"
            publishSelectedIfValid()
        } catch {
            statusText = "新建失败：\(error.localizedDescription)"
        }
    }

    func select(_ id: DynamicPageDocument.ID?) {
        selectedDocumentID = id
        selectedPreviewComponentIndex = nil
        previewNavigationStack = []
        compileSelectedNow()
        publishSelectedIfValid()
    }

    func selectPreviewComponent(at index: Int?) {
        selectedPreviewComponentIndex = index
    }

    func previewGoBack() {
        guard !previewNavigationStack.isEmpty else { return }
        previewNavigationStack.removeLast()
        selectedPreviewComponentIndex = nil
        publishPreviewDocumentIfValid()
    }

    func handlePreviewAction(_ action: DynamicAction?) {
        guard let action else { return }

        switch action.type {
        case "navigate":
            guard let target = action.target else { return }
            if target == "back" {
                previewGoBack()
                return
            }
            guard let document = document(matchingNavigationTarget: target) else {
                statusText = "没有找到预览跳转目标：\(target)"
                return
            }
            previewNavigationStack.append(document.id)
            selectedPreviewComponentIndex = nil
            statusText = "预览跳转到 \(document.displayName)"
            publishPreviewDocumentIfValid()
        default:
            statusText = "预览暂不执行 action：\(action.type)"
        }
    }

    func updateSelectedDKML(_ text: String) {
        updateSelected { $0.dkmlText = text }
    }

    func updateSelectedDKSS(_ text: String) {
        updateSelected { $0.dkssText = text }
    }

    func updateSelectedJS(_ text: String) {
        updateSelected { $0.jsText = text }
    }

    func updateSelectedConfigJSON(_ text: String) {
        updateSelected { $0.configJSONText = text }
    }

    func saveSelected() {
        guard let index = selectedIndex else { return }

        do {
            formatDocumentSources(at: index)
            try writeDocument(documents[index])
            documents[index].dirtyState = .clean
            documents[index].lastKnownDKMLDate = modificationDate(for: documents[index].dkmlURL)
            documents[index].lastKnownDKSSDate = modificationDate(for: documents[index].dkssURL)
            documents[index].lastKnownJSDate = modificationDate(for: documents[index].jsURL)
            documents[index].lastKnownConfigDate = modificationDate(for: documents[index].configJSONURL)
            statusText = "已保存 \(documents[index].displayName)"
        } catch {
            statusText = "保存失败：\(error.localizedDescription)"
        }
    }

    func formatSelectedCode() {
        guard let index = selectedIndex else { return }

        switch editorMode {
        case .dkml:
            documents[index].dkmlText = CodeFormatter.formatDKML(documents[index].dkmlText)
            markFormattedDocument(at: index, label: "DKML")
        case .dkss:
            documents[index].dkssText = CodeFormatter.formatDKSS(documents[index].dkssText)
            markFormattedDocument(at: index, label: "DKSS")
        case .js:
            documents[index].jsText = CodeFormatter.formatJS(documents[index].jsText)
            markFormattedDocument(at: index, label: "JS")
        case .config:
            do {
                let config = try JSONDecoder().decode(DKPageConfig.self, from: Data(documents[index].configJSONText.utf8))
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                let data = try encoder.encode(config)
                documents[index].configJSONText = String(data: data, encoding: .utf8) ?? documents[index].configJSONText
                markFormattedDocument(at: index, label: "JSON")
            } catch {
                documents[index].diagnostics = ["JSON 格式化失败：\(error.localizedDescription)"]
            }
        case .compiled, .diagnostics:
            statusText = "当前视图不支持格式化"
        }
    }

    func formatSelectedJSON() {
        formatSelectedCode()
    }

    func completionWordsForCurrentEditor() -> [String] {
        switch editorMode {
        case .dkml:
            return [
                "page", "view", "text", "image", "input", "textarea", "button", "card", "row", "column", "icon", "space", "selectable-card", "tableview", "collectionview",
                "class", "bindtap", "dk:if", "dk:for", "dk:item", "dk:index", "dk:key", "columns", "slot", "src", "placeholder", "name", "state-key", "value", "default", "default-text", "keyboard-type", "max-length", "data-id"
            ]
        case .dkss:
            return [
                "background-color", "text-color", "font-size", "font-weight", "corner-radius", "border-width", "border-color",
                "width", "height", "margin", "padding", "alignment", "text-align", "stack-alignment", "distribution", "spacing",
                "content-mode", "number-of-lines", "hidden"
            ]
        case .js:
            return [
                "Page", "data", "methods", "event", "dataset", "dk.setState", "dk.navigate", "dk.navigateNative", "dk.back", "dk.toast",
                "dk.track", "dk.request", "dk.delay", "params", "responseKey", "success", "fail", "failure", "showLoading", "loadingText",
                "selectedCardId", "pageParams"
            ]
        case .config:
            return [
                "schemaVersion", "pageId", "pageTitle", "backgroundColor", "pageParams", "onLoad", "apiKey",
                "params", "responseKey", "showLoading", "loadingText"
            ]
        case .compiled, .diagnostics:
            return []
        }
    }

    func validateSelected() {
        compileSelectedNow()
    }

    private func markFormattedDocument(at index: Int, label: String) {
        documents[index].dirtyState = .dirty
        compileDocument(at: index)
        publishSelectedIfValid()
        statusText = "\(label) 已格式化"
    }

    private func formatDocumentSources(at index: Int) {
        documents[index].dkmlText = CodeFormatter.formatDKML(documents[index].dkmlText)
        documents[index].dkssText = CodeFormatter.formatDKSS(documents[index].dkssText)
        documents[index].jsText = CodeFormatter.formatJS(documents[index].jsText)

        if let config = try? JSONDecoder().decode(DKPageConfig.self, from: Data(documents[index].configJSONText.utf8)) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            if let data = try? encoder.encode(config),
               let text = String(data: data, encoding: .utf8) {
                documents[index].configJSONText = text
            }
        }

        compileDocument(at: index)
    }

    func checkExternalChanges() {
        guard let index = selectedIndex else { return }
        let document = documents[index]
        if document.lastKnownDKMLDate != nil, modificationDate(for: document.dkmlURL) != document.lastKnownDKMLDate {
            externalChangeMessage = "\(document.displayName) 的 DKML 已在外部修改"
        } else if document.lastKnownDKSSDate != nil, modificationDate(for: document.dkssURL) != document.lastKnownDKSSDate {
            externalChangeMessage = "\(document.displayName) 的 DKSS 已在外部修改"
        } else if document.lastKnownJSDate != nil, modificationDate(for: document.jsURL) != document.lastKnownJSDate {
            externalChangeMessage = "\(document.displayName) 的 JS 已在外部修改"
        } else if document.lastKnownConfigDate != nil, modificationDate(for: document.configJSONURL) != document.lastKnownConfigDate {
            externalChangeMessage = "\(document.displayName) 的 JSON 配置已在外部修改"
        } else {
            externalChangeMessage = nil
        }
    }

    func reloadSelectedFromDisk() {
        guard let index = selectedIndex else { return }

        do {
            documents[index] = try makeDocument(pageDirectoryURL: documents[index].pageDirectoryURL, id: documents[index].id)
            externalChangeMessage = nil
            selectedPreviewComponentIndex = nil
            statusText = "已从磁盘刷新 \(documents[index].displayName)"
            publishSelectedIfValid()
        } catch {
            statusText = "刷新失败：\(error.localizedDescription)"
        }
    }

    func updateSelectedPageTitle(_ title: String) {
        guard let index = activePreviewOrSelectedIndex else { return }
        var configText = documents[index].configJSONText
        do {
            var config = try JSONDecoder().decode(DKPageConfig.self, from: Data(configText.utf8))
            config.pageTitle = title
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            configText = String(data: try encoder.encode(config), encoding: .utf8) ?? configText
            documents[index].configJSONText = configText
            documents[index].dirtyState = .dirty
            compileDocument(at: index)
        } catch {
            documents[index].diagnostics = ["页面标题更新失败：\(error.localizedDescription)"]
        }
    }

    func updateSelectedComponentPrimaryValue(_ value: String) {
        guard let index = activePreviewOrSelectedIndex else { return }
        // 第一版直接编辑 DKML 中第 N 个简单组件文本，失败则只提示，不覆盖源码。
        guard let componentIndex = selectedPreviewComponentIndex else { return }
        var replacementsRemaining = componentIndex
        let updated = replaceFirstSimpleNodeText(in: documents[index].dkmlText, newValue: value, replacementsRemaining: &replacementsRemaining)
        if updated != documents[index].dkmlText {
            documents[index].dkmlText = updated
            documents[index].dirtyState = .dirty
            compileDocument(at: index)
        } else {
            documents[index].diagnostics = ["暂无法从画布反写该组件，请在 DKML 中编辑"]
        }
    }

    private func updateSelected(_ mutate: (inout DynamicPageDocument) -> Void) {
        guard let index = selectedIndex else { return }
        mutate(&documents[index])
        documents[index].dirtyState = .dirty
        scheduleCompile()
    }

    private var selectedIndex: Int? {
        guard let selectedDocumentID else { return nil }
        return documents.firstIndex { $0.id == selectedDocumentID }
    }

    private var activePreviewOrSelectedIndex: Int? {
        if let id = previewNavigationStack.last,
           let index = documents.firstIndex(where: { $0.id == id }) {
            return index
        }
        return selectedIndex
    }

    private func scheduleCompile() {
        compileTask?.cancel()
        compileTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.compileSelectedNow()
            }
        }
    }

    private func compileSelectedNow() {
        guard let index = selectedIndex else { return }
        compileDocument(at: index)
        publishSelectedIfValid()
    }

    private func compileDocument(at index: Int) {
        let result = DKPageCompiler.compile(documents[index].source)
        documents[index].compiledPage = result.page
        documents[index].diagnostics = result.diagnostics
        if let page = result.page {
            documents[index].compiledJSONText = (try? DynamicPageCodec.prettyJSON(from: page)) ?? ""
            statusText = "\(documents[index].displayName) 编译通过"
        } else {
            statusText = "\(documents[index].displayName) 编译失败"
        }
    }

    private func publishSelectedIfValid() {
        compileAllDocumentsIfNeeded()
        guard let document = selectedDocument, let activePage = publishedPage(for: document) else { return }
        previewServer.publish(activePage: activePage, pages: publishedPages())
    }

    private func publishPreviewDocumentIfValid() {
        compileAllDocumentsIfNeeded()
        guard let document = activePreviewDocument ?? selectedDocument, let activePage = publishedPage(for: document) else { return }
        previewServer.publish(activePage: activePage, pages: publishedPages())
    }

    private func compileAllDocumentsIfNeeded() {
        for index in documents.indices where documents[index].compiledPage == nil {
            compileDocument(at: index)
        }
    }

    private func publishedPages() -> [PreviewPublishedPage] {
        documents.compactMap { publishedPage(for: $0) }
    }

    private func publishedPage(for document: DynamicPageDocument) -> PreviewPublishedPage? {
        guard let page = document.compiledPage else { return nil }
        let json = document.compiledJSONText.isEmpty
            ? (try? DynamicPageCodec.prettyJSON(from: page))
            : document.compiledJSONText
        guard let json else { return nil }
        return PreviewPublishedPage(
            displayName: document.displayName,
            pageId: page.pageId,
            jsonText: json
        )
    }

    private func document(matchingNavigationTarget target: String) -> DynamicPageDocument? {
        let normalizedTarget = normalize(target)
        return documents.first { document in
            if normalize(document.displayName) == normalizedTarget {
                return true
            }
            if let page = document.compiledPage, normalize(page.pageId ?? "") == normalizedTarget {
                return true
            }
            return false
        } ?? documents.first { document in
            normalize(document.displayName).contains(normalizedTarget) ||
                normalizedTarget.contains(normalize(document.displayName))
        }
    }

    private func scanDocuments(in root: URL) throws -> [DynamicPageDocument] {
        let directories = try pageDirectories(in: root)
        var loaded: [DynamicPageDocument] = []
        for directory in directories {
            loaded.append(try makeDocument(pageDirectoryURL: directory))
        }

        let legacyJSONFiles = try scanLegacyJSONFiles(in: root)
        for url in legacyJSONFiles {
            guard !loaded.contains(where: { $0.displayName == url.deletingPathExtension().lastPathComponent }) else { continue }
            let jsonText = try String(contentsOf: url, encoding: .utf8)
            guard let page = try? DynamicPageCodec.page(from: jsonText) else { continue }
            let source = DKPageCompiler.decompile(page: page)
            let pagesRoot = root.lastPathComponent == "pages" ? root : root.appendingPathComponent("pages", isDirectory: true)
            let virtualDirectory = pagesRoot.appendingPathComponent(url.deletingPathExtension().lastPathComponent, isDirectory: true)
            loaded.append(try makeDocument(pageDirectoryURL: virtualDirectory, displayName: url.deletingPathExtension().lastPathComponent, source: source, writeIfNeeded: false))
        }

        return loaded.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private func pageDirectories(in root: URL) throws -> [URL] {
        var directories: [URL] = []
        if FileManager.default.fileExists(atPath: root.appendingPathComponent("index.dkml").path) {
            directories.append(root)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return directories
        }

        for item in enumerator {
            guard let url = item as? URL else { continue }
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            let dkml = url.appendingPathComponent("index.dkml")
            guard FileManager.default.fileExists(atPath: dkml.path), !directories.contains(url) else { continue }
            directories.append(url)
        }

        return directories
    }

    private func scanLegacyJSONFiles(in root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension.lowercased() == "json" else { return nil }
            guard url.lastPathComponent != "index.json", url.lastPathComponent != "index.dynamic.json" else { return nil }
            let path = url.path
            guard !path.contains("/.build/"), !path.contains("/DerivedData/") else { return nil }
            return url
        }
    }

    private func makeDocument(pageDirectoryURL: URL, id: UUID = UUID()) throws -> DynamicPageDocument {
        let source = DKPageSource(
            dkmlText: try String(contentsOf: pageDirectoryURL.appendingPathComponent("index.dkml"), encoding: .utf8),
            dkssText: try String(contentsOf: pageDirectoryURL.appendingPathComponent("index.dkss"), encoding: .utf8),
            jsText: try String(contentsOf: pageDirectoryURL.appendingPathComponent("index.js"), encoding: .utf8),
            configJSONText: try String(contentsOf: pageDirectoryURL.appendingPathComponent("index.json"), encoding: .utf8)
        )
        return try makeDocument(pageDirectoryURL: pageDirectoryURL, id: id, displayName: pageDirectoryURL.lastPathComponent, source: source, writeIfNeeded: false)
    }

    private func makeDocument(
        pageDirectoryURL: URL,
        id: UUID = UUID(),
        displayName: String,
        source: DKPageSource,
        writeIfNeeded: Bool
    ) throws -> DynamicPageDocument {
        if writeIfNeeded {
            try FileManager.default.createDirectory(at: pageDirectoryURL, withIntermediateDirectories: true)
            try source.dkmlText.write(to: pageDirectoryURL.appendingPathComponent("index.dkml"), atomically: true, encoding: .utf8)
            try source.dkssText.write(to: pageDirectoryURL.appendingPathComponent("index.dkss"), atomically: true, encoding: .utf8)
            try source.jsText.write(to: pageDirectoryURL.appendingPathComponent("index.js"), atomically: true, encoding: .utf8)
            try source.configJSONText.write(to: pageDirectoryURL.appendingPathComponent("index.json"), atomically: true, encoding: .utf8)
        }

        let result = DKPageCompiler.compile(source)
        let compiledJSON = result.page.flatMap { try? DynamicPageCodec.prettyJSON(from: $0) } ?? ""
        return DynamicPageDocument(
            id: id,
            pageDirectoryURL: pageDirectoryURL,
            dkmlURL: pageDirectoryURL.appendingPathComponent("index.dkml"),
            dkssURL: pageDirectoryURL.appendingPathComponent("index.dkss"),
            jsURL: pageDirectoryURL.appendingPathComponent("index.js"),
            configJSONURL: pageDirectoryURL.appendingPathComponent("index.json"),
            dynamicJSONURL: pageDirectoryURL.appendingPathComponent("index.dynamic.json"),
            displayName: displayName,
            dkmlText: source.dkmlText,
            dkssText: source.dkssText,
            jsText: source.jsText,
            configJSONText: source.configJSONText,
            compiledJSONText: compiledJSON,
            compiledPage: result.page,
            diagnostics: result.diagnostics,
            lastKnownDKMLDate: modificationDate(for: pageDirectoryURL.appendingPathComponent("index.dkml")),
            lastKnownDKSSDate: modificationDate(for: pageDirectoryURL.appendingPathComponent("index.dkss")),
            lastKnownJSDate: modificationDate(for: pageDirectoryURL.appendingPathComponent("index.js")),
            lastKnownConfigDate: modificationDate(for: pageDirectoryURL.appendingPathComponent("index.json"))
        )
    }

    private func writeDocument(_ document: DynamicPageDocument) throws {
        try FileManager.default.createDirectory(at: document.pageDirectoryURL, withIntermediateDirectories: true)
        try document.dkmlText.write(to: document.dkmlURL, atomically: true, encoding: .utf8)
        try document.dkssText.write(to: document.dkssURL, atomically: true, encoding: .utf8)
        try document.jsText.write(to: document.jsURL, atomically: true, encoding: .utf8)
        try document.configJSONText.write(to: document.configJSONURL, atomically: true, encoding: .utf8)
        try document.compiledJSONText.write(to: document.dynamicJSONURL, atomically: true, encoding: .utf8)
    }

    private func uniquePageDirectory(in pagesURL: URL, preferredName: String) -> URL {
        var index = 0
        while true {
            let suffix = index == 0 ? "" : "\(index + 1)"
            let url = pagesURL.appendingPathComponent("\(preferredName)\(suffix)", isDirectory: true)
            if !FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            index += 1
        }
    }

    private func sanitizedPageDirectoryName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let name = trimmed.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "_"
        }
            .joined()
            .split(separator: "_")
            .joined(separator: "_")
        return name.isEmpty ? "NewPage" : name
    }

    private func replaceFirstSimpleNodeText(in text: String, newValue: String, replacementsRemaining: inout Int) -> String {
        let pattern = #"<(text|button)([^>]*)>(.*?)</\1>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return text }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: nsRange)
        guard matches.indices.contains(replacementsRemaining),
              let range = Range(matches[replacementsRemaining].range(at: 3), in: text) else {
            return text
        }
        return text.replacingCharacters(in: range, with: escapeXML(newValue))
    }

    private func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private func modificationDate(for url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
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
            if token.hasPrefix("</") {
                indent = max(0, indent - 1)
            }
            lines.append(String(repeating: "  ", count: indent) + token)
            if token.hasPrefix("<"),
               !token.hasPrefix("</"),
               !token.hasSuffix("/>"),
               !token.contains("</") {
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
            if line.hasSuffix("{") {
                indent += 1
            }
        }
        return trimTrailingBlankLines(lines).joined(separator: "\n") + "\n"
    }

    static func formatJS(_ text: String) -> String {
        var lines: [String] = []
        var current = ""
        var indent = 0
        var quote: Character?
        var isEscaping = false

        func flush() {
            let line = current.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                current = ""
                return
            }
            lines.append(String(repeating: "  ", count: max(0, indent)) + line)
            current = ""
        }

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
            case ",":
                current.append(character)
                flush()
            case "\n":
                flush()
            default:
                current.append(character)
            }
        }
        flush()
        return lines.joined(separator: "\n") + "\n"
    }

    private static func trimTrailingBlankLines(_ lines: [String]) -> [String] {
        var result = lines
        while result.last == "" {
            result.removeLast()
        }
        return result
    }
}
