import UIKit

@MainActor
final class MojuDataStore {
    private var storage: [String: Any] = [:]

    init(pageParams: [String: MojuValue]? = nil, user: [String: MojuValue]? = nil) {
        if let pageParams {
            storage["pageParams"] = pageParams.mapValues { $0.anyValue }
        }
        if let user {
            storage["user"] = user.mapValues { $0.anyValue }
        }
        
        // Add UIConfigure properties so they are accessible via templates like {{UIConfigure.width}}
        let screenBounds = UIScreen.main.bounds
        let statusBarHeight = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.statusBarManager?.statusBarFrame.height }
            .first ?? 0
        storage["UIConfigure"] = [
            "width": screenBounds.width,
            "height": screenBounds.height,
            "sizeScale": screenBounds.width / 375.0,
            "statusBarHeight": statusBarHeight,
            "realCornerRadius": 0
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
            } else if let dictionary = current as? [String: MojuValue] {
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
        if let dynamicValue = value as? MojuValue {
            return dynamicValue.anyValue
        }
        if let dictionary = value as? [String: MojuValue] {
            return dictionary.mapValues { $0.anyValue }
        }
        if let array = value as? [MojuValue] {
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
