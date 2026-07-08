import ObjectiveC
import UIKit

private final class MojuFitContentContainerView: UIView {
    weak var measuredContentView: UIView?
    var extraWidth: CGFloat = 0

    override var intrinsicContentSize: CGSize {
        guard let measuredContentView else {
            return super.intrinsicContentSize
        }
        let contentSize = measuredContentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return CGSize(width: contentSize.width + extraWidth, height: UIView.noIntrinsicMetric)
    }
}

@MainActor
final class MojuComponentFactory {
    private let placeholderColor = UIColor.systemGray5

    func makeView(from component: MojuComponent, context: MojuRenderContext, depth: Int) -> UIView? {
        guard isVisible(component, context: context) else { return nil }

        let contentView: UIView?
        let effectiveStyle = effectiveStyle(for: component, context: context)
        switch MojuComponentType(rawValue: component.type) {
        case .text:
            contentView = makeText(component, context: context)
        case .image:
            contentView = makeImage(component, context: context)
        case .input:
            contentView = makeInput(component, context: context)
        case .textarea:
            contentView = makeTextArea(component, context: context)
        case .button:
            contentView = makeButton(component, context: context)
        case .space:
            contentView = UIView()
        case .card:
            contentView = makeCard(component, context: context, depth: depth)
        case .row:
            contentView = makeRow(component, context: context, depth: depth)
        case .icon:
            contentView = makeIcon(component, context: context)
        case .selectableCard:
            contentView = makeSelectableCard(component, context: context, depth: depth)
        case .tableView:
            contentView = makeTableView(component, context: context, depth: depth)
        case .collectionView:
            contentView = makeCollectionView(component, context: context, depth: depth)
        case nil:
            MojuPageLogger.debug("unsupported component: \(component.type)")
            #if DEBUG
            contentView = makeUnsupportedComponent(type: component.type)
            #else
            contentView = nil
            #endif
        }

        guard let contentView else { return nil }
        let isContainer: Bool
        switch MojuComponentType(rawValue: component.type) {
        case .card, .row, .selectableCard, .tableView, .collectionView: isContainer = true
        default: isContainer = false
        }
        let wrappedView = wrap(contentView, style: effectiveStyle, parser: context.styleParser, isContainer: isContainer)
        let skipsTapAction = contentView is UIButton || MojuComponentType(rawValue: component.type) == .selectableCard
        attachTapActionIfNeeded(component.action, to: wrappedView, context: context, skipsButton: skipsTapAction)
        return wrappedView
    }

    private func makeText(_ component: MojuComponent, context: MojuRenderContext) -> UIView {
        let label = UILabel()
        let resolved = component.text.map { context.templateResolver.resolveString($0) }
        label.text = resolved?.isEmpty == false ? resolved : component.defaultText
        label.font = context.styleParser.font(size: component.style?.fontSize, weight: component.style?.fontWeight)
        label.textColor = context.styleParser.color(from: component.style?.textColor, default: .label)
        label.textAlignment = context.styleParser.textAlignment(from: component.style?.alignment)
        label.numberOfLines = component.style?.numberOfLines ?? 0
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    private func makeImage(_ component: MojuComponent, context: MojuRenderContext) -> UIView {
        let imageView = UIImageView()
        imageView.backgroundColor = placeholderColor
        imageView.clipsToBounds = true
        imageView.contentMode = context.styleParser.contentMode(from: component.style?.contentMode)

        if let placeholder = component.placeholderImage {
            imageView.image = context.imageProvider.image(named: placeholder)
        }

        let urlString = component.imageUrl.map { context.templateResolver.resolveString($0) } ?? ""
        imageView.accessibilityIdentifier = urlString

        guard
            let url = URL(string: urlString),
            ["http", "https"].contains(url.scheme?.lowercased())
        else {
            return imageView
        }

        let task = Task { [weak imageView] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, data.count <= MojuPageLimits.maxResponseBytes else { return }
                let image = UIImage(data: data)
                await MainActor.run {
                    guard imageView?.accessibilityIdentifier == urlString else { return }
                    imageView?.image = image
                    imageView?.backgroundColor = .clear
                }
            } catch {
                MojuPageLogger.debug("image load failed: \(url.absoluteString)")
            }
        }
        context.registerImageTask(task)

        return imageView
    }

    private func makeInput(_ component: MojuComponent, context: MojuRenderContext) -> UIView {
        let textField = UITextField()
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.font = context.styleParser.font(size: component.style?.fontSize, weight: component.style?.fontWeight)
        textField.textColor = context.styleParser.color(from: component.style?.textColor, default: .label)
        textField.textAlignment = context.styleParser.textAlignment(from: component.style?.alignment)
        textField.placeholder = component.placeholder.map { context.templateResolver.resolveString($0) }
        textField.keyboardType = keyboardType(from: component.keyboardType)
        textField.returnKeyType = .done
        textField.clearButtonMode = .whileEditing

        let initialText = initialInputText(for: component, context: context)
        textField.text = initialText
        syncInputValue(initialText, component: component, context: context)

        textField.addAction(UIAction { [weak textField] _ in
            guard let textField else { return }
            if let maxLength = component.maxLength, maxLength >= 0, textField.text?.count ?? 0 > maxLength {
                textField.text = String((textField.text ?? "").prefix(maxLength))
            }
            if let stateKey = component.stateKey, !stateKey.isEmpty {
                context.dataStore.set(textField.text ?? "", forKey: stateKey)
            }
        }, for: .editingChanged)

        textField.addAction(UIAction { [weak textField] _ in
            textField?.resignFirstResponder()
        }, for: .editingDidEndOnExit)

        textField.addAction(UIAction { _ in
            context.actionHandler.onStateChanged?()
        }, for: .editingDidEnd)

        return textField
    }

    private func makeTextArea(_ component: MojuComponent, context: MojuRenderContext) -> UIView {
        let container = UIView()
        let textView = UITextView()
        let placeholderLabel = UILabel()

        container.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        textView.backgroundColor = .clear
        textView.font = context.styleParser.font(size: component.style?.fontSize, weight: component.style?.fontWeight)
        textView.textColor = context.styleParser.color(from: component.style?.textColor, default: .label)
        textView.textAlignment = context.styleParser.textAlignment(from: component.style?.alignment)
        textView.keyboardType = keyboardType(from: component.keyboardType)
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0

        placeholderLabel.text = component.placeholder.map { context.templateResolver.resolveString($0) }
        placeholderLabel.font = textView.font
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.numberOfLines = 0

        let initialText = initialInputText(for: component, context: context)
        textView.text = initialText
        placeholderLabel.isHidden = !initialText.isEmpty
        syncInputValue(initialText, component: component, context: context)

        let delegate = MojuTextViewDelegate(
            maxLength: component.maxLength,
            onChange: { [weak placeholderLabel, weak textView] text in
                placeholderLabel?.isHidden = !text.isEmpty
                if let stateKey = component.stateKey, !stateKey.isEmpty {
                    context.dataStore.set(text, forKey: stateKey)
                }
                textView?.invalidateIntrinsicContentSize()
            },
            onEndEditing: {
                context.actionHandler.onStateChanged?()
            }
        )
        textView.delegate = delegate
        objc_setAssociatedObject(textView, &dynamicTextViewDelegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        container.addSubview(textView)
        container.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: container.topAnchor),
            textView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor)
        ])

        return container
    }

    private func makeButton(_ component: MojuComponent, context: MojuRenderContext) -> UIView {
        let button = UIButton(type: .system)
        let title = component.text.map { context.templateResolver.resolveString($0) } ?? ""
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = context.styleParser.color(from: component.style?.backgroundColor, default: .systemBlue)
        configuration.baseForegroundColor = context.styleParser.color(from: component.style?.textColor, default: .white)
        button.configuration = configuration
        button.titleLabel?.font = context.styleParser.font(size: component.style?.fontSize, weight: component.style?.fontWeight)
        button.layer.cornerRadius = component.style?.cornerRadius ?? 0
        button.clipsToBounds = true

        if let action = component.action {
            button.addAction(UIAction { [weak button, action] _ in
                Task { @MainActor in
                    guard button?.isEnabled == true else { return }
                    button?.isEnabled = false
                    await context.actionHandler.handle(action)
                    button?.isEnabled = true
                }
            }, for: .touchUpInside)
        }

        return button
    }

    private func makeCard(_ component: MojuComponent, context: MojuRenderContext, depth: Int) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = component.style?.spacing ?? 0
        stackView.alignment = context.styleParser.stackAlignment(from: component.style?.stackAlignment)
        stackView.distribution = context.styleParser.stackDistribution(from: component.style?.distribution)
        context.renderChildren(component.children ?? [], stackView, depth + 1, nil)
        return stackView
    }

    private func makeRow(_ component: MojuComponent, context: MojuRenderContext, depth: Int) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = component.style?.spacing ?? 8
        stackView.alignment = context.styleParser.stackAlignment(from: component.style?.stackAlignment ?? "center")
        stackView.distribution = context.styleParser.stackDistribution(from: component.style?.distribution)
        context.renderChildren(component.children ?? [], stackView, depth + 1, nil)
        if shouldAddTrailingSpacer(to: component) {
            let spacer = UIView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            stackView.addArrangedSubview(spacer)
        }
        return stackView
    }

    private func makeTableView(_ component: MojuComponent, context: MojuRenderContext, depth: Int) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = component.style?.spacing ?? 0
        stackView.alignment = context.styleParser.stackAlignment(from: component.style?.stackAlignment)
        stackView.distribution = context.styleParser.stackDistribution(from: component.style?.distribution)
        renderListItems(component, into: stackView, context: context, depth: depth)
        return stackView
    }

    private func makeCollectionView(_ component: MojuComponent, context: MojuRenderContext, depth: Int) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = component.style?.spacing ?? 8
        stackView.alignment = .fill
        stackView.distribution = .fill

        let items = context.templateResolver.resolveArray(component.forEach)
        let columns = max(component.columns ?? 2, 1)
        let itemName = component.forItem?.isEmpty == false ? component.forItem! : "item"
        let indexName = component.forIndex?.isEmpty == false ? component.forIndex! : "index"

        for chunkStart in stride(from: 0, to: items.count, by: columns) {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = component.style?.spacing ?? 8
            row.alignment = .fill
            row.distribution = .fillEqually

            let chunkEnd = min(chunkStart + columns, items.count)
            for index in chunkStart..<chunkEnd {
                let cell = makeListCell(
                    component,
                    item: items[index],
                    index: index,
                    itemName: itemName,
                    indexName: indexName,
                    context: context,
                    depth: depth
                )
                row.addArrangedSubview(cell)
            }

            if chunkEnd - chunkStart < columns {
                for _ in 0..<(columns - (chunkEnd - chunkStart)) {
                    row.addArrangedSubview(UIView())
                }
            }

            stackView.addArrangedSubview(row)
        }

        return stackView
    }

    private func renderListItems(_ component: MojuComponent, into stackView: UIStackView, context: MojuRenderContext, depth: Int) {
        let items = context.templateResolver.resolveArray(component.forEach)
        let itemName = component.forItem?.isEmpty == false ? component.forItem! : "item"
        let indexName = component.forIndex?.isEmpty == false ? component.forIndex! : "index"

        for (index, item) in items.enumerated() {
            let cell = makeListCell(
                component,
                item: item,
                index: index,
                itemName: itemName,
                indexName: indexName,
                context: context,
                depth: depth
            )
            stackView.addArrangedSubview(cell)
        }
    }

    private func makeListCell(
        _ component: MojuComponent,
        item: MojuValue,
        index: Int,
        itemName: String,
        indexName: String,
        context: MojuRenderContext,
        depth: Int
    ) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = component.style?.spacing ?? 0
        stackView.alignment = context.styleParser.stackAlignment(from: component.style?.stackAlignment)
        stackView.distribution = context.styleParser.stackDistribution(from: component.style?.distribution)
        let resolver = context.templateResolver.withLocalValues([
            itemName: item,
            indexName: .int(index)
        ])
        context.renderChildren(component.children ?? [], stackView, depth + 1, resolver)
        return stackView
    }

    private func makeIcon(_ component: MojuComponent, context: MojuRenderContext) -> UIView {
        let imageView = UIImageView()
        let iconName = component.iconName.map { context.templateResolver.resolveString($0) } ?? ""
        imageView.image = context.imageProvider.systemImage(named: iconName) ?? context.imageProvider.image(named: iconName)
        imageView.tintColor = context.styleParser.color(from: component.style?.textColor, default: .label)
        imageView.contentMode = context.styleParser.contentMode(from: component.style?.contentMode ?? "aspectFit")
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return imageView
    }

    private func makeSelectableCard(_ component: MojuComponent, context: MojuRenderContext, depth: Int) -> UIView {
        let card = makeCard(component, context: context, depth: depth)
        let tapRecognizer = UITapGestureRecognizer(target: nil, action: nil)
        let action = component.action
        tapRecognizer.addAction {
            Task { @MainActor in
                if let stateKey = component.stateKey, let value = component.value {
                    await context.actionHandler.handle(MojuAction(type: "setState", stateKey: stateKey, value: value), resolver: context.templateResolver)
                }
                if let action {
                    await context.actionHandler.handle(action, resolver: context.templateResolver)
                }
            }
        }
        card.addGestureRecognizer(tapRecognizer)
        card.isUserInteractionEnabled = true
        return card
    }

    private func makeUnsupportedComponent(type: String) -> UIView {
        let label = UILabel()
        label.text = "Unsupported component: \(type)"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.backgroundColor = .systemGray6
        label.numberOfLines = 0
        return label
    }

    private func attachTapActionIfNeeded(
        _ action: MojuAction?,
        to view: UIView,
        context: MojuRenderContext,
        skipsButton: Bool
    ) {
        guard let action, !skipsButton else { return }
        let tapRecognizer = UITapGestureRecognizer(target: nil, action: nil)
        tapRecognizer.addAction {
            Task { @MainActor in
                await context.actionHandler.handle(action, resolver: context.templateResolver)
            }
        }
        view.addGestureRecognizer(tapRecognizer)
        view.isUserInteractionEnabled = true
    }

    private func wrap(_ contentView: UIView, style: MojuStyle?, parser: MojuStyleParser, isContainer: Bool = false) -> UIView {
        let usesFitContentWidth = isFitContentWidth(style)
        let container: UIView = usesFitContentWidth ? MojuFitContentContainerView() : UIView()
        let innerView = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        innerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        container.backgroundColor = .clear
        innerView.backgroundColor = parser.color(from: style?.backgroundColor, default: .clear)
        innerView.layer.cornerRadius = style?.cornerRadius ?? 0
        innerView.layer.borderWidth = style?.borderWidth ?? 0
        innerView.layer.borderColor = parser.color(from: style?.borderColor, default: .clear).cgColor
        innerView.clipsToBounds = (style?.cornerRadius ?? 0) > 0
        container.isHidden = style?.hidden ?? false

        container.addSubview(innerView)
        innerView.addSubview(contentView)

        let marginTop = style?.marginTop ?? 0
        let marginBottom = style?.marginBottom ?? 0
        let marginLeft = style?.marginLeft ?? 0
        let marginRight = style?.marginRight ?? 0
        let paddingTop = style?.paddingTop ?? 0
        let paddingBottom = style?.paddingBottom ?? 0
        let paddingLeft = style?.paddingLeft ?? 0
        let paddingRight = style?.paddingRight ?? 0

        if let fitContentContainer = container as? MojuFitContentContainerView {
            fitContentContainer.measuredContentView = contentView
            fitContentContainer.extraWidth = paddingLeft + paddingRight + marginLeft + marginRight
        }

        var constraints = [
            innerView.topAnchor.constraint(equalTo: container.topAnchor, constant: marginTop),
            innerView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: marginLeft),
            innerView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -marginBottom),
            contentView.topAnchor.constraint(equalTo: innerView.topAnchor, constant: paddingTop),
            contentView.leadingAnchor.constraint(equalTo: innerView.leadingAnchor, constant: paddingLeft),
            contentView.bottomAnchor.constraint(equalTo: innerView.bottomAnchor, constant: -paddingBottom)
        ]

        if usesFitContentWidth {
            constraints.append(contentsOf: [
                contentView.trailingAnchor.constraint(equalTo: innerView.trailingAnchor, constant: -paddingRight),
                innerView.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -marginRight)
            ])
            if style?.width == nil, let contentWidth = measuredFitContentWidth(for: contentView) {
                let innerWidth = contentWidth + paddingLeft + paddingRight
                constraints.append(contentsOf: [
                    innerView.widthAnchor.constraint(equalToConstant: innerWidth),
                    container.widthAnchor.constraint(equalToConstant: innerWidth + marginLeft + marginRight)
                ])
            }
            [container, innerView, contentView].forEach {
                $0.setContentHuggingPriority(.required, for: .horizontal)
                $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            }
        } else {
            constraints.append(contentsOf: [
                contentView.trailingAnchor.constraint(equalTo: innerView.trailingAnchor, constant: -paddingRight),
                innerView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -marginRight)
            ])
        }

        if let height = style?.height {
            // For containers (row/card): height constrains innerView (the shell including padding).
            // For leaf views (text/image/icon/button/space): height constrains contentView directly.
            let heightTarget: UIView = isContainer ? innerView : contentView
            constraints.append(heightTarget.heightAnchor.constraint(equalToConstant: height))
        }
        if let width = style?.width {
            let widthTarget: UIView = isContainer ? innerView : contentView
            constraints.append(widthTarget.widthAnchor.constraint(equalToConstant: width))
        }

        NSLayoutConstraint.activate(constraints)
        return container
    }

    private func measuredFitContentWidth(for contentView: UIView) -> CGFloat? {
        let intrinsicWidth = contentView.intrinsicContentSize.width
        if intrinsicWidth > 0, intrinsicWidth != UIView.noIntrinsicMetric {
            return ceil(intrinsicWidth)
        }

        let fittingSize = contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        guard fittingSize.width > 0 else { return nil }
        return ceil(fittingSize.width)
    }

    private func isFitContentWidth(_ style: MojuStyle?) -> Bool {
        guard let widthMode = style?.widthMode?.lowercased() else { return false }
        return widthMode == "fit-content" || widthMode == "hug-content" || widthMode == "content"
    }

    private func shouldAddTrailingSpacer(to component: MojuComponent) -> Bool {
        guard component.style?.distribution == nil else { return false }
        guard let children = component.children, !children.isEmpty else { return false }
        return children.allSatisfy { isFitContentWidth($0.style) }
    }

    private func isVisible(_ component: MojuComponent, context: MojuRenderContext) -> Bool {
        if component.style?.hidden == true {
            return false
        }

        guard let visible = component.visible else {
            return true
        }

        switch context.templateResolver.resolveValue(visible) {
        case .bool(let value):
            return value
        case .string(let value):
            return !value.isEmpty && value != "false" && value != "0"
        case .int(let value):
            return value != 0
        case .double(let value):
            return value != 0
        case .null:
            return false
        case .object, .array:
            return true
        }
    }

    private func effectiveStyle(for component: MojuComponent, context: MojuRenderContext) -> MojuStyle? {
        guard isSelected(component, context: context) else {
            return component.style
        }

        if let style = component.style {
            return style.merging(component.selectedStyle)
        }
        return component.selectedStyle
    }

    private func isSelected(_ component: MojuComponent, context: MojuRenderContext) -> Bool {
        guard let stateKey = component.stateKey, let value = component.value else {
            return false
        }

        let current = MojuValue.fromAny(context.dataStore.value(forKeyPath: stateKey))
        let expected = context.templateResolver.resolveValue(value)
        return current.stringValue == expected.stringValue
    }

    private func initialInputText(for component: MojuComponent, context: MojuRenderContext) -> String {
        if let stateKey = component.stateKey,
           let current = context.dataStore.value(forKeyPath: stateKey) {
            return MojuValue.fromAny(current).stringValue ?? ""
        }
        if let text = component.text {
            return context.templateResolver.resolveString(text)
        }
        if let defaultText = component.defaultText {
            return context.templateResolver.resolveString(defaultText)
        }
        return ""
    }

    private func syncInputValue(_ text: String, component: MojuComponent, context: MojuRenderContext) {
        guard let stateKey = component.stateKey, !stateKey.isEmpty else { return }
        context.dataStore.set(text, forKey: stateKey)
    }

    private func keyboardType(from rawValue: String?) -> UIKeyboardType {
        switch rawValue?.lowercased() {
        case "number", "numberpad", "number-pad":
            return .numberPad
        case "decimal", "decimalpad", "decimal-pad":
            return .decimalPad
        case "phone", "phonepad", "phone-pad":
            return .phonePad
        case "email", "emailaddress", "email-address":
            return .emailAddress
        case "url":
            return .URL
        case "ascii", "ascii-capable":
            return .asciiCapable
        default:
            return .default
        }
    }
}

private var dynamicTextViewDelegateKey: UInt8 = 0

private final class MojuTextViewDelegate: NSObject, UITextViewDelegate {
    private let maxLength: Int?
    private let onChange: (String) -> Void
    private let onEndEditing: (() -> Void)?

    init(maxLength: Int?, onChange: @escaping (String) -> Void, onEndEditing: (() -> Void)? = nil) {
        self.maxLength = maxLength
        self.onChange = onChange
        self.onEndEditing = onEndEditing
    }

    func textViewDidChange(_ textView: UITextView) {
        if let maxLength, maxLength >= 0, textView.text.count > maxLength {
            textView.text = String(textView.text.prefix(maxLength))
        }
        onChange(textView.text)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        onEndEditing?()
    }
}

private extension UITapGestureRecognizer {
    func addAction(_ action: @escaping () -> Void) {
        let sleeve = MojuGestureSleeve(action)
        addTarget(sleeve, action: #selector(MojuGestureSleeve.invoke))
        objc_setAssociatedObject(self, &dynamicGestureSleeveKey, sleeve, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

private var dynamicGestureSleeveKey: UInt8 = 0

private final class MojuGestureSleeve {
    private let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }

    @objc func invoke() {
        action()
    }
}
