import UIKit

@MainActor
final class MojuPageRenderer {
    private let page: MojuPage
    private let components: [MojuComponent]
    private let stackView: UIStackView
    private let dataStore: MojuDataStore
    private let actionHandler: MojuActionHandler
    private let imageProvider: MojuImageProviding
    private let styleParser = MojuStyleParser()
    private let factory = MojuComponentFactory()
    private var imageTasks: [Task<Void, Never>] = []

    init(
        page: MojuPage,
        components: [MojuComponent]? = nil,
        stackView: UIStackView,
        dataStore: MojuDataStore,
        actionHandler: MojuActionHandler,
        imageProvider: MojuImageProviding
    ) {
        self.page = page
        self.components = components ?? page.components
        self.stackView = stackView
        self.dataStore = dataStore
        self.actionHandler = actionHandler
        self.imageProvider = imageProvider
    }

    func render() {
        cleanup()
        renderComponents(components, into: stackView, depth: 1)
        MojuPageLogger.debug("page loaded")
    }

    func cleanup() {
        imageTasks.forEach { $0.cancel() }
        imageTasks.removeAll()
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    private func renderComponents(_ components: [MojuComponent], into stackView: UIStackView, depth: Int) {
        guard depth <= MojuPageLimits.maxRecursionDepth else {
            MojuPageLogger.debug("recursion too deep")
            return
        }

        let resolver = MojuTemplateResolver(dataStore: dataStore)
        let context = MojuRenderContext(
            dataStore: dataStore,
            templateResolver: resolver,
            styleParser: styleParser,
            actionHandler: actionHandler,
            imageProvider: imageProvider,
            renderChildren: { [weak self] children, childStackView, childDepth in
                self?.renderComponents(children, into: childStackView, depth: childDepth)
            },
            registerImageTask: { [weak self] task in
                self?.imageTasks.append(task)
            }
        )

        for component in components {
            MojuPageLogger.debug("render component: \(component.type)")
            if let view = factory.makeView(from: component, context: context, depth: depth) {
                stackView.addArrangedSubview(view)
            }
        }
    }
}
