import UIKit

@MainActor
final class DynamicPageRenderer {
    private let page: DynamicPage
    private let components: [DynamicComponent]
    private let stackView: UIStackView
    private let dataStore: DynamicDataStore
    private let actionHandler: DynamicActionHandler
    private let styleParser = DynamicStyleParser()
    private let factory = DynamicComponentFactory()
    private var imageTasks: [Task<Void, Never>] = []

    init(
        page: DynamicPage,
        components: [DynamicComponent]? = nil,
        stackView: UIStackView,
        dataStore: DynamicDataStore,
        actionHandler: DynamicActionHandler
    ) {
        self.page = page
        self.components = components ?? page.components
        self.stackView = stackView
        self.dataStore = dataStore
        self.actionHandler = actionHandler
    }

    func render() {
        cleanup()
        renderComponents(components, into: stackView, depth: 1)
        DynamicPageLogger.debug("page loaded")
    }

    func cleanup() {
        imageTasks.forEach { $0.cancel() }
        imageTasks.removeAll()
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    private func renderComponents(_ components: [DynamicComponent], into stackView: UIStackView, depth: Int) {
        guard depth <= DynamicPageLimits.maxRecursionDepth else {
            DynamicPageLogger.debug("recursion too deep")
            return
        }

        let resolver = DynamicTemplateResolver(dataStore: dataStore)
        let context = DynamicRenderContext(
            dataStore: dataStore,
            templateResolver: resolver,
            styleParser: styleParser,
            actionHandler: actionHandler,
            renderChildren: { [weak self] children, childStackView, childDepth in
                self?.renderComponents(children, into: childStackView, depth: childDepth)
            },
            registerImageTask: { [weak self] task in
                self?.imageTasks.append(task)
            }
        )

        for component in components {
            DynamicPageLogger.debug("render component: \(component.type)")
            if let view = factory.makeView(from: component, context: context, depth: depth) {
                stackView.addArrangedSubview(view)
            }
        }
    }
}
