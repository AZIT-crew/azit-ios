import Foundation
import UIKit
import WebKit

private struct BridgeMessage: Decodable {
    let type: String
    let method: String?
    let args: [JSONValue]?
    let id: String?
}

final class AppBridge: NSObject {

    static let handlerName = "Bridge"

    static func userScript(accessToken: String?, authStatus: String?) -> WKUserScript {
        let tokenExpr: String
        if let token = accessToken,
           let encoded = try? JSONEncoder().encode(token),
           let str = String(data: encoded, encoding: .utf8) {
            tokenExpr = str
        } else {
            tokenExpr = "undefined"
        }
        let statusExpr: String
        if let status = authStatus,
           let encoded = try? JSONEncoder().encode(status),
           let str = String(data: encoded, encoding: .utf8) {
            statusExpr = str
        } else {
            statusExpr = "undefined"
        }
        let js = """
        (function() {
            window.ReactNativeWebView = {
                postMessage: function(msg) {
                    window.webkit.messageHandlers.\(handlerName).postMessage(msg);
                }
            };
            window.__accessToken__ = \(tokenExpr);
            window.__authStatus__ = \(statusExpr);
        })();
        """
        return WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    weak var webView: WKWebView?
    private weak var viewController: UIViewController?

    private lazy var locationHandler = LocationHandler(bridge: self)
    private lazy var imagePickerHandler = ImagePickerHandler(bridge: self, viewController: viewController)
    private lazy var socialLoginHandler = SocialLoginHandler(bridge: self, viewController: viewController)

    init(viewController: UIViewController) {
        self.viewController = viewController
    }

    func respondVoid(id: String) {
        emitResponse(["type": "response", "id": id, "result": NSNull()])
    }

    func respondString(id: String, value: String) {
        emitResponse(["type": "response", "id": id, "result": value])
    }

    func respondObject(id: String, value: [String: Any]) {
        emitResponse(["type": "response", "id": id, "result": value])
    }

    func respondError(id: String, message: String = "오류가 발생했습니다.") {
        emitResponse(["type": "response", "id": id, "error": message])
    }

    private func emitResponse(_ response: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: response),
              let jsonStr = String(data: data, encoding: .utf8),
              let quotedData = try? JSONEncoder().encode(jsonStr),
              let quotedStr = String(data: quotedData, encoding: .utf8) else { return }
        let js = "window.dispatchEvent(new MessageEvent('message', { data: \(quotedStr) }));"
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}

extension AppBridge: WKScriptMessageHandler {

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == Self.handlerName,
              let bodyStr = message.body as? String,
              let data = bodyStr.data(using: .utf8),
              let msg = try? JSONDecoder().decode(BridgeMessage.self, from: data)
        else { return }

        guard msg.type == "request",
              let method = msg.method,
              let id = msg.id
        else { return }

        handleMethod(method: method, id: id, args: msg.args ?? [])
    }

    private func handleMethod(method: String, id: String, args: [JSONValue]) {
        switch method {

        case "openExternalBrowser", "shareInviteCode", "shareSchedule", "openNaverMap":
            handleExternalMethod(method: method, id: id, args: args)

        case "getCurrentPosition":
            locationHandler.getCurrentPosition(id: id)

        case "getLocationPermissionStatus":
            locationHandler.getLocationPermissionStatus(id: id)

        case "openLocationSettings":
            openLocationSettings(id: id)

        case "pickProfileImage":
            guard let source = args[safe: 0]?.string else {
                respondError(id: id); return
            }
            imagePickerHandler.pickProfileImage(source: source, id: id)

        case "getAppVersion":
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            respondString(id: id, value: version)

        case "socialLogin":
            guard let type = args[safe: 0]?.string else {
                respondError(id: id); return
            }
            socialLoginHandler.socialLogin(type: type, id: id)

        default:
            respondError(id: id, message: "지원하지 않는 메서드: \(method)")
        }
    }

    private func handleExternalMethod(method: String, id: String, args: [JSONValue]) {
        switch method {

        case "openExternalBrowser":
            guard let urlStr = args[safe: 0]?.string, let url = URL(string: urlStr) else {
                respondError(id: id); return
            }
            DispatchQueue.main.async { UIApplication.shared.open(url) }
            respondVoid(id: id)

        case "shareInviteCode":
            guard let code = args[safe: 0]?.string,
                  let crewName = args[safe: 1]?.string else {
                respondError(id: id); return
            }
            let webURL = AppConfig.webURL.absoluteString
            let text = "[AZIT] '\(crewName)' 크루에서 당신을 초대했어요!\n\n초대 코드: \(code)\n\n\(webURL)/onboarding?inviteCode=\(code)"
            showShareSheet(text: text, id: id)

        case "shareSchedule":
            guard let scheduleId = args[safe: 0]?.string else {
                respondError(id: id); return
            }
            let webURL = AppConfig.webURL.absoluteString
            let text = "[AZIT 일정] 이번 주 정기런/번개런 일정 확정!\n상세 일정을 확인하고, 지금 바로 AZIT 앱에서 신청해 주세요.\n\(webURL)/schedule/\(scheduleId)"
            showShareSheet(text: text, id: id)

        case "openNaverMap":
            guard let address = args[safe: 0]?.string,
                  let lat = args[safe: 1]?.number,
                  let lng = args[safe: 2]?.number else {
                respondError(id: id); return
            }
            openNaverMap(address: address, lat: lat, lng: lng, id: id)

        default:
            break
        }
    }

    private func openLocationSettings(id: String) {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            DispatchQueue.main.async { UIApplication.shared.open(url) }
        }
        respondVoid(id: id)
    }

    private func showShareSheet(text: String, id: String) {
        DispatchQueue.main.async { [weak self] in
            guard let vc = self?.viewController else { return }
            let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            activity.completionWithItemsHandler = { [weak self] _, _, _, _ in
                self?.respondVoid(id: id)
            }
            vc.present(activity, animated: true)
        }
    }

    private func openNaverMap(address: String, lat: Double, lng: Double, id: String) {
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        let appURLStr = "nmap://place?lat=\(lat)&lng=\(lng)&name=\(encoded)&appname=com.azitcrew.app"
        let storeURLStr = "https://apps.apple.com/app/id347727151"
        DispatchQueue.main.async { [weak self] in
            if let appURL = URL(string: appURLStr) {
                UIApplication.shared.open(appURL) { success in
                    if !success, let storeURL = URL(string: storeURLStr) {
                        UIApplication.shared.open(storeURL)
                    }
                }
            }
            self?.respondVoid(id: id)
        }
    }
}
