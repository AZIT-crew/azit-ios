import AuthenticationServices
import Foundation
import UIKit

final class SocialLoginHandler: NSObject {

    private weak var bridge: AppBridge?
    private weak var viewController: UIViewController?
    private var pendingId: String?
    private var webAuthSession: ASWebAuthenticationSession?

    init(bridge: AppBridge, viewController: UIViewController?) {
        self.bridge = bridge
        self.viewController = viewController
    }

    func socialLogin(type: String, id: String) {
        pendingId = id
        switch type {
        case "kakao":
            startKakaoLogin(id: id)
        case "apple":
            DispatchQueue.main.async { [weak self] in
                self?.startAppleLogin(id: id)
            }
        default:
            bridge?.respondObject(id: id, value: ["success": false, "message": "지원하지 않는 로그인 방식입니다."])
            pendingId = nil
        }
    }

    private func startKakaoLogin(id: String) {
        guard let kakaoURL = buildKakaoOAuthURL() else {
            bridge?.respondObject(id: id, value: ["success": false, "message": "카카오 로그인 URL 생성에 실패했습니다."])
            pendingId = nil
            return
        }
        let session = ASWebAuthenticationSession(url: kakaoURL, callbackURLScheme: "azit") { [weak self] callbackURL, error in
            Task { @MainActor in
                guard let self else { return }
                self.webAuthSession = nil
                if let authError = error as? ASWebAuthenticationSessionError, authError.code == .canceledLogin {
                    self.bridge?.respondObject(id: id, value: ["success": false, "message": "로그인이 취소되었습니다."])
                    self.pendingId = nil
                    return
                }
                if error != nil {
                    self.bridge?.respondObject(id: id, value: ["success": false, "message": "카카오 로그인에 실패했습니다."])
                    self.pendingId = nil
                    return
                }
                guard let url = callbackURL,
                      let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    self.bridge?.respondObject(id: id, value: ["success": false, "message": "인증 코드를 받지 못했습니다."])
                    self.pendingId = nil
                    return
                }
                self.bridge?.respondObject(id: id, value: ["success": true, "authorizationCode": code])
                self.pendingId = nil
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        webAuthSession = session
        DispatchQueue.main.async { session.start() }
    }

    private func buildKakaoOAuthURL() -> URL? {
        var components = URLComponents(string: "https://kauth.kakao.com/oauth/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: AppConfig.kakaoAppKey),
            URLQueryItem(name: "redirect_uri", value: AppConfig.kakaoRedirectURI),
            URLQueryItem(name: "response_type", value: "code"),
        ]
        return components?.url
    }

    private func startAppleLogin(id: String) {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
}

extension SocialLoginHandler: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        viewController?.view.window ?? UIWindow()
    }
}

extension SocialLoginHandler: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let id = pendingId else { return }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let codeData = credential.authorizationCode,
              let code = String(data: codeData, encoding: .utf8) else {
            bridge?.respondObject(id: id, value: ["success": false, "message": "애플 로그인에 실패했습니다."])
            pendingId = nil
            return
        }
        bridge?.respondObject(id: id, value: ["success": true, "authorizationCode": code])
        pendingId = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard let id = pendingId else { return }
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            bridge?.respondObject(id: id, value: ["success": false, "message": "로그인이 취소되었습니다."])
        } else {
            bridge?.respondObject(id: id, value: ["success": false, "message": error.localizedDescription])
        }
        pendingId = nil
    }
}

extension SocialLoginHandler: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        viewController?.view.window ?? UIWindow()
    }
}
