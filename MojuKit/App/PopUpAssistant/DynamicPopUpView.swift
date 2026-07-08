import UIKit

class DynamicPopUpView: PopUpBaseView {
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    
    private var dataStore: DynamicDataStore!
    private var requestExecutor: DynamicRequestExecutor!
    private var actionHandler: DynamicActionHandler!
    private var renderer: DynamicPageRenderer!
    
    private var topRadius: CGFloat = 16
    private var bottomRadius: CGFloat = UIScreen.main.realCornerRadius
    
    init(
        page: DynamicPage,
        width: CGFloat,
        height: CGFloat,
        topRadius: CGFloat = 16,
        bottomRadius: CGFloat = UIScreen.main.realCornerRadius,
        bounces: Bool = false,
        networkProvider: DynamicNetworkProviding,
        onNavigate: ((_ target: String, _ params: [String: DynamicValue]?) -> Void)? = nil
    ) {
        self.topRadius = topRadius
        self.bottomRadius = bottomRadius
        super.init(frame: CGRect(x: 0, y: 0, width: width, height: height))
        
        self.backgroundColor = .systemBackground
        
        // 1. Setup ScrollView and StackView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.bounces = bounces
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .fill
        
        self.addSubview(scrollView)
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: self.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        // 2. Setup dynamic rendering context
        dataStore = DynamicDataStore(pageParams: page.pageParams)
        requestExecutor = DynamicRequestExecutor(networkProvider: networkProvider, dataStore: dataStore)
        actionHandler = DynamicActionHandler(dataStore: dataStore, requestExecutor: requestExecutor)
        
        actionHandler.onNavigate = { [weak self] target, params in
            if target == "back" || target == "close" {
                self?.popDelegate?.didClosePopView()
            } else {
                self?.popDelegate?.didClosePopView()
                onNavigate?(target, params)
            }
        }
        
        actionHandler.onStateChanged = { [weak self] in
            self?.renderer.render()
        }
        
        requestExecutor.onRequestFinished = { [weak self] in
            self?.renderer.render()
        }
        
        renderer = DynamicPageRenderer(
            page: page,
            stackView: stackView,
            dataStore: dataStore,
            actionHandler: actionHandler
        )
        
        // 3. Render the page
        renderer.render()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let path = UIBezierPath()
        let width = bounds.width
        let height = bounds.height
        let tr = topRadius
        let tl = topRadius
        let br = bottomRadius
        let bl = bottomRadius
        
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

// MARK: - PopUp Configuration Parsing
struct PopUpConfig {
    var position: PopUpAlertPosition = .bottom
    var useCover: Bool = true
    var canTouchCoverCloseSelf: Bool = true
    var tapSelfRemove: Bool = false
    var bottomSpacing: CGFloat? = nil
    var width: CGFloat = UIConfigure.Width
    var height: CGFloat = 500
    var topRadius: CGFloat = 16
    var bottomRadius: CGFloat = UIScreen.main.realCornerRadius
    var bounces: Bool = false
    
    init(from params: [String: DynamicValue]?) {
        guard let params = params else { return }
        
        if let posVal = params["modal_position"]?.stringValue {
            switch posVal.lowercased() {
            case "center": position = .center
            case "top": position = .top
            default: position = .bottom
            }
        }
        if let useCoverVal = params["modal_useCover"]?.anyValue {
            if let b = useCoverVal as? Bool {
                useCover = b
            } else if let s = useCoverVal as? String {
                useCover = (s.lowercased() == "true")
            }
        }
        if let canCloseVal = params["modal_canTouchCoverCloseSelf"]?.anyValue {
            if let b = canCloseVal as? Bool {
                canTouchCoverCloseSelf = b
            } else if let s = canCloseVal as? String {
                canTouchCoverCloseSelf = (s.lowercased() == "true")
            }
        }
        if let tapVal = params["modal_tapSelfRemove"]?.anyValue {
            if let b = tapVal as? Bool {
                tapSelfRemove = b
            } else if let s = tapVal as? String {
                tapSelfRemove = (s.lowercased() == "true")
            }
        }
        if let spacingVal = params["modal_bottomSpacing"]?.anyValue {
            if let d = spacingVal as? Double {
                bottomSpacing = CGFloat(d)
            } else if let i = spacingVal as? Int {
                bottomSpacing = CGFloat(i)
            } else if let s = spacingVal as? String, let d = Double(s) {
                bottomSpacing = CGFloat(d)
            }
        }
        if let widthVal = params["modal_width"]?.anyValue {
            if let parsedWidth = Self.dimensionValue(from: widthVal, base: UIConfigure.Width) {
                width = parsedWidth
            }
        }
        if let heightVal = params["modal_height"]?.anyValue {
            if let parsedHeight = Self.dimensionValue(from: heightVal, base: UIConfigure.Height) {
                height = parsedHeight
            }
        }
        if let trVal = params["modal_topRadius"]?.anyValue {
            if let d = trVal as? Double {
                topRadius = CGFloat(d)
            } else if let i = trVal as? Int {
                topRadius = CGFloat(i)
            } else if let s = trVal as? String, let d = Double(s) {
                topRadius = CGFloat(d)
            }
        }
        if let brVal = params["modal_bottomRadius"] {
            if let rawRadius = brVal.stringValue,
               Self.isRealCornerRadiusExpression(rawRadius) {
                bottomRadius = UIScreen.main.realCornerRadius
            } else if let brDouble = brVal.anyValue as? Double {
                bottomRadius = CGFloat(brDouble)
            } else if let brInt = brVal.anyValue as? Int {
                bottomRadius = CGFloat(brInt)
            } else if let s = brVal.anyValue as? String {
                if Self.isRealCornerRadiusExpression(s) {
                    bottomRadius = UIScreen.main.realCornerRadius
                } else if let parsedRadius = Self.dimensionValue(from: s, base: UIScreen.main.realCornerRadius) {
                    bottomRadius = parsedRadius
                }
            }
        }
        if let bouncesVal = params["modal_bounces"]?.anyValue {
            if let b = bouncesVal as? Bool {
                bounces = b
            } else if let s = bouncesVal as? String {
                bounces = (s.lowercased() == "true")
            }
        }
    }

    private static func dimensionValue(from rawValue: Any, base: CGFloat) -> CGFloat? {
        if let doubleValue = rawValue as? Double {
            return CGFloat(doubleValue)
        }
        if let intValue = rawValue as? Int {
            return CGFloat(intValue)
        }
        guard let stringValue = rawValue as? String else { return nil }

        let expression = normalizedExpression(stringValue)
        if let number = Double(expression) {
            return CGFloat(number)
        }
        return evaluateDimensionExpression(expression, base: base)
    }

    private static func normalizedExpression(_ value: String) -> String {
        var expression = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if expression.hasPrefix("{{"), expression.hasSuffix("}}") {
            expression = String(expression.dropFirst(2).dropLast(2))
        }
        if expression.lowercased().hasPrefix("calc("), expression.hasSuffix(")") {
            expression = String(expression.dropFirst(5).dropLast())
        }
        return expression.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isRealCornerRadiusExpression(_ value: String) -> Bool {
        let expression = normalizedExpression(value)
        return expression == "realCornerRadius" || expression == "UIConfigure.realCornerRadius"
    }

    private static func evaluateDimensionExpression(_ expression: String, base: CGFloat) -> CGFloat? {
        let compact = expression
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "UIConfigure.width", with: "screenWidth")
            .replacingOccurrences(of: "UIConfigure.Width", with: "screenWidth")
            .replacingOccurrences(of: "UIConfigure.height", with: "screenHeight")
            .replacingOccurrences(of: "UIConfigure.Height", with: "screenHeight")
            .replacingOccurrences(of: "100vw", with: "screenWidth")
            .replacingOccurrences(of: "100vh", with: "screenHeight")

        guard compact.hasPrefix("screenWidth") || compact.hasPrefix("screenHeight") else {
            return nil
        }

        let remainder: String
        if compact.hasPrefix("screenWidth") {
            remainder = String(compact.dropFirst("screenWidth".count))
        } else {
            remainder = String(compact.dropFirst("screenHeight".count))
        }

        guard !remainder.isEmpty else { return base }
        let operation = remainder.prefix(1)
        let operandString = String(remainder.dropFirst())
        guard let operand = Double(operandString) else { return nil }
        let value = CGFloat(operand)

        switch operation {
        case "+": return base + value
        case "-": return base - value
        case "*": return base * value
        case "/": return value == 0 ? nil : base / value
        default: return nil
        }
    }
}
