import DynamicPageKitCore
import Foundation

struct DynamicPageDocument: Identifiable, Equatable {
    enum DirtyState: String {
        case clean = "已保存"
        case dirty = "未保存"
    }

    let id: UUID
    var pageDirectoryURL: URL
    var dkmlURL: URL
    var dkssURL: URL
    var jsURL: URL
    var configJSONURL: URL
    var dynamicJSONURL: URL
    var displayName: String
    var dkmlText: String
    var dkssText: String
    var jsText: String
    var configJSONText: String
    var compiledJSONText: String
    var compiledPage: DynamicPage?
    var diagnostics: [String]
    var dirtyState: DirtyState
    var lastKnownDKMLDate: Date?
    var lastKnownDKSSDate: Date?
    var lastKnownJSDate: Date?
    var lastKnownConfigDate: Date?

    init(
        id: UUID = UUID(),
        pageDirectoryURL: URL,
        dkmlURL: URL,
        dkssURL: URL,
        jsURL: URL,
        configJSONURL: URL,
        dynamicJSONURL: URL,
        displayName: String,
        dkmlText: String,
        dkssText: String,
        jsText: String,
        configJSONText: String,
        compiledJSONText: String = "",
        compiledPage: DynamicPage? = nil,
        diagnostics: [String] = [],
        dirtyState: DirtyState = .clean,
        lastKnownDKMLDate: Date? = nil,
        lastKnownDKSSDate: Date? = nil,
        lastKnownJSDate: Date? = nil,
        lastKnownConfigDate: Date? = nil
    ) {
        self.id = id
        self.pageDirectoryURL = pageDirectoryURL
        self.dkmlURL = dkmlURL
        self.dkssURL = dkssURL
        self.jsURL = jsURL
        self.configJSONURL = configJSONURL
        self.dynamicJSONURL = dynamicJSONURL
        self.displayName = displayName
        self.dkmlText = dkmlText
        self.dkssText = dkssText
        self.jsText = jsText
        self.configJSONText = configJSONText
        self.compiledJSONText = compiledJSONText
        self.compiledPage = compiledPage
        self.diagnostics = diagnostics
        self.dirtyState = dirtyState
        self.lastKnownDKMLDate = lastKnownDKMLDate
        self.lastKnownDKSSDate = lastKnownDKSSDate
        self.lastKnownJSDate = lastKnownJSDate
        self.lastKnownConfigDate = lastKnownConfigDate
    }

    var source: DKPageSource {
        DKPageSource(
            dkmlText: dkmlText,
            dkssText: dkssText,
            jsText: jsText,
            configJSONText: configJSONText
        )
    }
}
