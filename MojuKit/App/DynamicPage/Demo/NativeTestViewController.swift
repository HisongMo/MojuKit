import UIKit

final class NativeTestViewController: UIViewController {
    private let route: String
    private let params: [String: DynamicValue]?

    init(route: String, params: [String: DynamicValue]?) {
        self.route = route
        self.params = params
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "原生测试页"
        view.backgroundColor = .systemBackground
        setupViews()
    }

    private func setupViews() {
        let iconView = UIImageView(image: UIImage(systemName: "iphone.gen3"))
        iconView.tintColor = .systemBlue
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "已跳转到原生页面"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let routeLabel = UILabel()
        routeLabel.text = "Route: \(route)"
        routeLabel.font = .systemFont(ofSize: 15, weight: .medium)
        routeLabel.textColor = .secondaryLabel
        routeLabel.textAlignment = .center
        routeLabel.translatesAutoresizingMaskIntoConstraints = false

        let paramsLabel = UILabel()
        paramsLabel.text = formattedParams()
        paramsLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        paramsLabel.textColor = .secondaryLabel
        paramsLabel.numberOfLines = 0
        paramsLabel.textAlignment = .left
        paramsLabel.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = UIButton(type: .system)
        closeButton.configuration = .filled()
        closeButton.configuration?.title = "返回动态页"
        closeButton.addAction(UIAction { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        }, for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        let stackView = UIStackView(arrangedSubviews: [iconView, titleLabel, routeLabel, paramsLabel, closeButton])
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 18
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            iconView.heightAnchor.constraint(equalToConstant: 64),
            closeButton.heightAnchor.constraint(equalToConstant: 46)
        ])
    }

    private func formattedParams() -> String {
        guard let params, !params.isEmpty else {
            return "Params: {}"
        }

        let body = params
            .sorted { $0.key < $1.key }
            .map { "  \($0.key): \($0.value.displayText)" }
            .joined(separator: "\n")
        return "Params:\n\(body)"
    }
}

private extension DynamicValue {
    var displayText: String {
        switch self {
        case .string(let value):
            return "\"\(value)\""
        case .int(let value):
            return "\(value)"
        case .double(let value):
            return "\(value)"
        case .bool(let value):
            return "\(value)"
        case .object(let value):
            let fields = value
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value.displayText)" }
                .joined(separator: ", ")
            return "{\(fields)}"
        case .array(let value):
            return "[\(value.map(\.displayText).joined(separator: ", "))]"
        case .null:
            return "null"
        }
    }
}
