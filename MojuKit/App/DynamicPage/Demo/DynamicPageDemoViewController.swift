import UIKit
import UniformTypeIdentifiers

final class DynamicPageDemoViewController: UIViewController, UIDocumentPickerDelegate {
    private let stackView = UIStackView()
    private let descriptionLabel = UILabel()
    private let basicDemoButton = UIButton(type: .system)
    private let allComponentsButton = UIButton(type: .system)
    private let etcDemoButton = UIButton(type: .system)
    private let navigationDemoButton = UIButton(type: .system)
    private let studioPreviewButton = UIButton(type: .system)
    private let remoteRetrieveButton = UIButton(type: .system)
    private let uploadButton = UIButton(type: .system)
    private let popupTestButton = UIButton(type: .system)
    private let popupBottomTestButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Dynamic Page Demo"
        view.backgroundColor = .systemBackground
        setupViews()
    }

    private func setupViews() {
        stackView.axis = .vertical
        stackView.spacing = 14
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false

        descriptionLabel.text = "选择内置示例，或上传一个 JSON 文件测试页面渲染。"
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.font = .systemFont(ofSize: 15)
        descriptionLabel.numberOfLines = 0

        configure(
            basicDemoButton,
            title: "基础 JSON 示例",
            color: .systemBlue,
            action: #selector(openBasicDemo)
        )
        configure(
            allComponentsButton,
            title: "全组件能力示例",
            color: .systemIndigo,
            action: #selector(openAllComponentsDemo)
        )
        configure(
            etcDemoButton,
            title: "ETC 绑定复杂页示例",
            color: .systemTeal,
            action: #selector(openETCDemo)
        )
        configure(
            navigationDemoButton,
            title: "多页面跳转示例",
            color: .systemOrange,
            action: #selector(openNavigationDemo)
        )
        configure(
            studioPreviewButton,
            title: "连接 Studio 预览",
            color: .systemPurple,
            action: #selector(openStudioPreview)
        )
        configure(
            remoteRetrieveButton,
            title: "远程获取接口测试",
            color: .systemPink,
            action: #selector(openRemoteRetrieve)
        )

        uploadButton.configuration = makeButtonConfiguration(title: "上传 JSON 文件", color: .systemGreen)
        uploadButton.translatesAutoresizingMaskIntoConstraints = false
        uploadButton.addTarget(self, action: #selector(uploadJSONFile), for: .touchUpInside)

        configure(
            popupTestButton,
            title: "居中弹窗测试",
            color: .systemRed,
            action: #selector(openPopupTest)
        )
        configure(
            popupBottomTestButton,
            title: "底部弹窗测试",
            color: .orange,
            action: #selector(openPopupBottomTest)
        )

        statusLabel.textColor = .secondaryLabel
        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center

        view.addSubview(stackView)
        stackView.addArrangedSubview(descriptionLabel)
        stackView.addArrangedSubview(basicDemoButton)
        stackView.addArrangedSubview(allComponentsButton)
        stackView.addArrangedSubview(etcDemoButton)
        stackView.addArrangedSubview(navigationDemoButton)
        stackView.addArrangedSubview(studioPreviewButton)
        stackView.addArrangedSubview(remoteRetrieveButton)
        stackView.addArrangedSubview(uploadButton)
        stackView.addArrangedSubview(popupTestButton)
        stackView.addArrangedSubview(popupBottomTestButton)
        stackView.addArrangedSubview(statusLabel)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            basicDemoButton.heightAnchor.constraint(equalToConstant: 48),
            allComponentsButton.heightAnchor.constraint(equalToConstant: 48),
            etcDemoButton.heightAnchor.constraint(equalToConstant: 48),
            navigationDemoButton.heightAnchor.constraint(equalToConstant: 48),
            studioPreviewButton.heightAnchor.constraint(equalToConstant: 48),
            remoteRetrieveButton.heightAnchor.constraint(equalToConstant: 48),
            uploadButton.heightAnchor.constraint(equalToConstant: 48),
            popupTestButton.heightAnchor.constraint(equalToConstant: 48),
            popupBottomTestButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func configure(_ button: UIButton, title: String, color: UIColor, action: Selector) {
        button.configuration = makeButtonConfiguration(title: title, color: color)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func makeButtonConfiguration(title: String, color: UIColor) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = color
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .medium
        return configuration
    }

    @objc private func openBasicDemo() {
        openBundledDynamicPage(named: "DynamicPageDemo")
    }

    @objc private func openAllComponentsDemo() {
        openBundledDynamicPage(named: "DynamicPageAllComponentsDemo")
    }

    @objc private func openETCDemo() {
        openBundledDynamicPage(named: "DynamicPageETCBindingDemo")
    }

    @objc private func openNavigationDemo() {
        openBundledDynamicPage(named: "DynamicPageNavigationListDemo")
    }

    @objc private func openStudioPreview() {
        navigationController?.pushViewController(DynamicPagePreviewHostViewController(), animated: true)
    }

    @objc private func openRemoteRetrieve() {
        navigationController?.pushViewController(DynamicPageRemoteRetrieveViewController(), animated: true)
    }

    private func openBundledDynamicPage(named resourceName: String) {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            showStatus("没有找到内置 \(resourceName).json")
            return
        }

        openDynamicPage(from: url)
    }

    @objc private func uploadJSONFile() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        openDynamicPage(from: url)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        showStatus("已取消上传")
    }

    private func openDynamicPage(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            guard data.count <= DynamicPageLimits.maxJSONSize else {
                showStatus("JSON 文件超过 1 MB，已拒绝加载")
                return
            }

            let page = try DynamicSchemaValidator.decodePage(from: data)
            showStatus("JSON 加载成功：\(url.lastPathComponent)")
            navigationController?.pushViewController(makeDynamicPageViewController(page: page), animated: true)
        } catch {
            showStatus("JSON 解析失败，请检查 schemaVersion、components 和字段类型")
            print("Dynamic page decode failed:", error)
        }
    }

    private func makeDynamicPageViewController(page: DynamicPage) -> DynamicPageViewController {
        let viewController = DynamicPageViewController(page: page, networkProvider: MockDynamicNetworkProvider())
        viewController.onNavigate = { [weak self, weak viewController] target, params in
            print("Navigate:", target, params ?? [:])
            self?.handleNavigation(target: target, params: params, from: viewController)
        }
        viewController.onNativeNavigate = { [weak self, weak viewController] target, params in
            print("NativeNavigate:", target, params ?? [:])
            self?.handleNativeNavigation(target: target, params: params, from: viewController)
        }
        viewController.onShowModal = { [weak self, weak viewController] target, params in
            print("ShowModal:", target, params ?? [:])
            self?.handleShowModal(target: target, params: params, from: viewController)
        }
        viewController.onTrackEvent = { eventName, params in
            print("Track:", eventName, params ?? [:])
        }
        viewController.onConfirmHighRiskRequest = { _, _, completion in
            completion(true)
        }
        return viewController
    }

    private func handleNavigation(
        target: String,
        params: [String: DynamicValue]?,
        from viewController: UIViewController?
    ) {
        switch target {
        case "navigationDetail":
            guard let page = loadBundledPage(named: "DynamicPageNavigationDetailDemo", params: params) else {
                showStatus("没有找到详情页 JSON")
                return
            }
            viewController?.navigationController?.pushViewController(
                makeDynamicPageViewController(page: page),
                animated: true
            )

        case "back":
            viewController?.navigationController?.popViewController(animated: true)

        default:
            break
        }
    }

    private func handleShowModal(
        target: String,
        params: [String: DynamicValue]?,
        from viewController: UIViewController?
    ) {
        guard let page = loadBundledPage(named: target, params: params) else {
            showStatus("没有找到弹窗页 \(target).json")
            return
        }
        
        let config = PopUpConfig(from: params)
        
        let popUpView = DynamicPopUpView(
            page: page,
            width: config.width,
            height: config.height,
            topRadius: config.topRadius,
            bottomRadius: config.bottomRadius,
            networkProvider: MockDynamicNetworkProvider()
        ) { [weak self] target, params in
            self?.handleNavigation(target: target, params: params, from: viewController)
        }
        
        PopUpAssistant.shared.showCustomView(
            popUpView,
            position: config.position,
            useCover: config.useCover,
            canTouchCoverCloseSelf: config.canTouchCoverCloseSelf,
            tapSelfRemove: config.tapSelfRemove,
            bottomSpacing: config.bottomSpacing
        )
    }

    private func handleNativeNavigation(
        target: String,
        params: [String: DynamicValue]?,
        from viewController: UIViewController?
    ) {
        switch target {
        case "NativeTest":
            viewController?.navigationController?.pushViewController(
                NativeTestViewController(route: target, params: params),
                animated: true
            )

        default:
            showStatus("没有注册原生路由：\(target)")
        }
    }

    private func loadBundledPage(named resourceName: String, params: [String: DynamicValue]? = nil) -> DynamicPage? {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let page = try DynamicSchemaValidator.decodePage(from: data)
            guard let params else { return page }
            return page.mergingPageParams(params)
        } catch {
            print("Dynamic page decode failed:", error)
            return nil
        }
    }

    private func showStatus(_ message: String) {
        statusLabel.text = message
    }
}

private extension DynamicPage {
    func mergingPageParams(_ params: [String: DynamicValue]) -> DynamicPage {
        var mergedParams = pageParams ?? [:]
        params.forEach { key, value in
            mergedParams[key] = value
        }

        return DynamicPage(
            schemaVersion: schemaVersion,
            pageId: pageId,
            pageTitle: pageTitle,
            backgroundColor: backgroundColor,
            pageParams: mergedParams,
            onLoad: onLoad,
            components: components,
            fixedBottomComponents: fixedBottomComponents
        )
    }
}

// MARK: - PopUp Tests
extension DynamicPageDemoViewController {
    @objc private func openPopupTest() {
        let testView = TestPopUpView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        PopUpAssistant.shared.showCustomView(testView, position: .center, useCover: true)
    }

    @objc private func openPopupBottomTest() {
        let testView = TestPopUpView(frame: CGRect(x: 0, y: 0, width: UIConfigure.Width - 20, height: 500))
        PopUpAssistant.shared.showCustomView(testView, position: .bottom, useCover: true, bottomSpacing: 10)
    }
}

class TestPopUpView: PopUpBaseView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .systemBackground
        
        let titleLabel = UILabel()
        titleLabel.text = "🎉 弹窗测试成功！"
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let contentLabel = UILabel()
        contentLabel.text = "这是一个通过 PopUpAssistant 弹出的自定义视图。\n支持遮罩层、下滑关闭手势与回弹动画。"
        contentLabel.font = .systemFont(ofSize: 14)
        contentLabel.textColor = .secondaryLabel
        contentLabel.numberOfLines = 0
        contentLabel.textAlignment = .center
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("我知道了", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        closeButton.configuration = .filled()
        closeButton.addTarget(self, action: #selector(closeAction), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        self.addSubview(titleLabel)
        self.addSubview(contentLabel)
        self.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -20),
            
            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            contentLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 20),
            contentLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -20),
            
            closeButton.topAnchor.constraint(equalTo: contentLabel.bottomAnchor, constant: 20),
            closeButton.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -20),
            closeButton.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -24),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc override func closeAction() {
        super.closeAction() // Executes closeBlock
        self.popDelegate?.didClosePopView() // Closes PopUpCustomView / Window
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let path = UIBezierPath()
        let width = bounds.width
        let height = bounds.height
        let tr: CGFloat = 16
        let tl: CGFloat = 16
        let br = UIScreen.main.realCornerRadius
        let bl = UIScreen.main.realCornerRadius
        
        path.move(to: CGPoint(x: tl, y: 0))
        path.addLine(to: CGPoint(x: width - tr, y: 0))
        path.addArc(withCenter: CGPoint(x: width - tr, y: tr), radius: tr, startAngle: CGFloat(3 * Double.pi / 2), endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: width, y: height - br))
        path.addArc(withCenter: CGPoint(x: width - br, y: height - br), radius: br, startAngle: 0, endAngle: CGFloat(Double.pi / 2), clockwise: true)
        path.addLine(to: CGPoint(x: bl, y: height))
        path.addArc(withCenter: CGPoint(x: bl, y: height - bl), radius: bl, startAngle: CGFloat(Double.pi / 2), endAngle: CGFloat(Double.pi), clockwise: true)
        path.addLine(to: CGPoint(x: 0, y: tl))
        path.addArc(withCenter: CGPoint(x: tl, y: tl), radius: tl, startAngle: CGFloat(Double.pi), endAngle: CGFloat(3 * Double.pi / 2), clockwise: true)
        path.close()
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        self.layer.mask = maskLayer
    }
}
