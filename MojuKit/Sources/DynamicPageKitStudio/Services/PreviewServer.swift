import Foundation
import Network

struct PreviewPublishedPage: Equatable {
    let displayName: String
    let pageId: String?
    let jsonText: String
}

@MainActor
final class PreviewServer: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var statusText = "预览服务未启动"
    @Published private(set) var revision = 0

    let port: UInt16 = 8088
    private var listener: NWListener?
    private var activeJSON = "{}"
    private var activePageName: String?
    private var pages: [PreviewPublishedPage] = []

    var activePageURL: String {
        "http://127.0.0.1:\(port)/active-page.json"
    }

    var eventsURL: String {
        "http://127.0.0.1:\(port)/events"
    }

    func start() {
        guard listener == nil else { return }

        do {
            let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handle(connection: connection)
                }
            }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.updateState(state)
                }
            }
            listener.start(queue: .global(qos: .userInitiated))
            self.listener = listener
        } catch {
            isRunning = false
            statusText = "预览服务启动失败：\(error.localizedDescription)"
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        statusText = "预览服务已停止"
    }

    func publish(jsonText: String) {
        activeJSON = jsonText
        revision += 1
    }

    func publish(activePage: PreviewPublishedPage, pages: [PreviewPublishedPage]) {
        activeJSON = activePage.jsonText
        activePageName = activePage.displayName
        self.pages = pages
        revision += 1
    }

    private func updateState(_ state: NWListener.State) {
        switch state {
        case .ready:
            isRunning = true
            statusText = "预览服务运行中：\(activePageURL)"
        case .failed(let error):
            isRunning = false
            statusText = "预览服务失败：\(error.localizedDescription)"
            listener = nil
        case .cancelled:
            isRunning = false
            statusText = "预览服务已停止"
            listener = nil
        default:
            break
        }
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, _ in
            guard let self else {
                connection.cancel()
                return
            }

            Task { @MainActor in
                let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                let path = self.path(from: request)
                print("[PreviewServer] 收到 HTTP 请求: \(path)")
                let response = self.response(for: path)
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    private func path(from request: String) -> String {
        let firstLine = request.split(separator: "\r\n", maxSplits: 1).first ?? ""
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return "/" }
        return String(parts[1])
    }

    func response(for rawPath: String) -> Data {
        let path = rawPath.components(separatedBy: "?").first ?? rawPath
        
        let queryParams: [String: String]
        if let components = URLComponents(string: "http://localhost" + rawPath),
           let queryItems = components.queryItems {
            queryParams = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })
        } else {
            queryParams = [:]
        }
        print("[PreviewServer] 路由分发 - 路径: \(path), 查询参数: \(queryParams)")
        
        switch path {
        case "/active-page.json":
            return httpResponse(body: activeJSON, contentType: "application/json")
        case "/events":
            return httpResponse(
                body: #"{"revision":\#(revision)}"#,
                contentType: "application/json"
            )
        case "/manifest.json":
            return httpResponse(body: manifestJSON(), contentType: "application/json")
        case "/dynamic/runtime/manifest":
            let projectKey = queryParams["projectKey"] ?? ""
            let manifestPages = pages.map { page -> [String: Any] in
                let escapedName = page.displayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? page.displayName
                let path = "/dynamic/runtime/page?projectKey=\(projectKey)&page=\(escapedName)"
                return [
                    "name": page.displayName,
                    "pageId": page.pageId ?? NSNull(),
                    "path": path
                ]
            }
            let manifestInfo: [String: Any] = [
                "projectKey": projectKey,
                "name": "DynamicPageKit Studio",
                "activePage": activePageName ?? NSNull(),
                "pages": manifestPages
            ]
            if let data = try? JSONSerialization.data(withJSONObject: manifestInfo, options: [.prettyPrinted, .sortedKeys]),
               let bodyString = String(data: data, encoding: .utf8) {
                return httpResponse(body: bodyString, contentType: "application/json")
            }
            return httpResponse(statusCode: 500, reason: "Internal Server Error", body: #"{"error":"serialization_failed"}"#, contentType: "application/json")
            
        case "/dynamic/runtime/page":
            let pageName = queryParams["page"] ?? ""
            if let page = page(matching: pageName) {
                return httpResponse(body: page.jsonText, contentType: "application/json")
            }
            return httpResponse(
                statusCode: 404,
                reason: "Not Found",
                body: #"{"error":"page_not_found", "message":"Page not found: \#(pageName)"}"#,
                contentType: "application/json"
            )
            
        case "/dynamic/runtime/package":
            let projectKey = queryParams["projectKey"] ?? ""
            let manifestPages = pages.map { page -> [String: Any] in
                let escapedName = page.displayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? page.displayName
                let path = "/dynamic/runtime/page?projectKey=\(projectKey)&page=\(escapedName)"
                return [
                    "name": page.displayName,
                    "pageId": page.pageId ?? NSNull(),
                    "path": path
                ]
            }
            let manifestInfo: [String: Any] = [
                "projectKey": projectKey,
                "name": "DynamicPageKit Studio",
                "activePage": activePageName ?? NSNull(),
                "pages": manifestPages
            ]
            
            var pagesMap: [String: Any] = [:]
            for page in pages {
                if let data = page.jsonText.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) {
                    pagesMap[page.displayName] = json
                }
            }
            
            let packageJSON: [String: Any] = [
                "projectKey": projectKey,
                "manifest": manifestInfo,
                "pages": pagesMap
            ]
            
            if let data = try? JSONSerialization.data(withJSONObject: packageJSON, options: [.prettyPrinted, .sortedKeys]),
               let bodyString = String(data: data, encoding: .utf8) {
                return httpResponse(body: bodyString, contentType: "application/json")
            }
            return httpResponse(statusCode: 500, reason: "Internal Server Error", body: #"{"error":"serialization_failed"}"#, contentType: "application/json")

        default:
            if path.hasPrefix("/page/"), path.hasSuffix(".json") {
                let target = String(path.dropFirst("/page/".count).dropLast(".json".count))
                    .removingPercentEncoding ?? ""
                if let page = page(matching: target) {
                    return httpResponse(body: page.jsonText, contentType: "application/json")
                }
                return httpResponse(
                    statusCode: 404,
                    reason: "Not Found",
                    body: #"{"error":"page_not_found"}"#,
                    contentType: "application/json"
                )
            }

            return httpResponse(
                body: #"{"name":"DynamicPageKit Studio","activePage":"/active-page.json","events":"/events","manifest":"/manifest.json"}"#,
                contentType: "application/json"
            )
        }
    }

    private func page(matching target: String) -> PreviewPublishedPage? {
        let normalizedTarget = normalize(target)
        return pages.first { page in
            normalize(page.displayName) == normalizedTarget ||
                normalize(page.pageId ?? "") == normalizedTarget
        } ?? pages.first { page in
            normalize(page.displayName).contains(normalizedTarget) ||
                normalizedTarget.contains(normalize(page.displayName))
        }
    }

    private func manifestJSON() -> String {
        struct Manifest: Encodable {
            struct Page: Encodable {
                let name: String
                let pageId: String?
                let path: String
            }

            let name: String
            let revision: Int
            let activePage: String?
            let activePagePath: String
            let eventsPath: String
            let pages: [Page]
        }

        let manifest = Manifest(
            name: "DynamicPageKit Studio",
            revision: revision,
            activePage: activePageName,
            activePagePath: "/active-page.json",
            eventsPath: "/events",
            pages: pages.map { page in
                let escapedName = page.displayName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? page.displayName
                return Manifest.Page(
                    name: page.displayName,
                    pageId: page.pageId,
                    path: "/page/\(escapedName).json"
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(manifest) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private func httpResponse(
        statusCode: Int = 200,
        reason: String = "OK",
        body: String,
        contentType: String
    ) -> Data {
        let bodyData = Data(body.utf8)
        let header = """
        HTTP/1.1 \(statusCode) \(reason)\r
        Content-Type: \(contentType); charset=utf-8\r
        Access-Control-Allow-Origin: *\r
        Cache-Control: no-store\r
        Content-Length: \(bodyData.count)\r
        Connection: close\r
        \r

        """
        var data = Data(header.utf8)
        data.append(bodyData)
        return data
    }
}
