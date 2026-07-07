import UIKit

public protocol MojuImageProviding {
    func image(named name: String) -> UIImage?
    func systemImage(named name: String) -> UIImage?
}

public final class DefaultMojuImageProvider: MojuImageProviding {
    public init() {}

    public func image(named name: String) -> UIImage? {
        UIImage(named: name)
    }

    public func systemImage(named name: String) -> UIImage? {
        UIImage(systemName: name)
    }
}
