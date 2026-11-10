import Foundation

enum WebNavigationDecision: Equatable {
    case loadInApp
    case openExternally
}

struct WebPolicy {

    let baseURL: URL

    static let app = WebPolicy(baseURL: AppConfig.webURL)

    func isTrusted(host: String?) -> Bool {
        host?.lowercased() == baseURL.host?.lowercased()
    }

    func decide(for url: URL) -> WebNavigationDecision {
        switch url.scheme?.lowercased() {
        case "http", "https":
            return isTrusted(host: url.host) ? .loadInApp : .openExternally
        case "about", "blob", "data":
            return .loadInApp
        default:
            return .openExternally
        }
    }

    // azit://schedule/1?tab=a → WEB_URL/schedule/1?tab=a
    func webURL(fromDeepLink url: URL) -> URL? {
        guard url.scheme?.lowercased() == "azit" else { return nil }
        var path = "/\(url.host ?? "")\(url.path)"
        if let query = url.query {
            path += "?\(query)"
        }
        return URL(string: baseURL.absoluteString + path)
    }
}
