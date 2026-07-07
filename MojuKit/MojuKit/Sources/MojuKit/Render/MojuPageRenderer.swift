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
        renderComponents(components, into: stackView, depth: 1, resolver: nil)
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

    private func renderComponents(
        _ components: [MojuComponent],
        into stackView: UIStackView,
        depth: Int,
        resolver inheritedResolver: MojuTemplateResolver?
    ) {
        guard depth <= MojuPageLimits.maxRecursionDepth else {
            MojuPageLogger.debug("recursion too deep")
            return
        }

        let resolver = inheritedResolver ?? MojuTemplateResolver(dataStore: dataStore)

        for component in components {
            MojuPageLogger.debug("render component: \(component.type)")
            if shouldExpandLoop(for: component) {
                renderLoopedComponent(component, into: stackView, depth: depth, resolver: resolver)
            } else {
                renderSingleComponent(component, into: stackView, depth: depth, resolver: resolver)
            }
        }
    }

    private func renderSingleComponent(
        _ component: MojuComponent,
        into stackView: UIStackView,
        depth: Int,
        resolver: MojuTemplateResolver
    ) {
        let context = makeContext(resolver: resolver)
        if let view = factory.makeView(from: component, context: context, depth: depth) {
            stackView.addArrangedSubview(view)
        }
    }

    private func renderLoopedComponent(
        _ component: MojuComponent,
        into stackView: UIStackView,
        depth: Int,
        resolver: MojuTemplateResolver
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

    private func makeContext(resolver: MojuTemplateResolver) -> MojuRenderContext {
        MojuRenderContext(
            dataStore: dataStore,
            templateResolver: resolver,
            styleParser: styleParser,
            actionHandler: actionHandler,
            imageProvider: imageProvider,
            renderChildren: { [weak self] children, childStackView, childDepth, childResolver in
                self?.renderComponents(children, into: childStackView, depth: childDepth, resolver: childResolver ?? resolver)
            },
            registerImageTask: { [weak self] task in
                self?.imageTasks.append(task)
            }
        )
    }

    private func shouldExpandLoop(for component: MojuComponent) -> Bool {
        guard component.forEach?.isEmpty == false else { return false }
        return MojuComponentType(rawValue: component.type) != .tableView &&
            MojuComponentType(rawValue: component.type) != .collectionView
    }
}

private extension MojuComponent {
    func withoutLoop() -> MojuComponent {
        MojuComponent(
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
