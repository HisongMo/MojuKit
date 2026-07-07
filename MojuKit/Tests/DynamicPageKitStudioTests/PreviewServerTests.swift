import XCTest
@testable import DynamicPageKitStudio

@MainActor
final class PreviewServerTests: XCTestCase {
    func testPreviewServerReturnsActiveEventsManifestAndPage() throws {
        let server = PreviewServer()
        server.publish(
            activePage: PreviewPublishedPage(
                displayName: "ETCList",
                pageId: "etc_list",
                jsonText: #"{"schemaVersion":"1.0","pageId":"etc_list","components":[]}"#
            ),
            pages: [
                PreviewPublishedPage(
                    displayName: "ETCList",
                    pageId: "etc_list",
                    jsonText: #"{"schemaVersion":"1.0","pageId":"etc_list","components":[]}"#
                ),
                PreviewPublishedPage(
                    displayName: "ETCDetail",
                    pageId: "etc_detail",
                    jsonText: #"{"schemaVersion":"1.0","pageId":"etc_detail","components":[]}"#
                )
            ]
        )

        XCTAssertTrue(body(from: server.response(for: "/active-page.json")).contains(#""pageId":"etc_list""#))
        XCTAssertTrue(body(from: server.response(for: "/events")).contains(#""revision":1"#))
        XCTAssertTrue(body(from: server.response(for: "/manifest.json")).contains(#""name" : "ETCDetail""#))
        XCTAssertTrue(body(from: server.response(for: "/page/etc_detail.json")).contains(#""pageId":"etc_detail""#))
        XCTAssertTrue(body(from: server.response(for: "/page/ETCDetail.json")).contains(#""pageId":"etc_detail""#))
    }

    func testPreviewServerReturns404ForMissingPage() {
        let server = PreviewServer()
        server.publish(
            activePage: PreviewPublishedPage(
                displayName: "Home",
                pageId: "home",
                jsonText: #"{"schemaVersion":"1.0","pageId":"home","components":[]}"#
            ),
            pages: []
        )

        let response = String(data: server.response(for: "/page/missing.json"), encoding: .utf8) ?? ""
        XCTAssertTrue(response.hasPrefix("HTTP/1.1 404 Not Found"))
        XCTAssertTrue(response.contains("page_not_found"))
    }

    func testPreviewServerRuntimeManifest() throws {
        let server = PreviewServer()
        server.publish(
            activePage: PreviewPublishedPage(
                displayName: "ETCList",
                pageId: "etc_list",
                jsonText: #"{"schemaVersion":"1.0","pageId":"etc_list","components":[]}"#
            ),
            pages: [
                PreviewPublishedPage(
                    displayName: "ETCList",
                    pageId: "etc_list",
                    jsonText: #"{"schemaVersion":"1.0","pageId":"etc_list","components":[]}"#
                )
            ]
        )

        let response = body(from: server.response(for: "/dynamic/runtime/manifest?projectKey=my_project"))
        let data = Data(response.utf8)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["projectKey"] as? String, "my_project")
        XCTAssertEqual(json?["activePage"] as? String, "ETCList")
        
        let pagesList = json?["pages"] as? [[String: Any]]
        XCTAssertEqual(pagesList?.count, 1)
        XCTAssertEqual(pagesList?[0]["name"] as? String, "ETCList")
        XCTAssertEqual(pagesList?[0]["pageId"] as? String, "etc_list")
        XCTAssertEqual(pagesList?[0]["path"] as? String, "/dynamic/runtime/page?projectKey=my_project&page=ETCList")
    }

    func testPreviewServerRuntimePage() throws {
        let server = PreviewServer()
        server.publish(
            activePage: PreviewPublishedPage(
                displayName: "ETCList",
                pageId: "etc_list",
                jsonText: #"{"schemaVersion":"1.0","pageId":"etc_list","components":[]}"#
            ),
            pages: [
                PreviewPublishedPage(
                    displayName: "ETCList",
                    pageId: "etc_list",
                    jsonText: #"{"schemaVersion":"1.0","pageId":"etc_list","components":[]}"#
                )
            ]
        )

        let response = body(from: server.response(for: "/dynamic/runtime/page?projectKey=my_project&page=ETCList"))
        let data = Data(response.utf8)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["pageId"] as? String, "etc_list")

        let missingResponse = String(data: server.response(for: "/dynamic/runtime/page?projectKey=my_project&page=Missing"), encoding: .utf8) ?? ""
        XCTAssertTrue(missingResponse.hasPrefix("HTTP/1.1 404 Not Found"))
        XCTAssertTrue(missingResponse.contains("page_not_found"))
    }

    func testPreviewServerRuntimePackage() throws {
        let server = PreviewServer()
        server.publish(
            activePage: PreviewPublishedPage(
                displayName: "ETCList",
                pageId: "etc_list",
                jsonText: #"{"schemaVersion":"1.0","pageId":"etc_list","components":[]}"#
            ),
            pages: [
                PreviewPublishedPage(
                    displayName: "ETCList",
                    pageId: "etc_list",
                    jsonText: #"{"schemaVersion":"1.0","pageId":"etc_list","components":[]}"#
                )
            ]
        )

        let response = body(from: server.response(for: "/dynamic/runtime/package?projectKey=my_project"))
        let data = Data(response.utf8)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["projectKey"] as? String, "my_project")
        
        let manifest = json?["manifest"] as? [String: Any]
        XCTAssertEqual(manifest?["activePage"] as? String, "ETCList")
        
        let pagesMap = json?["pages"] as? [String: Any]
        let etcListPage = pagesMap?["ETCList"] as? [String: Any]
        XCTAssertEqual(etcListPage?["pageId"] as? String, "etc_list")
    }

    private func body(from response: Data) -> String {
        let text = String(data: response, encoding: .utf8) ?? ""
        return text.components(separatedBy: "\r\n\r\n").last ?? ""
    }
}
