import UIKit

final class DynamicStyleParser {
    func color(from hex: String?, default defaultColor: UIColor) -> UIColor {
        guard var hex else { return defaultColor }
        hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }

        let expanded: String
        switch hex.count {
        case 3:
            expanded = hex.map { "\($0)\($0)" }.joined() + "FF"
        case 4:
            expanded = hex.map { "\($0)\($0)" }.joined()
        case 6:
            expanded = hex + "FF"
        case 8:
            expanded = hex
        default:
            return defaultColor
        }

        guard let value = UInt64(expanded, radix: 16) else {
            return defaultColor
        }

        let red = CGFloat((value & 0xFF00_0000) >> 24) / 255
        let green = CGFloat((value & 0x00FF_0000) >> 16) / 255
        let blue = CGFloat((value & 0x0000_FF00) >> 8) / 255
        let alpha = CGFloat(value & 0x0000_00FF) / 255
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    func font(size: CGFloat?, weight: String?) -> UIFont {
        let fontSize = size ?? 15
        let fontWeight: UIFont.Weight

        switch weight?.lowercased() {
        case "medium":
            fontWeight = .medium
        case "semibold":
            fontWeight = .semibold
        case "bold":
            fontWeight = .bold
        default:
            fontWeight = .regular
        }

        return .systemFont(ofSize: fontSize, weight: fontWeight)
    }

    func textAlignment(from value: String?) -> NSTextAlignment {
        switch value?.lowercased() {
        case "center":
            return .center
        case "right":
            return .right
        case "natural":
            return .natural
        default:
            return .left
        }
    }

    func contentMode(from value: String?) -> UIView.ContentMode {
        switch value?.lowercased() {
        case "aspectfit":
            return .scaleAspectFit
        case "scaletofill":
            return .scaleToFill
        case "center":
            return .center
        default:
            return .scaleAspectFill
        }
    }

    func stackAlignment(from value: String?) -> UIStackView.Alignment {
        switch value?.lowercased() {
        case "center":
            return .center
        case "leading", "left":
            return .leading
        case "trailing", "right":
            return .trailing
        case "firstbaseline":
            return .firstBaseline
        case "lastbaseline":
            return .lastBaseline
        default:
            return .fill
        }
    }

    func stackDistribution(from value: String?) -> UIStackView.Distribution {
        switch value?.lowercased() {
        case "fillEqually":
            return .fillEqually
        case "fillProportionally":
            return .fillProportionally
        case "equalSpacing":
            return .equalSpacing
        case "equalCentering":
            return .equalCentering
        default:
            return .fill
        }
    }
}
