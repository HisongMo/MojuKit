import XCTest

final class DynamicPageKitCLITests: XCTestCase {
    func testCompilePageCommandOutputsRuntimeJSON() throws {
        let fixture = try makePageFixture()
        let output = try runCLI(["compile-page", "--page-dir", fixture.path])
        XCTAssertEqual(output["success"] as? Bool, true)
        XCTAssertEqual(output["pageName"] as? String, fixture.lastPathComponent)
        XCTAssertNotNil(output["jsonText"] as? String)
    }

    func testCompileProjectMatchesActivePageByPageId() throws {
        let project = try temporaryDirectory()
        let pages = project.appendingPathComponent("pages", isDirectory: true)
        try FileManager.default.createDirectory(at: pages, withIntermediateDirectories: true)
        _ = try makePageFixture(in: pages, name: "Home", pageId: "home_page")
        _ = try makePageFixture(in: pages, name: "Detail", pageId: "detail_page")

        let output = try runCLI(["compile-project", "--project-dir", project.path, "--active", "detail_page"])
        XCTAssertEqual(output["success"] as? Bool, true)
        XCTAssertEqual(output["activePage"] as? String, "Detail")
        XCTAssertEqual((output["pages"] as? [[String: Any]])?.count, 2)
    }

    func testCompilePageCommandReportsDiagnosticsForInvalidJS() throws {
        let fixture = try makePageFixture(jsText: """
        Page({
          methods: {
            missing() {
              console.log("unsupported")
            }
          }
        })
        """)
        let output = try runCLI(["compile-page", "--page-dir", fixture.path])
        XCTAssertEqual(output["success"] as? Bool, true)
        let diagnostics = try XCTUnwrap(output["diagnostics"] as? [String])
        XCTAssertTrue(diagnostics.contains { $0.contains("暂未识别") || $0.contains("没有找到") })
    }

    func testDecompileJSONCommandWritesFourFiles() throws {
        let jsonFile = try temporaryDirectory().appendingPathComponent("Legacy.json")
        try """
        {
          "schemaVersion": "1.0",
          "pageId": "legacy",
          "pageTitle": "Legacy",
          "components": [
            { "type": "text", "text": "Legacy Page" }
          ]
        }
        """.write(to: jsonFile, atomically: true, encoding: .utf8)

        let outputDirectory = try temporaryDirectory().appendingPathComponent("LegacyPage")
        let output = try runCLI(["decompile-json", "--json", jsonFile.path, "--out-dir", outputDirectory.path])
        XCTAssertEqual(output["success"] as? Bool, true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("index.dkml").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("index.dkss").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("index.js").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("index.json").path))
    }

    private func makePageFixture(
        in parent: URL? = nil,
        name: String = "SamplePage",
        pageId: String = "sample_page",
        jsText: String = """
        Page({
          methods: {
            showToast() {
              dk.toast("Saved")
            }
          }
        })
        """
    ) throws -> URL {
        let root = try parent ?? temporaryDirectory()
        let directory = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try """
        <page class="page">
          <button class="primary-button" bindtap="showToast">Save</button>
        </page>
        """.write(to: directory.appendingPathComponent("index.dkml"), atomically: true, encoding: .utf8)
        try """
        .page {
          background-color: #FFFFFF;
        }

        .primary-button {
          height: 44;
          background-color: #2F80ED;
          text-color: #FFFFFF;
          corner-radius: 8;
        }
        """.write(to: directory.appendingPathComponent("index.dkss"), atomically: true, encoding: .utf8)
        try jsText.write(to: directory.appendingPathComponent("index.js"), atomically: true, encoding: .utf8)
        try """
        {
          "schemaVersion": "1.0",
          "pageId": "\(pageId)",
          "pageTitle": "\(name)"
        }
        """.write(to: directory.appendingPathComponent("index.json"), atomically: true, encoding: .utf8)
        return directory
    }

    private func runCLI(_ arguments: [String]) throws -> [String: Any] {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let executable = try cliExecutableURL(packageRoot: packageRoot)
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = packageRoot

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let error = String(data: errorData, encoding: .utf8) ?? "CLI failed"
            XCTFail(error)
        }
        let data = outputData.isEmpty ? errorData : outputData
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any])
    }

    private func cliExecutableURL(packageRoot: URL) throws -> URL {
        let candidates = [
            packageRoot.appendingPathComponent(".build/debug/DynamicPageKitCLI"),
            packageRoot.appendingPathComponent(".build/arm64-apple-macosx/debug/DynamicPageKitCLI"),
            packageRoot.appendingPathComponent(".build/x86_64-apple-macosx/debug/DynamicPageKitCLI")
        ]
        guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
            throw XCTSkip("DynamicPageKitCLI executable was not found in .build; run swift test after building executable products.")
        }
        return executable
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DynamicPageKitCLITests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
