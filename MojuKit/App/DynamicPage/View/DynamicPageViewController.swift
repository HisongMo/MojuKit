import UIKit

final class DynamicPageViewController: UIViewController {
    var onNavigate: ((_ target: String, _ params: [String: DynamicValue]?) -> Void)? {
        didSet { actionHandler?.onNavigate = onNavigate }
    }
    var onNativeNavigate: ((_ target: String, _ params: [String: DynamicValue]?) -> Void)? {
        didSet { actionHandler?.onNativeNavigate = onNativeNavigate }
    }
    var onTrackEvent: ((_ eventName: String, _ params: [String: DynamicValue]?) -> Void)? {
        didSet { actionHandler?.onTrackEvent = onTrackEvent }
    }
    var onShowModal: ((_ target: String, _ params: [String: DynamicValue]?) -> Void)? {
        didSet { actionHandler?.onShowModal = onShowModal }
    }
    var onConfirmHighRiskRequest: ((_ apiKey: String, _ params: [String: Any], _ completion: @escaping (Bool) -> Void) -> Void)? {
        didSet { requestExecutor?.onConfirmHighRiskRequest = onConfirmHighRiskRequest }
    }

    private let page: DynamicPage
    private let networkProvider: DynamicNetworkProviding
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    private let fixedBottomContainerView = UIView()
    private let fixedBottomStackView = UIStackView()
    private let stateLabel = UILabel()
    private let loadingView = UIActivityIndicatorView(style: .large)
    private var dataStore: DynamicDataStore!
    private var requestExecutor: DynamicRequestExecutor!
    private var actionHandler: DynamicActionHandler!
    private var renderer: DynamicPageRenderer!
    private var fixedBottomRenderer: DynamicPageRenderer?
    private var loadTask: Task<Void, Never>?
    private var hasLoadedRequests = false

    init(page: DynamicPage, networkProvider: DynamicNetworkProviding) {
        self.page = page
        self.networkProvider = networkProvider
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupDependencies()
        setupViews()
        setupNavigationBar()
        renderInitialPage()
        executeOnLoadIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavigationBar()
    }

    deinit {
        loadTask?.cancel()
    }

    private func setupDependencies() {
        dataStore = DynamicDataStore(pageParams: page.pageParams)
        requestExecutor = DynamicRequestExecutor(networkProvider: networkProvider, dataStore: dataStore)
        actionHandler = DynamicActionHandler(dataStore: dataStore, requestExecutor: requestExecutor)
        renderer = DynamicPageRenderer(page: page, stackView: stackView, dataStore: dataStore, actionHandler: actionHandler)

        actionHandler.onNavigate = onNavigate
        actionHandler.onNativeNavigate = onNativeNavigate
        actionHandler.onTrackEvent = onTrackEvent
        actionHandler.onShowModal = onShowModal
        actionHandler.onShowToast = { [weak self] message in
            self?.showToast(message)
        }
        actionHandler.onStateChanged = { [weak self] in
            self?.renderAll()
        }

        requestExecutor.onShowLoading = { [weak self] text in
            self?.showLoading(text: text)
        }
        requestExecutor.onHideLoading = { [weak self] in
            self?.hideLoading()
        }
        requestExecutor.onRequestFinished = { [weak self] in
            self?.renderAll()
        }
        requestExecutor.onConfirmHighRiskRequest = onConfirmHighRiskRequest
    }

    private func setupViews() {
        title = page.pageTitle
        view.backgroundColor = DynamicStyleParser().color(from: page.backgroundColor, default: .systemBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        fixedBottomContainerView.translatesAutoresizingMaskIntoConstraints = false
        fixedBottomStackView.translatesAutoresizingMaskIntoConstraints = false
        stateLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingView.translatesAutoresizingMaskIntoConstraints = false

        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.alignment = .fill
        stackView.distribution = .fill
        fixedBottomStackView.axis = .vertical
        fixedBottomStackView.spacing = 0
        fixedBottomStackView.alignment = .fill
        fixedBottomStackView.distribution = .fill
        fixedBottomContainerView.backgroundColor = view.backgroundColor

        stateLabel.textAlignment = .center
        stateLabel.numberOfLines = 0
        stateLabel.textColor = .secondaryLabel
        stateLabel.isHidden = true

        view.addSubview(scrollView)
        view.addSubview(fixedBottomContainerView)
        view.addSubview(stateLabel)
        view.addSubview(loadingView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        fixedBottomContainerView.addSubview(fixedBottomStackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: fixedBottomContainerView.topAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            fixedBottomContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fixedBottomContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            fixedBottomContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            fixedBottomStackView.topAnchor.constraint(equalTo: fixedBottomContainerView.topAnchor),
            fixedBottomStackView.leadingAnchor.constraint(equalTo: fixedBottomContainerView.leadingAnchor),
            fixedBottomStackView.trailingAnchor.constraint(equalTo: fixedBottomContainerView.trailingAnchor),
            fixedBottomStackView.bottomAnchor.constraint(equalTo: fixedBottomContainerView.safeAreaLayoutGuide.bottomAnchor),
            stateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func renderInitialPage() {
        do {
            try DynamicSchemaValidator.validate(page)
            fixedBottomRenderer = DynamicPageRenderer(
                page: page,
                components: page.fixedBottomComponents ?? [],
                stackView: fixedBottomStackView,
                dataStore: dataStore,
                actionHandler: actionHandler
            )
            renderAll()
        } catch {
            showErrorState()
        }
    }

    private func renderAll() {
        renderer.render()
        fixedBottomRenderer?.render()
        fixedBottomContainerView.isHidden = page.fixedBottomComponents?.isEmpty ?? true
        
        let parser = DynamicStyleParser()
        if let firstComponent = page.fixedBottomComponents?.first,
           let bgColorString = firstComponent.style?.backgroundColor {
            fixedBottomContainerView.backgroundColor = parser.color(from: bgColorString, default: view.backgroundColor ?? .systemBackground)
        } else {
            fixedBottomContainerView.backgroundColor = view.backgroundColor
        }
        
        updateEmptyState()
    }

    private func executeOnLoadIfNeeded() {
        guard !hasLoadedRequests else { return }
        hasLoadedRequests = true

        let requests = page.onLoad ?? []
        guard !requests.isEmpty else { return }

        loadTask = Task { [weak self] in
            guard let self else { return }
            for request in requests {
                guard !Task.isCancelled else { return }
                do {
                    _ = try await requestExecutor.execute(request: request)
                } catch {
                    DynamicPageLogger.debug("onLoad failed: \(request.apiKey)")
                }
            }
        }
    }

    private func updateEmptyState() {
        let isEmpty = stackView.arrangedSubviews.isEmpty
        stateLabel.text = isEmpty ? "暂无内容" : nil
        stateLabel.isHidden = !isEmpty
    }

    private func showErrorState() {
        renderer?.cleanup()
        stateLabel.text = "页面加载失败，请稍后再试"
        stateLabel.isHidden = false
    }

    private func showLoading(text: String?) {
        loadingView.startAnimating()
        stateLabel.text = text
        stateLabel.isHidden = text?.isEmpty ?? true
    }

    private func hideLoading() {
        loadingView.stopAnimating()
        stateLabel.isHidden = true
    }

    private func showToast(_ message: String) {
        guard let parentView = view.window ?? view else { return }

        // Blur Effect Container
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 18
        blurView.clipsToBounds = true
        blurView.alpha = 0
        
        // Icon Name & Color selection based on message
        let iconName: String
        let iconColor: UIColor
        let msg = message.lowercased()
        if msg.contains("成功") || msg.contains("保存") || msg.contains("完成") || msg.contains("已") {
            iconName = "checkmark.circle.fill"
            iconColor = .systemGreen
        } else if msg.contains("失败") || msg.contains("错误") || msg.contains("异常") || msg.contains("未") {
            iconName = "xmark.circle.fill"
            iconColor = .systemRed
        } else {
            iconName = "info.circle.fill"
            iconColor = .white
        }
        
        // Icon (UIImageView)
        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: iconName)
        iconView.tintColor = iconColor
        iconView.contentMode = .scaleAspectFit
        
        // Label (UILabel)
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = message
        label.textColor = .white
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        // Stack View to align them vertically
        let stackView = UIStackView(arrangedSubviews: [iconView, label])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 14
        
        blurView.contentView.addSubview(stackView)
        parentView.addSubview(blurView)
        
        NSLayoutConstraint.activate([
            // Position: Center on the whole window / screen
            blurView.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),
            blurView.centerYAnchor.constraint(equalTo: parentView.centerYAnchor),
            
            // Size bounds: square of size between 140 and 220
            blurView.widthAnchor.constraint(equalTo: blurView.heightAnchor),
            blurView.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            blurView.widthAnchor.constraint(lessThanOrEqualToConstant: 220),
            
            // Stack View Constraints (inner padding)
            stackView.topAnchor.constraint(greaterThanOrEqualTo: blurView.contentView.topAnchor, constant: 18),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: blurView.contentView.bottomAnchor, constant: -18),
            stackView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -16),
            stackView.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            
            // Icon Dimensions
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48)
        ])
        
        // Animation
        UIView.animate(withDuration: 0.25) {
            blurView.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.25, delay: 1.5) {
                blurView.alpha = 0
            } completion: { _ in
                blurView.removeFromSuperview()
            }
        }
    }

    private func setupNavigationBar() {
        guard let navigationController else { return }
        
        if let config = page.navigationBar {
            // 1. Control hidden state
            let isHidden = config.hidden ?? false
            navigationController.setNavigationBarHidden(isHidden, animated: false)
            
            if isHidden {
                return
            }
            
            // 2. Configure appearance
            let appearance = UINavigationBarAppearance()
            
            let parser = DynamicStyleParser()
            if let bgColorString = config.backgroundColor {
                let color = parser.color(from: bgColorString, default: .systemBackground)
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = color
            } else {
                appearance.configureWithDefaultBackground()
            }
            
            // Text color config
            var titleTextAttributes: [NSAttributedString.Key: Any] = [:]
            if let textColorString = config.textColor {
                let color = parser.color(from: textColorString, default: .label)
                titleTextAttributes[.foregroundColor] = color
                navigationController.navigationBar.tintColor = color
            } else {
                navigationController.navigationBar.tintColor = .systemBlue
            }
            appearance.titleTextAttributes = titleTextAttributes
            
            navigationController.navigationBar.standardAppearance = appearance
            navigationController.navigationBar.scrollEdgeAppearance = appearance
            navigationController.navigationBar.compactAppearance = appearance
            
            // 3. Back Button
            if config.hideBackButton == true {
                navigationItem.hidesBackButton = true
                navigationItem.leftBarButtonItem = nil
            } else if let customBack = config.backButton {
                navigationItem.hidesBackButton = false
                let action = UIAction { [weak self] _ in
                    if let customAction = customBack.action {
                        Task { @MainActor [weak self] in
                            await self?.actionHandler.handle(customAction)
                        }
                    } else {
                        self?.navigationController?.popViewController(animated: true)
                    }
                }
                
                let barButtonItem: UIBarButtonItem
                if let iconName = customBack.iconName {
                    let image = UIImage(systemName: iconName) ?? UIImage(named: iconName)
                    barButtonItem = UIBarButtonItem(image: image, primaryAction: action)
                } else {
                    barButtonItem = UIBarButtonItem(title: customBack.text ?? "返回", style: .plain, target: nil, action: nil)
                    barButtonItem.primaryAction = action
                }
                navigationItem.leftBarButtonItem = barButtonItem
            } else {
                navigationItem.hidesBackButton = false
                navigationItem.leftBarButtonItem = nil
            }
            
            // 4. Right/Action Buttons
            if let rightButtons = config.rightButtons, !rightButtons.isEmpty {
                var items: [UIBarButtonItem] = []
                for button in rightButtons {
                    let action = UIAction { [weak self] _ in
                        if let customAction = button.action {
                            Task { @MainActor [weak self] in
                                await self?.actionHandler.handle(customAction)
                            }
                        }
                    }
                    
                    let item: UIBarButtonItem
                    if let iconName = button.iconName {
                        let image = UIImage(systemName: iconName) ?? UIImage(named: iconName)
                        item = UIBarButtonItem(image: image, primaryAction: action)
                    } else {
                        item = UIBarButtonItem(title: button.text ?? "", style: .plain, target: nil, action: nil)
                        item.primaryAction = action
                    }
                    item.accessibilityIdentifier = button.id
                    items.append(item)
                }
                navigationItem.rightBarButtonItems = items
            } else {
                navigationItem.rightBarButtonItems = nil
            }
        } else {
            // Restore default navigation bar styles if no configuration provided
            navigationController.setNavigationBarHidden(false, animated: false)
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            navigationController.navigationBar.standardAppearance = appearance
            navigationController.navigationBar.scrollEdgeAppearance = appearance
            navigationController.navigationBar.compactAppearance = appearance
            navigationController.navigationBar.tintColor = .systemBlue
            navigationItem.hidesBackButton = false
            navigationItem.leftBarButtonItem = nil
            navigationItem.rightBarButtonItems = nil
        }
    }
}
