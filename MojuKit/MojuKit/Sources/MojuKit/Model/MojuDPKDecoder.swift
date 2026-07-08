import CryptoKit
import Foundation

public struct MojuDPKManifest: Codable, Equatable {
    public struct Page: Codable, Equatable {
        public let name: String
        public let pageId: String?

        public init(name: String, pageId: String? = nil) {
            self.name = name
            self.pageId = pageId
        }
    }

    public let name: String
    public let generatedAt: String
    public let sourceProject: String?
    public let activePage: String?
    public let pages: [Page]

    public init(
        name: String,
        generatedAt: String,
        sourceProject: String? = nil,
        activePage: String? = nil,
        pages: [Page]
    ) {
        self.name = name
        self.generatedAt = generatedAt
        self.sourceProject = sourceProject
        self.activePage = activePage
        self.pages = pages
    }
}

public struct MojuDPKPackage: Codable {
    public let manifest: MojuDPKManifest
    public let pages: [String: MojuPage]
    public let releaseTitle: String
    public let releaseDescription: String
    public let generatedAt: String

    public init(
        manifest: MojuDPKManifest,
        pages: [String: MojuPage],
        releaseTitle: String,
        releaseDescription: String,
        generatedAt: String
    ) {
        self.manifest = manifest
        self.pages = pages
        self.releaseTitle = releaseTitle
        self.releaseDescription = releaseDescription
        self.generatedAt = generatedAt
    }

    public var activePage: MojuPage? {
        guard let activePage = manifest.activePage else { return nil }
        return page(namedOrId: activePage)
    }

    public func page(namedOrId target: String) -> MojuPage? {
        let normalizedTarget = normalize(target)
        return pages.first { name, page in
            normalize(name) == normalizedTarget || normalize(page.pageId ?? "") == normalizedTarget
        }?.value ?? pages.first { name, page in
            normalize(name).contains(normalizedTarget) ||
                normalizedTarget.contains(normalize(name)) ||
                normalize(page.pageId ?? "").contains(normalizedTarget)
        }?.value
    }

    private func normalize(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}

public enum MojuDPKError: Error, Equatable {
    case invalidFormat
    case unsupportedVersion
    case invalidSecret
    case decryptionFailed
    case manifestMissing
    case pageNotFound
}

public enum MojuDPKDecoder {
    private static let magic = Data([0x4D, 0x4F, 0x4A, 0x55, 0x44, 0x50, 0x4B, 0x31])
    private static let version: UInt8 = 1
    private static let nonceLength = 12
    private static let tagLength = 16

    public static func decodePackage(from data: Data, secret: Data) throws -> MojuDPKPackage {
        guard data.count > magic.count + 1 + nonceLength + tagLength,
              data.prefix(magic.count) == magic else {
            throw MojuDPKError.invalidFormat
        }

        let versionIndex = magic.count
        guard data[versionIndex] == version else {
            throw MojuDPKError.unsupportedVersion
        }

        let payloadStart = versionIndex + 1
        let nonceEnd = payloadStart + nonceLength
        let tagStart = data.count - tagLength
        guard nonceEnd < tagStart else {
            throw MojuDPKError.invalidFormat
        }

        let key = try symmetricKey(from: secret)
        let nonceData = data[payloadStart..<nonceEnd]
        let ciphertext = data[nonceEnd..<tagStart]
        let tag = data[tagStart..<data.count]

        let sealedBox: AES.GCM.SealedBox
        do {
            let nonce = try AES.GCM.Nonce(data: nonceData)
            sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        } catch {
            throw MojuDPKError.invalidFormat
        }

        let plaintext: Data
        do {
            plaintext = try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw MojuDPKError.decryptionFailed
        }

        do {
            let package = try JSONDecoder().decode(MojuDPKPackage.self, from: plaintext)
            guard !package.manifest.pages.isEmpty else {
                throw MojuDPKError.manifestMissing
            }
            try package.pages.values.forEach(MojuSchemaValidator.validate)
            return package
        } catch let error as MojuDPKError {
            throw error
        } catch {
            throw MojuDPKError.invalidFormat
        }
    }

    public static func decodePage(named target: String, from data: Data, secret: Data) throws -> MojuPage {
        let package = try decodePackage(from: data, secret: secret)
        guard let page = package.page(namedOrId: target) else {
            throw MojuDPKError.pageNotFound
        }
        return page
    }

    private static func symmetricKey(from secret: Data) throws -> SymmetricKey {
        guard !secret.isEmpty else {
            throw MojuDPKError.invalidSecret
        }

        if secret.count == 32 {
            return SymmetricKey(data: secret)
        }

        return SymmetricKey(data: SHA256.hash(data: secret))
    }
}
