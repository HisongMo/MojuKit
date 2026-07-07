import Foundation

@MainActor
final class SimulatorPreviewController: ObservableObject {
    @Published private(set) var isWorking = false
    @Published private(set) var statusText = "Simulator 预览未启动"
    @Published private(set) var selectedDeviceName = "-"
    @Published private(set) var lastLog = ""
    @Published private(set) var lastLogFilePath = "-"

    private let bundleIdentifier = "com.demo.MojuKitPreview"
    private var lastProjectURL: URL?

    func start(projectURL: URL?) {
        guard let projectURL else {
            statusText = "请先加载页面项目文件夹"
            return
        }
        lastProjectURL = projectURL

        isWorking = true
        statusText = "正在启动 iPhone Simulator 预览..."
        lastLog = ""

        Task {
            do {
                let hostProjectURL = try resolveHostProjectURL(from: projectURL)
                let device = try await selectDevice()
                selectedDeviceName = device.name
                statusText = "正在构建 MojuKitPreview..."

                let derivedDataURL = hostProjectURL.appendingPathComponent(".build/SimulatorPreviewDerivedData", isDirectory: true)
                try await build(projectURL: hostProjectURL, derivedDataURL: derivedDataURL, device: device)

                statusText = "正在启动 \(device.name)..."
                try await boot(device: device)

                statusText = "正在安装 MojuKitPreview..."
                let appURL = derivedDataURL.appendingPathComponent("Build/Products/Debug-iphonesimulator/MojuKitPreview.app", isDirectory: true)
                guard FileManager.default.fileExists(atPath: appURL.appendingPathComponent("Info.plist").path) else {
                    throw SimulatorPreviewError.commandFailed("构建完成但未找到 MojuKitPreview.app：\(appURL.path)")
                }
                try await run("/usr/bin/xcrun", ["simctl", "install", device.udid, appURL.path])

                statusText = "正在打开 MojuKitPreview..."
                _ = try? await run("/usr/bin/open", ["-a", "Simulator"])
                _ = try? await run("/usr/bin/xcrun", ["simctl", "terminate", device.udid, bundleIdentifier])
                try await run("/usr/bin/xcrun", ["simctl", "launch", device.udid, bundleIdentifier, "--dynamicpage-preview-host"])

                statusText = "\(device.name) 预览运行中"
            } catch {
                statusText = "Simulator 预览启动失败：\(error.localizedDescription)"
            }
            isWorking = false
        }
    }

    func relaunchHost() {
        guard let lastProjectURL else {
            statusText = "请先点击“启动 iPhone 预览”完成安装"
            return
        }

        isWorking = true
        statusText = "正在重新安装并启动 MojuKitPreview..."

        Task {
            do {
                let hostProjectURL = try resolveHostProjectURL(from: lastProjectURL)
                let device = try await selectDevice()
                selectedDeviceName = device.name
                let derivedDataURL = hostProjectURL.appendingPathComponent(".build/SimulatorPreviewDerivedData", isDirectory: true)
                let appURL = derivedDataURL.appendingPathComponent("Build/Products/Debug-iphonesimulator/MojuKitPreview.app", isDirectory: true)
                if !FileManager.default.fileExists(atPath: appURL.path) {
                    try await build(projectURL: hostProjectURL, derivedDataURL: derivedDataURL, device: device)
                }
                try await boot(device: device)
                try await run("/usr/bin/xcrun", ["simctl", "install", device.udid, appURL.path])
                _ = try? await run("/usr/bin/xcrun", ["simctl", "terminate", device.udid, bundleIdentifier])
                _ = try? await run("/usr/bin/open", ["-a", "Simulator"])
                try await run("/usr/bin/xcrun", ["simctl", "launch", device.udid, bundleIdentifier, "--dynamicpage-preview-host"])
                statusText = "\(device.name) MojuKitPreview 已重启"
            } catch {
                statusText = "重启失败：\(error.localizedDescription)"
            }
            isWorking = false
        }
    }

    private func build(projectURL: URL, derivedDataURL: URL) async throws {
        try await build(projectURL: projectURL, derivedDataURL: derivedDataURL, device: nil)
    }

    private func build(projectURL: URL, derivedDataURL: URL, device: SimulatorDevice?) async throws {
        let destination = device.map { "platform=iOS Simulator,id=\($0.udid)" } ?? "generic/platform=iOS Simulator"
        try await run(
            "/usr/bin/xcodebuild",
            [
                "-project", projectURL.appendingPathComponent("MojuKitPreview.xcodeproj").path,
                "-scheme", "MojuKitPreview",
                "-configuration", "Debug",
                "-destination", destination,
                "-derivedDataPath", derivedDataURL.path,
                "-quiet",
                "build"
            ]
        )
    }

    private func resolveHostProjectURL(from loadedProjectURL: URL?) throws -> URL {
        var candidates: [URL] = []
        if let loadedProjectURL {
            candidates.append(loadedProjectURL)
            candidates.append(loadedProjectURL.deletingLastPathComponent())
        }

        let bundleURL = Bundle.main.bundleURL
        candidates.append(bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent())
        candidates.append(URL(fileURLWithPath: "/Users/wangleihaoshuaio/Developer/Demo/MojuKit", isDirectory: true))

        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("MojuKitPreview.xcodeproj").path) {
                return candidate
            }
        }

        throw SimulatorPreviewError.commandFailed("没有找到 MojuKitPreview.xcodeproj。页面项目可以是任意文件夹，但 MojuKitPreview 需要当前 MojuKitPreview 工程。")
    }

    private func boot(device: SimulatorDevice) async throws {
        if device.state != "Booted" {
            _ = try? await run("/usr/bin/xcrun", ["simctl", "boot", device.udid])
        }
        try await run("/usr/bin/xcrun", ["simctl", "bootstatus", device.udid, "-b"])
    }

    private func selectDevice() async throws -> SimulatorDevice {
        let output = try await run("/usr/bin/xcrun", ["simctl", "list", "devices", "available", "--json"])
        let data = Data(output.utf8)
        let list = try JSONDecoder().decode(SimctlDeviceList.self, from: data)
        let devices = list.devices.values
            .flatMap { $0 }
            .filter { $0.isAvailable != false && $0.name.contains("iPhone") }

        guard !devices.isEmpty else {
            throw SimulatorPreviewError.noAvailableIPhoneSimulator
        }

        return devices.sorted { lhs, rhs in
            score(lhs) < score(rhs)
        }[0]
    }

    private func score(_ device: SimulatorDevice) -> Int {
        if device.state == "Booted" { return 0 }
        if device.name.contains("iPhone 17") { return 1 }
        if device.name.contains("iPhone 16") { return 2 }
        if device.name.contains("iPhone 15") { return 3 }
        if device.name.contains("iPhone 14") { return 4 }
        return 10
    }

    @discardableResult
    private func run(_ executable: String, _ arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let logURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("dynamicpagekit-studio-\(UUID().uuidString).log")
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
            guard let logHandle = try? FileHandle(forWritingTo: logURL) else {
                continuation.resume(throwing: SimulatorPreviewError.commandFailed("无法创建命令日志文件"))
                return
            }

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = logHandle
            process.standardError = logHandle

            process.terminationHandler = { process in
                try? logHandle.close()
                let data = (try? Data(contentsOf: logURL)) ?? Data()
                try? FileManager.default.removeItem(at: logURL)
                let output = String(data: data, encoding: .utf8) ?? ""
                let commandLine = ([executable] + arguments).joined(separator: " ")
                let fullOutput = output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? commandLine
                    : "\(commandLine)\n\(output)"
                Task { @MainActor in
                    let trimmedOutput = fullOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.lastLog = trimmedOutput
                    self.persistLastLog(trimmedOutput)
                    if process.terminationStatus == 0 {
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(throwing: SimulatorPreviewError.commandFailed("exit \(process.terminationStatus)\n\(fullOutput)"))
                    }
                }
            }

            do {
                try process.run()
            } catch {
                try? logHandle.close()
                try? FileManager.default.removeItem(at: logURL)
                continuation.resume(throwing: error)
            }
        }
    }

    private func persistLastLog(_ text: String) {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("DynamicPageKitStudio", isDirectory: true)
        guard let supportURL else { return }
        do {
            try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
            let logURL = supportURL.appendingPathComponent("last-simulator-preview.log")
            try text.write(to: logURL, atomically: true, encoding: .utf8)
            lastLogFilePath = logURL.path
        } catch {
            lastLogFilePath = "日志保存失败：\(error.localizedDescription)"
        }
    }
}

private struct SimctlDeviceList: Decodable {
    let devices: [String: [SimulatorDevice]]
}

private struct SimulatorDevice: Decodable {
    let name: String
    let udid: String
    let state: String
    let isAvailable: Bool?
}

private enum SimulatorPreviewError: LocalizedError {
    case noAvailableIPhoneSimulator
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAvailableIPhoneSimulator:
            return "没有找到可用的 iPhone Simulator"
        case .commandFailed(let output):
            return output.isEmpty ? "命令执行失败" : output
        }
    }
}
