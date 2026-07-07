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
        renderComponents(components, into: stackView, depth: 1, resolver: nil)
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

    private func renderComponents(
        _ components: [DynamicComponent],
        into stackView: UIStackView,
        depth: Int,
        resolver inheritedResolver: DynamicTemplateResolver?
    ) {
        guard depth <= DynamicPageLimits.maxRecursionDepth else {
            DynamicPageLogger.debug("recursion too deep")
            return
        }

        let resolver = inheritedResolver ?? DynamicTemplateResolver(dataStore: dataStore)

        for component in components {
            DynamicPageLogger.debug("render component: \(component.type)")
            if shouldExpandLoop(for: component) {
                renderLoopedComponent(component, into: stackView, depth: depth, resolver: resolver)
            } else {
                renderSingleComponent(component, into: stackView, depth: depth, resolver: resolver)
            }
        }
    }

    private func renderSingleComponent(
        _ component: DynamicComponent,
        into stackView: UIStackView,
        depth: Int,
        resolver: DynamicTemplateResolver
    ) {
        let context = makeContext(resolver: resolver)
        if let view = factory.makeView(from: component, context: context, depth: depth) {
            stackView.addArrangedSubview(view)
        }
    }

    private func renderLoopedComponent(
        _ component: DynamicComponent,
        into stackView: UIStackView,
        depth: Int,
        resolver: DynamicTemplateResolver
    ) {
        let items = resolver.resolveArray(component.forEach)
        guard !items.isEmpty else { return }
        let itemName = component.forItem?.isEmpty == false ? component.forItem! : "item"
        let indexName = component.forIndex?.isEmpty == false ? component.forIndex! : "index"
        let looplessComponent = component.withoutLoop()

        for (index, item) in items.enumerated() {
            let localResolver = resolver.withLocalValues([
                itemName: item,
                indexName: .int(index)
            ])
            renderSingleComponent(looplessComponent, into: stackView, depth: depth, resolver: localResolver)
        }
    }

    private func makeContext(resolver: DynamicTemplateResolver) -> DynamicRenderContext {
        DynamicRenderContext(
            dataStore: dataStore,
            templateResolver: resolver,
            styleParser: styleParser,
            actionHandler: actionHandler,
            renderChildren: { [weak self] children, childStackView, childDepth, childResolver in
                self?.renderComponents(children, into: childStackView, depth: childDepth, resolver: childResolver ?? resolver)
            },
            registerImageTask: { [weak self] task in
                self?.imageTasks.append(task)
            }
        )
    }

    private func shouldExpandLoop(for component: DynamicComponent) -> Bool {
        guard component.forEach?.isEmpty == false else { return false }
        return DynamicComponentType(rawValue: component.type) != .tableView &&
            DynamicComponentType(rawValue: component.type) != .collectionView
    }
}

private extension DynamicComponent {
    func withoutLoop() -> DynamicComponent {
        DynamicComponent(
            id: id,
            type: type,
            text: text,
            defaultText: defaultText,
            placeholder: placeholder,
            imageUrl: imageUrl,
            placeholderImage: placeholderImage,
            iconName: iconName,
            keyboardType: keyboardType,
            maxLength: maxLength,
            style: style,
            selectedStyle: selectedStyle,
            action: action,
            children: children,
            visible: visible,
            stateKey: stateKey,
            value: value,
            forEach: nil,
            forItem: nil,
            forIndex: nil,
            columns: columns
        )
    }
}
