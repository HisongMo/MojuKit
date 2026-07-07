import Foundation

@MainActor
final class MojuTemplateResolver {
    private let dataStore: MojuDataStore

    init(dataStore: MojuDataStore) {
        self.dataStore = dataStore
    }

    func resolveString(_ template: String) -> String {
        var result = template
        let pattern = "\\{\\{\\s*([^}]+?)\\s*\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return template
        }

        let nsRange = NSRange(template.startIndex..<template.endIndex, in: template)
        let matches = regex.matches(in: template, range: nsRange).reversed()

        for match in matches {
            guard
                let fullRange = Range(match.range(at: 0), in: template),
                let keyRange = Range(match.range(at: 1), in: template)
            else {
                continue
            }

            let keyPath = template[keyRange].trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedValue: Any?
            if keyPath.contains("+") || keyPath.contains("-") || keyPath.contains("*") || keyPath.contains("/") {
                resolvedValue = evaluateExpression(keyPath)
            } else {
                resolvedValue = dataStore.value(forKeyPath: keyPath)
            }
            let replacement = string(from: resolvedValue)
            result.replaceSubrange(fullRange, with: replacement)
        }

        return result
    }

    private func evaluateExpression(_ expressionString: String) -> Any? {
        let pattern = "[a-zA-Z_][a-zA-Z0-9_.]*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        
        var resolvedString = expressionString
        let nsRange = NSRange(expressionString.startIndex..<expressionString.endIndex, in: expressionString)
        let matches = regex.matches(in: expressionString, range: nsRange).reversed()
        
        for match in matches {
            guard let range = Range(match.range(at: 0), in: resolvedString) else { continue }
            let varName = String(resolvedString[range])
            
            if let val = dataStore.value(forKeyPath: varName) {
                let valStr: String
                if let d = val as? Double {
                    valStr = String(d)
                } else if let i = val as? Int {
                    valStr = String(i)
                } else if let f = val as? Float {
                    valStr = String(f)
                } else {
                    valStr = "\(val)"
                }
                resolvedString.replaceSubrange(range, with: valStr)
            }
        }
        
        let cleanExpression = resolvedString.trimmingCharacters(in: .whitespacesAndNewlines)
        let expr = NSExpression(format: cleanExpression)
        return expr.expressionValue(with: nil, context: nil)
    }

    func resolveValue(_ value: MojuValue) -> MojuValue {
        switch value {
        case .string(let string):
            return .string(resolveString(string))
        case .object(let object):
            return .object(object.mapValues { resolveValue($0) })
        case .array(let array):
            return .array(array.map { resolveValue($0) })
        default:
            return value
        }
    }

    func resolveParams(_ params: [String: MojuValue]) -> [String: MojuValue] {
        params.mapValues { resolveValue($0) }
    }

    private func string(from value: Any?) -> String {
        switch value {
        case nil, is NSNull:
            return ""
        case let value as String:
            return value
        case let value as Int:
            return String(value)
        case let value as Double:
            return String(value)
        case let value as Float:
            return String(value)
        case let value as Bool:
            return String(value)
        case let value as MojuValue:
            return value.stringValue ?? ""
        default:
            return ""
        }
    }
}
