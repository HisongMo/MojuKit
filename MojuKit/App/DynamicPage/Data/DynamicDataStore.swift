import UIKit

@MainActor
final class DynamicDataStore {
    private var storage: [String: Any] = [:]

    init(pageParams: [String: DynamicValue]? = nil, user: [String: DynamicValue]? = nil) {
        if let pageParams {
            storage["pageParams"] = pageParams.mapValues { $0.anyValue }
        }
        if let user {
            storage["user"] = user.mapValues { $0.anyValue }
        }
        
        // Add UIConfigure properties so they are accessible via templates like {{UIConfigure.width}}
        storage["UIConfigure"] = [
            "width": UIConfigure.Width,
            "height": UIConfigure.Height,
            "sizeScale": UIConfigure.SizeScale,
            "statusBarHeight": UIConfigure.KStatusBarHeight,
            "realCornerRadius": UIScreen.main.realCornerRadius
        ]
    }

    func set(_ value: Any, forKey key: String) {
        let normalizedValue = normalize(value)
        let parts = key.split(separator: ".").map(String.init)
        guard parts.count > 1, let first = parts.first else {
            storage[key] = normalizedValue
            return
        }

        var dictionary = storage[first] as? [String: Any] ?? [:]
        set(normalizedValue, in: &dictionary, path: Array(parts.dropFirst()))
        storage[first] = dictionary
    }

    func value(forKey key: String) -> Any? {
        storage[key]
    }

    func value(forKeyPath keyPath: String) -> Any? {
        let parts = keyPath.split(separator: ".").map(String.init)
        guard let first = parts.first else { return nil }
        var current: Any? = storage[first]

        for key in parts.dropFirst() {
            if let dictionary = current as? [String: Any] {
                current = dictionary[key]
            } else if let dictionary = current as? [String: DynamicValue] {
                current = dictionary[key]?.anyValue
            } else {
                return nil
            }
        }

        return current
    }

    func removeValue(forKey key: String) {
        storage.removeValue(forKey: key)
    }

    func removeAll() {
        storage.removeAll()
    }

    private func normalize(_ value: Any) -> Any {
        if let dynamicValue = value as? DynamicValue {
            return dynamicValue.anyValue
        }
        if let dictionary = value as? [String: DynamicValue] {
            return dictionary.mapValues { $0.anyValue }
        }
        if let array = value as? [DynamicValue] {
            return array.map { $0.anyValue }
        }
        return value
    }

    private func set(_ value: Any, in dictionary: inout [String: Any], path: [String]) {
        guard let key = path.first else { return }

        if path.count == 1 {
            dictionary[key] = value
            return
        }

        var child = dictionary[key] as? [String: Any] ?? [:]
        set(value, in: &child, path: Array(path.dropFirst()))
        dictionary[key] = child
    }
}
