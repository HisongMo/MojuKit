import Foundation

enum DynamicPageValidationSamples {
    @MainActor
    static func run() {
        validateDynamicValue()
        validateTemplateAndKeyPath()
        validateSchemaLimits()
        validateAPIRegistry()
    }

    private static func validateDynamicValue() {
        let json = """
        {
          "string": "value",
          "int": 1,
          "double": 1.5,
          "bool": true,
          "object": { "name": "demo" },
          "array": [1, "two"]
        }
        """.data(using: .utf8)!

        _ = try? JSONDecoder().decode([String: DynamicValue].self, from: json)
    }

    @MainActor
    private static func validateTemplateAndKeyPath() {
        let store = DynamicDataStore(pageParams: ["source": .string("home")])
        store.set(["name": "黄金会员", "nested": ["id": "vip_10001"]], forKey: "vipData")
        let resolver = DynamicTemplateResolver(dataStore: store)
        assert(resolver.resolveString("欢迎 {{vipData.name}}") == "欢迎 黄金会员")
        assert(store.value(forKeyPath: "vipData.nested.id") as? String == "vip_10001")
        assert(resolver.resolveString("{{missing.key}}").isEmpty)
    }

    private static func validateSchemaLimits() {
        let page = DynamicPage(
            schemaVersion: "1.0",
            pageId: "sample",
            pageTitle: nil,
            backgroundColor: nil,
            pageParams: nil,
            onLoad: nil,
            components: [
                DynamicComponent(
                    id: nil,
                    type: "unknown",
                    text: nil,
                    defaultText: nil,
                    imageUrl: nil,
                    placeholderImage: nil,
                    iconName: nil,
                    style: nil,
                    selectedStyle: nil,
                    action: nil,
                    children: nil,
                    visible: nil,
                    stateKey: nil,
                    value: nil
                )
            ],
            fixedBottomComponents: nil
        )
        try? DynamicSchemaValidator.validate(page)
    }

    private static func validateAPIRegistry() {
        assert(DynamicAPIRegistry.endpoint(for: "vipInfo") != nil)
        assert(DynamicAPIRegistry.endpoint(for: "unknown") == nil)
    }
}
