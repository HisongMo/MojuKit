import UIKit

final class DynamicPageRemoteRetrieveViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let mainStackView = UIStackView()
    
    // Inputs Card
    private let inputsCard = UIView()
    private let serverURLLabel = UILabel()
    private let serverURLField = UITextField()
    private let projectKeyLabel = UILabel()
    private let projectKeyField = UITextField()
    private let pageNameLabel = UILabel()
    private let pageNameField = UITextField()
    
    // Action Buttons Row
    private let buttonsStackView = UIStackView()
    private let fetchManifestButton = UIButton(type: .system)
    private let fetchPageButton = UIButton(type: .system)
    private let fetchPackageButton = UIButton(type: .system)
    
    // Results
    private let logHeaderLabel = UILabel()
    private let logTextView = UITextView()
    
    // Pages List Card
    private let pagesCard = UIView()
    private let pagesHeaderLabel = UILabel()
    private let pagesStackView = UIStackView()
    
    private var fetchedPages: [[String: Any]] = []
    private var packagePages: [String: Any] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "远程获取测试"
        view.backgroundColor = .systemGroupedBackground
        setupViews()
        setupKeyboardTappedDismiss()
    }
    
    private func setupViews() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        
        mainStackView.axis = .vertical
        mainStackView.spacing = 20
        mainStackView.alignment = .fill
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            
            mainStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            mainStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
        
        setupInputsCard()
        setupActionButtons()
        setupLogView()
        setupPagesCard()
    }
    
    private func setupInputsCard() {
        inputsCard.backgroundColor = .secondarySystemGroupedBackground
        inputsCard.layer.cornerRadius = 12
        inputsCard.layer.masksToBounds = true
        inputsCard.translatesAutoresizingMaskIntoConstraints = false
        
        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 12
        cardStack.alignment = .fill
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        
        configureLabel(serverURLLabel, text: "服务器地址")
        serverURLField.text = "http://10.18.20.97:8099"
        serverURLField.borderStyle = .roundedRect
        serverURLField.autocapitalizationType = .none
        serverURLField.autocorrectionType = .no
        
        configureLabel(projectKeyLabel, text: "项目 Key (projectKey)")
        projectKeyField.text = ""
        projectKeyField.borderStyle = .roundedRect
        projectKeyField.autocapitalizationType = .none
        projectKeyField.autocorrectionType = .no
        
        configureLabel(pageNameLabel, text: "单页面名称 (page)")
        pageNameField.text = ""
        pageNameField.borderStyle = .roundedRect
        pageNameField.autocapitalizationType = .none
        pageNameField.autocorrectionType = .no
        
        cardStack.addArrangedSubview(serverURLLabel)
        cardStack.addArrangedSubview(serverURLField)
        cardStack.addArrangedSubview(projectKeyLabel)
        cardStack.addArrangedSubview(projectKeyField)
        cardStack.addArrangedSubview(pageNameLabel)
        cardStack.addArrangedSubview(pageNameField)
        
        inputsCard.addSubview(cardStack)
        mainStackView.addArrangedSubview(inputsCard)
        
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: inputsCard.topAnchor, constant: 16),
            cardStack.leadingAnchor.constraint(equalTo: inputsCard.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: inputsCard.trailingAnchor, constant: -16),
            cardStack.bottomAnchor.constraint(equalTo: inputsCard.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupActionButtons() {
        buttonsStackView.axis = .horizontal
        buttonsStackView.spacing = 10
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        configureButton(fetchManifestButton, title: "获取 Manifest", color: .systemBlue, action: #selector(fetchManifest))
        configureButton(fetchPageButton, title: "获取单页", color: .systemOrange, action: #selector(fetchPage))
        configureButton(fetchPackageButton, title: "获取 Package", color: .systemGreen, action: #selector(fetchPackage))
        
        buttonsStackView.addArrangedSubview(fetchManifestButton)
        buttonsStackView.addArrangedSubview(fetchPageButton)
        buttonsStackView.addArrangedSubview(fetchPackageButton)
        
        mainStackView.addArrangedSubview(buttonsStackView)
        
        NSLayoutConstraint.activate([
            buttonsStackView.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupLogView() {
        configureLabel(logHeaderLabel, text: "请求响应日志")
        
        logTextView.backgroundColor = .secondarySystemGroupedBackground
        logTextView.textColor = .label
        logTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        logTextView.layer.cornerRadius = 8
        logTextView.isEditable = false
        logTextView.isScrollEnabled = false // Let stack view expand or shrink it
        logTextView.translatesAutoresizingMaskIntoConstraints = false
        
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 8
        container.addArrangedSubview(logHeaderLabel)
        container.addArrangedSubview(logTextView)
        
        mainStackView.addArrangedSubview(container)
        
        NSLayoutConstraint.activate([
            logTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
    }
    
    private func setupPagesCard() {
        pagesCard.backgroundColor = .secondarySystemGroupedBackground
        pagesCard.layer.cornerRadius = 12
        pagesCard.layer.masksToBounds = true
        pagesCard.translatesAutoresizingMaskIntoConstraints = false
        pagesCard.isHidden = true
        
        configureLabel(pagesHeaderLabel, text: "解析到的页面 (点击渲染)")
        pagesHeaderLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        
        pagesStackView.axis = .vertical
        pagesStackView.spacing = 8
        pagesStackView.alignment = .fill
        pagesStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let stackContainer = UIStackView()
        stackContainer.axis = .vertical
        stackContainer.spacing = 12
        stackContainer.translatesAutoresizingMaskIntoConstraints = false
        stackContainer.addArrangedSubview(pagesHeaderLabel)
        stackContainer.addArrangedSubview(pagesStackView)
        
        pagesCard.addSubview(stackContainer)
        mainStackView.addArrangedSubview(pagesCard)
        
        NSLayoutConstraint.activate([
            stackContainer.topAnchor.constraint(equalTo: pagesCard.topAnchor, constant: 16),
            stackContainer.leadingAnchor.constraint(equalTo: pagesCard.leadingAnchor, constant: 16),
            stackContainer.trailingAnchor.constraint(equalTo: pagesCard.trailingAnchor, constant: -16),
            stackContainer.bottomAnchor.constraint(equalTo: pagesCard.bottomAnchor, constant: -16)
        ])
    }
    
    private func configureLabel(_ label: UILabel, text: String) {
        label.text = text
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
    }
    
    private func configureButton(_ button: UIButton, title: String, color: UIColor, action: Selector) {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = color
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        button.configuration = config
        button.addTarget(self, action: action, for: .touchUpInside)
    }
    
    private func getClient() -> DynamicPagePreviewClient? {
        guard let urlString = serverURLField.text,
              let url = URL(string: urlString) else {
            log("❌ 无效的服务器 URL")
            return nil
        }
        return DynamicPagePreviewClient(baseURL: url)
    }
    
    private func log(_ message: String) {
        logTextView.text = message
    }
    
    @objc private func fetchManifest() {
        guard let client = getClient() else { return }
        guard let projectKey = projectKeyField.text, !projectKey.isEmpty else {
            log("❌ 请输入 projectKey")
            return
        }
        
        log("🔄 正在获取 manifest.json...")
        Task {
            do {
                let manifestEnvelope = try await client.fetchRuntimeManifest(projectKey: projectKey)
                await MainActor.run {
                    if let data = try? JSONSerialization.data(withJSONObject: manifestEnvelope, options: [.prettyPrinted, .sortedKeys]),
                       let string = String(data: data, encoding: .utf8) {
                        self.log(string)
                    } else {
                        self.log("✅ 获取成功: \(manifestEnvelope)")
                    }
                    
                    let dataDict = manifestEnvelope["data"] as? [String: Any] ?? manifestEnvelope
                    self.fetchedPages = dataDict["pages"] as? [[String: Any]] ?? []
                    self.packagePages = [:]
                    self.updatePagesList(isPackage: false)
                }
            } catch {
                await MainActor.run {
                    self.log("❌ 获取 Manifest 失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func fetchPage() {
        guard let client = getClient() else { return }
        guard let projectKey = projectKeyField.text, !projectKey.isEmpty else {
            log("❌ 请输入 projectKey")
            return
        }
        guard let pageName = pageNameField.text, !pageName.isEmpty else {
            log("❌ 请输入页面名称")
            return
        }
        
        log("🔄 正在获取页面 \(pageName)...")
        Task {
            do {
                let page = try await client.fetchRuntimePage(projectKey: projectKey, pageName: pageName)
                await MainActor.run {
                    self.log("✅ 获取页面成功: \(pageName)\nTitle: \(page.pageTitle ?? "无")\nComponents: \(page.components.count)个")
                    self.openPage(page)
                }
            } catch {
                await MainActor.run {
                    self.log("❌ 获取页面失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func fetchPackage() {
        guard let client = getClient() else { return }
        guard let projectKey = projectKeyField.text, !projectKey.isEmpty else {
            log("❌ 请输入 projectKey")
            return
        }
        
        log("🔄 正在打包获取整个项目（从 Manifest 并行下载页面）...")
        Task {
            do {
                let manifestEnvelope = try await client.fetchRuntimeManifest(projectKey: projectKey)
                let dataDict = manifestEnvelope["data"] as? [String: Any] ?? manifestEnvelope
                let pagesList = dataDict["pages"] as? [[String: Any]] ?? []
                let activePageName = dataDict["activePage"] as? String ?? (pagesList.first?["pageName"] as? String ?? pagesList.first?["name"] as? String ?? "")
                
                await MainActor.run {
                    self.log("✅ 已成功获取 Manifest，包含 \(pagesList.count) 个页面，开始下载各页面内容...")
                }
                
                var tempPages: [String: Any] = [:]
                try await withThrowingTaskGroup(of: (String, DynamicPage).self) { group in
                    for item in pagesList {
                        guard let name = item["pageName"] as? String ?? item["name"] as? String else { continue }
                        group.addTask {
                            let page = try await client.fetchRuntimePage(projectKey: projectKey, pageName: name)
                            return (name, page)
                        }
                    }
                    for try await (name, page) in group {
                        tempPages[name] = page
                    }
                }
                
                await MainActor.run {
                    self.fetchedPages = []
                    self.packagePages = tempPages
                    self.updatePagesList(isPackage: true)
                    self.log("✅ 整包项目下载并解析成功！\n共下载页面: \(tempPages.keys.joined(separator: ", "))")
                    
                    // 自动打开 activePage
                    if let activePageModel = self.packagePages[activePageName] as? DynamicPage {
                        self.openPage(activePageModel)
                    } else if let firstPageModel = tempPages.values.first as? DynamicPage {
                        self.openPage(firstPageModel)
                    }
                }
            } catch {
                await MainActor.run {
                    self.log("❌ 获取 Package 失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func updatePagesList(isPackage: Bool) {
        // Clear old buttons
        pagesStackView.arrangedSubviews.forEach {
            $0.removeFromSuperview()
        }
        
        if isPackage {
            if packagePages.isEmpty {
                pagesCard.isHidden = true
                return
            }
            pagesCard.isHidden = false
            for (key, _) in packagePages.sorted(by: { $0.key < $1.key }) {
                addPageButton(title: key, tag: key, isPackage: true)
            }
        } else {
            if fetchedPages.isEmpty {
                pagesCard.isHidden = true
                return
            }
            pagesCard.isHidden = false
            for (index, item) in fetchedPages.enumerated() {
                let name = item["pageName"] as? String ?? item["name"] as? String ?? "Unnamed Page"
                addPageButton(title: name, tag: String(index), isPackage: false)
            }
        }
    }
    
    private func addPageButton(title: String, tag: String, isPackage: Bool) {
        let container = UIView()
        container.backgroundColor = .tertiarySystemGroupedBackground
        container.layer.cornerRadius = 8
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrow.tintColor = .tertiaryLabel
        arrow.translatesAutoresizingMaskIntoConstraints = false
        
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        if isPackage {
            button.setTitle(tag, for: .normal)
            button.setTitleColor(.clear, for: .normal)
            button.addTarget(self, action: #selector(packagePageTapped(_:)), for: .touchUpInside)
        } else {
            if let indexInt = Int(tag) {
                button.tag = indexInt
                button.addTarget(self, action: #selector(manifestPageTapped(_:)), for: .touchUpInside)
            }
        }
        
        container.addSubview(label)
        container.addSubview(arrow)
        container.addSubview(button)
        pagesStackView.addArrangedSubview(container)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 44),
            
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            arrow.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            arrow.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
    
    @objc private func manifestPageTapped(_ sender: UIButton) {
        let index = sender.tag
        guard fetchedPages.indices.contains(index) else { return }
        let pageItem = fetchedPages[index]
        let name = pageItem["pageName"] as? String ?? pageItem["name"] as? String ?? ""
        
        guard let projectKey = projectKeyField.text, !projectKey.isEmpty else { return }
        log("🔄 正在获取单独页面 \(name)...")
        
        Task {
            do {
                guard let client = getClient() else { return }
                let page = try await client.fetchRuntimePage(projectKey: projectKey, pageName: name)
                await MainActor.run {
                    self.log("✅ 加载成功: \(name)")
                    self.openPage(page)
                }
            } catch {
                await MainActor.run {
                    self.log("❌ 加载失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func packagePageTapped(_ sender: UIButton) {
        guard let pageKey = sender.title(for: .normal) else { return }
        
        if let page = findCachedPage(matching: pageKey) {
            log("✅ 从本地内存缓存读取成功: \(pageKey)")
            openPage(page)
        } else {
            log("❌ 未在缓存中找到页面: \(pageKey)")
        }
    }
    
    private func openPage(_ page: DynamicPage) {
        let vc = DynamicPageViewController(page: page, networkProvider: MockDynamicNetworkProvider())
        vc.onNavigate = { [weak self, weak vc] target, params in
            self?.handleNavigation(target: target, params: params, from: vc)
        }
        vc.onNativeNavigate = { [weak self, weak vc] target, params in
            self?.handleNativeNavigation(target: target, params: params, from: vc)
        }
        vc.onShowModal = { [weak self, weak vc] target, params in
            self?.handleShowModal(target: target, params: params, from: vc)
        }
        vc.onConfirmHighRiskRequest = { _, _, completion in
            completion(true)
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func handleNavigation(target: String, params: [String: DynamicValue]?, from vc: UIViewController?) {
        print("[Client] 收到导航跳转事件 - target: \(target), params: \(params ?? [:])")
        if target == "back" {
            vc?.navigationController?.popViewController(animated: true)
            return
        }
        
        // 1. 尝试从本地 package 内存缓存中匹配页面（支持页面名和 pageId 的模糊匹配）
        if let cachedPage = findCachedPage(matching: target) {
            let pageVC = DynamicPageViewController(page: cachedPage, networkProvider: MockDynamicNetworkProvider())
            pageVC.onNavigate = { [weak self, weak pageVC] t, p in
                self?.handleNavigation(target: t, params: p, from: pageVC)
            }
            pageVC.onNativeNavigate = { [weak self, weak pageVC] t, p in
                self?.handleNativeNavigation(target: t, params: p, from: pageVC)
            }
            pageVC.onShowModal = { [weak self, weak pageVC] t, p in
                self?.handleShowModal(target: t, params: p, from: pageVC)
            }
            self.navigationController?.pushViewController(pageVC, animated: true)
            return
        }
        
        // 2. 如果未命中本地缓存，向服务端请求对应页面
        log("🔄 正在从服务端跳转获取 \(target)...")
        Task {
            do {
                guard let client = getClient(),
                      let projectKey = projectKeyField.text else { return }
                let page = try await client.fetchRuntimePage(projectKey: projectKey, pageName: target)
                await MainActor.run {
                    let pageVC = DynamicPageViewController(page: page, networkProvider: MockDynamicNetworkProvider())
                    pageVC.onNavigate = { [weak self, weak pageVC] t, p in
                        self?.handleNavigation(target: t, params: p, from: pageVC)
                    }
                    pageVC.onNativeNavigate = { [weak self, weak pageVC] t, p in
                        self?.handleNativeNavigation(target: t, params: p, from: pageVC)
                    }
                    pageVC.onShowModal = { [weak self, weak pageVC] t, p in
                        self?.handleShowModal(target: t, params: p, from: pageVC)
                    }
                    self.navigationController?.pushViewController(pageVC, animated: true)
                }
            } catch {
                await MainActor.run {
                    self.log("❌ 跳转加载失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleShowModal(target: String, params: [String: DynamicValue]?, from vc: UIViewController?) {
        print("[Client] 收到弹窗事件 - target: \(target), params: \(params ?? [:])")
        
        // 1. 尝试从本地 package 内存缓存中匹配页面
        if let cachedPage = findCachedPage(matching: target) {
            self.showModalView(page: cachedPage, params: params, from: vc)
            return
        }
        
        // 2. 如果未命中本地缓存，向服务端请求对应页面
        log("🔄 正在从服务端获取弹窗 \(target)...")
        Task {
            do {
                guard let client = getClient(),
                      let projectKey = projectKeyField.text else { return }
                let page = try await client.fetchRuntimePage(projectKey: projectKey, pageName: target)
                await MainActor.run {
                    self.showModalView(page: page, params: params, from: vc)
                }
            } catch {
                await MainActor.run {
                    self.log("❌ 弹窗加载失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showModalView(page: DynamicPage, params: [String: DynamicValue]?, from vc: UIViewController?) {
        let config = PopUpConfig(from: params)
        let popUpView = DynamicPopUpView(
            page: page,
            width: config.width,
            height: config.height,
            topRadius: config.topRadius,
            bottomRadius: config.bottomRadius,
            networkProvider: MockDynamicNetworkProvider()
        ) { [weak self, weak vc] target, params in
            self?.handleNavigation(target: target, params: params, from: vc)
        }
        
        PopUpAssistant.shared.showCustomView(
            popUpView,
            position: config.position,
            useCover: config.useCover,
            canTouchCoverCloseSelf: config.canTouchCoverCloseSelf,
            tapSelfRemove: config.tapSelfRemove,
            bottomSpacing: config.bottomSpacing
        )
        self.log("✅ 弹窗显示成功: \(page.pageId ?? "")")
    }
    
    private func handleNativeNavigation(target: String, params: [String: DynamicValue]?, from vc: UIViewController?) {
        print("[Client] 收到原生路由跳转 - target: \(target)")
        switch target {
        case "NativeTest":
            self.navigationController?.pushViewController(
                NativeTestViewController(route: target, params: params),
                animated: true
            )
        default:
            self.log("没有注册原生路由：\(target)")
        }
    }
    
    private func findCachedPage(matching target: String) -> DynamicPage? {
        let normalizedTarget = normalize(target)
        
        // 1. 精确/模糊匹配 displayName 字段
        for (key, val) in packagePages {
            if normalize(key) == normalizedTarget {
                if let page = val as? DynamicPage { return page }
                if let rawPageDict = val as? [String: Any],
                   let data = try? JSONSerialization.data(withJSONObject: rawPageDict),
                   let page = try? DynamicSchemaValidator.decodePage(from: data) {
                    return page
                }
            }
        }
        
        // 2. 匹配内部编译生成的 pageId 字段
        for (_, val) in packagePages {
            var page: DynamicPage?
            if let p = val as? DynamicPage {
                page = p
            } else if let rawPageDict = val as? [String: Any],
                      let data = try? JSONSerialization.data(withJSONObject: rawPageDict),
                      let p = try? DynamicSchemaValidator.decodePage(from: data) {
                page = p
            }
            
            if let page = page,
               let pageId = page.pageId,
               normalize(pageId) == normalizedTarget {
                return page
            }
        }
        return nil
    }
    
    private func normalize(_ value: String) -> String {
        var result = value.lowercased()
        if let regex = try? NSRegularExpression(pattern: "(_?v\\d+.*)$", options: []) {
            let range = NSRange(location: 0, length: result.utf16.count)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }
        return result
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
    
    private func setupKeyboardTappedDismiss() {
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
}

// Swift utility
private extension UIButton {
    func then(_ block: (UIButton) -> Void) -> UIButton {
        block(self)
        return self
    }
}
