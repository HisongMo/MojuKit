import UIKit

final class DynamicPagePreviewHostViewController: UIViewController {
    private let client: DynamicPagePreviewClient
    private let statusLabel = UILabel()
    private let containerView = UIView()
    private var pollTask: Task<Void, Never>?
    private var currentRevision = -1
    private var currentPageViewController: DynamicPageViewController?
    private var navigationDepth = 0

    init(client: DynamicPagePreviewClient = DynamicPagePreviewClient()) {
        self.client = client
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "预览"
        view.backgroundColor = .systemBackground
        setupViews()
        startPolling()
    }

    deinit {
        pollTask?.cancel()
    }

    private func setupViews() {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.text = ""
        statusLabel.textAlignment = .center
        statusLabel.textColor = .secondaryLabel
        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true

        view.addSubview(statusLabel)
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func startPolling() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshIfNeeded()
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
        }
    }

    @MainActor
    private func refreshIfNeeded() async {
        do {
            let revision = try await client.fetchRevision()
            guard revision != currentRevision else { return }

            let snapshot = try await client.fetchActivePage(revision: revision)
            currentRevision = snapshot.revision
            statusLabel.isHidden = true
            navigationController?.popToViewController(self, animated: false)
            navigationDepth = 0
            render(page: snapshot.page, replacingCurrent: true)
        } catch {
            if currentPageViewController == nil {
                title = "预览"
                statusLabel.text = "无法加载预览页面：请确认 VS Code 插件或 macOS Studio 已启动预览服务\n\(error.localizedDescription)"
                statusLabel.isHidden = false
            }
        }
    }

    @MainActor
    private func render(page: DynamicPage, replacingCurrent: Bool) {
        guard replacingCurrent else {
            let pageViewController = makePageViewController(page: page)
            navigationDepth += 1
            navigationController?.pushViewController(pageViewController, animated: true)
            return
        }

        currentPageViewController?.willMove(toParent: nil)
        currentPageViewController?.view.removeFromSuperview()
        currentPageViewController?.removeFromParent()

        let pageViewController = makePageViewController(page: page)
        addChild(pageViewController)
        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(pageViewController.view)
        NSLayoutConstraint.activate([
            pageViewController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            pageViewController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        pageViewController.didMove(toParent: self)
        currentPageViewController = pageViewController
        mirrorNavigationItem(from: pageViewController, fallbackTitle: page.pageTitle)
    }

    private func makePageViewController(page: DynamicPage) -> DynamicPageViewController {
        let pageViewController = DynamicPageViewController(page: page, networkProvider: MockDynamicNetworkProvider())
        pageViewController.onNavigate = { [weak self] target, params in
            self?.handleNavigation(target: target, params: params)
        }
        pageViewController.onNativeNavigate = { [weak self] target, params in
            self?.handleNativeNavigation(target: target, params: params)
        }
        pageViewController.onShowModal = { [weak self] target, params in
            self?.handleShowModal(target: target, params: params)
        }
        pageViewController.onTrackEvent = { eventName, params in
            print("Preview track:", eventName, params ?? [:])
        }
        pageViewController.onConfirmHighRiskRequest = { _, _, completion in
            completion(true)
        }
        return pageViewController
    }

    private func mirrorNavigationItem(from pageViewController: DynamicPageViewController, fallbackTitle: String?) {
        title = pageViewController.title ?? fallbackTitle
        navigationItem.hidesBackButton = pageViewController.navigationItem.hidesBackButton
        navigationItem.leftBarButtonItem = pageViewController.navigationItem.leftBarButtonItem
        navigationItem.leftBarButtonItems = pageViewController.navigationItem.leftBarButtonItems
        navigationItem.rightBarButtonItem = pageViewController.navigationItem.rightBarButtonItem
        navigationItem.rightBarButtonItems = pageViewController.navigationItem.rightBarButtonItems
    }

    private func handleShowModal(target: String, params: [String: DynamicValue]?) {
        Task { [weak self] in
            do {
                guard let self else { return }
                let page = try await self.client.fetchPage(target: target).mergingPageParams(params)
                await MainActor.run {
                    let config = PopUpConfig(from: params)
                    
                    let popUpView = DynamicPopUpView(
                        page: page,
                        width: config.width,
                        height: config.height,
                        topRadius: config.topRadius,
                        bottomRadius: config.bottomRadius,
                        bounces: config.bounces,
                        networkProvider: MockDynamicNetworkProvider()
                    ) { [weak self] target, params in
                        self?.handleNavigation(target: target, params: params)
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
            } catch {
                print("Failed to fetch modal page:", target)
            }
        }
    }

    private func handleNavigation(target: String, params: [String: DynamicValue]?) {
        print("Preview navigate:", target, params ?? [:])
        if target == "back" {
            navigationController?.popViewController(animated: true)
            navigationDepth = max(0, navigationDepth - 1)
            return
        }

        Task { [weak self] in
            do {
                guard let self else { return }
                let page = try await client.fetchPage(target: target).mergingPageParams(params)
                await MainActor.run {
                    self.statusLabel.isHidden = true
                    self.render(page: page, replacingCurrent: false)
                }
            } catch {
                await MainActor.run {
                    self?.statusLabel.text = "没有找到跳转目标：\(target)"
                    self?.statusLabel.isHidden = false
                }
            }
        }
    }

    private func handleNativeNavigation(target: String, params: [String: DynamicValue]?) {
        print("Preview native navigate:", target, params ?? [:])
        switch target {
        case "NativeTest":
            navigationController?.pushViewController(
                NativeTestViewController(route: target, params: params),
                animated: true
            )

        default:
            statusLabel.text = "没有注册原生路由：\(target)"
            statusLabel.isHidden = false
        }
    }
}

private extension DynamicPage {
    func mergingPageParams(_ params: [String: DynamicValue]?) -> DynamicPage {
        guard let params else { return self }
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
            fixedBottomComponents: fixedBottomComponents,
            navigationBar: navigationBar
        )
    }
}
