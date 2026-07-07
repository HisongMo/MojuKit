import Foundation

@MainActor
final class DynamicTemplateResolver {
    private let dataStore: DynamicDataStore
    private let locals: [String: DynamicValue]

    init(dataStore: DynamicDataStore, locals: [String: DynamicValue] = [:]) {
        self.dataStore = dataStore
        self.locals = locals
    }

    func withLocalValues(_ newLocals: [String: DynamicValue]) -> DynamicTemplateResolver {
        var merged = locals
        for (k, v) in newLocals {
            merged[k] = v
        }
        return DynamicTemplateResolver(dataStore: dataStore, locals: merged)
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
                resolvedValue = value(forKeyPath: keyPath)
            }
            let replacement = string(from: resolvedValue)
            result.replaceSubrange(fullRange, with: replacement)
        }

        return result
    }

    func resolveArray(_ expression: String?) -> [DynamicValue] {
        guard let expression else { return [] }
        let keyPath = unwrappedTemplateExpression(expression)
        switch value(forKeyPath: keyPath) {
        case let value as DynamicValue:
            if case .array(let array) = value { return array }
            return []
        case let array as [DynamicValue]:
            return array
        case let array as [Any]:
            return array.map(DynamicValue.fromAny)
        default:
            return []
        }
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
            
            if let val = value(forKeyPath: varName) {
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

    func resolveValue(_ value: DynamicValue) -> DynamicValue {
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

    func resolveParams(_ params: [String: DynamicValue]) -> [String: DynamicValue] {
        params.mapValues { resolveValue($0) }
    }

    private func value(forKeyPath keyPath: String) -> Any? {
        let parts = keyPath
            .split(separator: ".")
            .map(String.init)
            .filter { !$0.isEmpty }
        guard let first = parts.first else { return nil }

        if let localValue = locals[first] {
            return value(localValue, at: Array(parts.dropFirst()))
        }

        return dataStore.value(forKeyPath: keyPath)
    }

    private func value(_ value: DynamicValue, at path: [String]) -> Any? {
        guard let head = path.first else { return value.anyValue }
        switch value {
        case .object(let object):
            guard let next = object[head] else { return nil }
            return self.value(next, at: Array(path.dropFirst()))
        case .array(let array):
            guard let index = Int(head), array.indices.contains(index) else { return nil }
            return self.value(array[index], at: Array(path.dropFirst()))
        default:
            return nil
        }
    }

    private func unwrappedTemplateExpression(_ expression: String) -> String {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{{"), trimmed.hasSuffix("}}") else { return trimmed }
        return trimmed
            .dropFirst(2)
            .dropLast(2)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
        case let value as DynamicValue:
            return value.stringValue ?? ""
        default:
            return ""
        }
    }
}
