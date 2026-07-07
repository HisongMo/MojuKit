import Foundation

struct DynamicPagePreviewSnapshot {
    let revision: Int
    let page: DynamicPage
}

final class DynamicPagePreviewClient {
    private struct EventsResponse: Decodable {
        let revision: Int
    }

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "http://127.0.0.1:8088")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchRevision() async throws -> Int {
        let url = baseURL.appendingPathComponent("events")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(EventsResponse.self, from: data).revision
    }

    func fetchActivePage(revision: Int) async throws -> DynamicPagePreviewSnapshot {
        let url = baseURL.appendingPathComponent("active-page.json")
        let (data, _) = try await session.data(from: url)
        let page = try DynamicSchemaValidator.decodePage(from: data)
        return DynamicPagePreviewSnapshot(revision: revision, page: page)
    }

    func fetchPage(target: String) async throws -> DynamicPage {
        let escapedTarget = target.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? target
        let url = baseURL
            .appendingPathComponent("page")
            .appendingPathComponent("\(escapedTarget).json")
        let (data, response) = try await session.data(from: url)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            throw URLError(.fileDoesNotExist)
        }
        return try DynamicSchemaValidator.decodePage(from: data)
    }

    func fetchRuntimeManifest(projectKey: String) async throws -> [String: Any] {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("dynamic/runtime/manifest"), resolvingAgainstBaseURL: true) else {
            throw URLError(.badURL)
        }
        components.queryItems = [URLQueryItem(name: "projectKey", value: projectKey)]
        guard let url = components.url else { throw URLError(.badURL) }
        print("[Client] 请求 Manifest URL: \(url)")
        let (data, response) = try await session.data(from: url)
        if let httpResponse = response as? HTTPURLResponse {
            print("[Client] Manifest 响应状态码: \(httpResponse.statusCode)")
        }
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            throw URLError(.fileDoesNotExist)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        return json
    }

    func fetchRuntimePage(projectKey: String, pageName: String) async throws -> DynamicPage {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("dynamic/runtime/page"), resolvingAgainstBaseURL: true) else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "projectKey", value: projectKey),
            URLQueryItem(name: "page", value: pageName)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        print("[Client] 请求 Page URL: \(url)")
        let (data, response) = try await session.data(from: url)
        if let httpResponse = response as? HTTPURLResponse {
            print("[Client] Page 响应状态码: \(httpResponse.statusCode)")
        }
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            throw URLError(.fileDoesNotExist)
        }
        return try DynamicSchemaValidator.decodePage(from: data)
    }

    func fetchRuntimePackage(projectKey: String) async throws -> [String: Any] {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("dynamic/runtime/package"), resolvingAgainstBaseURL: true) else {
            throw URLError(.badURL)
        }
        components.queryItems = [URLQueryItem(name: "projectKey", value: projectKey)]
        guard let url = components.url else { throw URLError(.badURL) }
        print("[Client] 请求 Package URL: \(url)")
        let (data, response) = try await session.data(from: url)
        if let httpResponse = response as? HTTPURLResponse {
            print("[Client] Package 响应状态码: \(httpResponse.statusCode)")
        }
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            throw URLError(.fileDoesNotExist)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        return json
    }
}
