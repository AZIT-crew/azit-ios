import Foundation

enum AuthProvider: String {
    case kakao = "KAKAO"
    case apple = "APPLE"
}

enum AuthStatus: String {
    case active = "ACTIVE"
    case pendingTerms = "PENDING_TERMS"
    case pendingOnboarding = "PENDING_ONBOARDING"
}

struct AuthResult {
    let accessToken: String
    let status: String
}

enum AuthError: Error {
    case noRefreshToken
    case requestFailed(statusCode: Int)
    case invalidResponse
    case reissueFailed
}

@MainActor
final class AuthManager {

    static let shared = AuthManager()
    private init() {}

    private(set) var accessToken: String?

    var isLoggedIn: Bool {
        KeychainManager.shared.refreshToken != nil
    }

    func initialize() async -> AuthResult? {
        guard KeychainManager.shared.refreshToken != nil else { return nil }
        return try? await reissue()
    }

    func login(provider: AuthProvider, authorizationCode: String) async throws -> AuthResult {
        let url = AppConfig.apiURL.appendingPathComponent("auth/social-login/\(provider.rawValue)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["authorizationCode": authorizationCode])

        let result = try await perform(request: request, url: url)
        accessToken = result.accessToken
        return result
    }

    func reissue() async throws -> AuthResult {
        guard let refreshToken = KeychainManager.shared.refreshToken else {
            throw AuthError.noRefreshToken
        }
        let url = AppConfig.apiURL.appendingPathComponent("auth/reissue")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("refreshToken=\(refreshToken)", forHTTPHeaderField: "Cookie")

        let result = try await perform(request: request, url: url)
        accessToken = result.accessToken
        return result
    }

    func logout() {
        accessToken = nil
        KeychainManager.shared.deleteRefreshToken()
    }

    private func perform(request: URLRequest, url: URL) async throws -> AuthResult {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AuthError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let headerFields = httpResponse.allHeaderFields.reduce(into: [String: String]()) { acc, pair in
            if let key = pair.key as? String, let value = pair.value as? String {
                acc[key] = value
            }
        }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
        if let refreshCookie = cookies.first(where: { $0.name == "refreshToken" }) {
            KeychainManager.shared.setRefreshToken(refreshCookie.value)
        }

        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        guard let accessToken = decoded.result?.accessToken else {
            throw AuthError.invalidResponse
        }

        return AuthResult(accessToken: accessToken, status: decoded.result?.status ?? "ACTIVE")
    }
}

private struct APIResponse: Decodable {
    let code: String?
    let result: AuthResponseResult?
}

private struct AuthResponseResult: Decodable {
    let accessToken: String?
    let status: String?
}
