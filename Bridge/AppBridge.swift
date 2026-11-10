import Foundation
import UIKit
import WebKit

private struct BridgeMessage: Decodable {
    let type: String
    let bridgeId: String?
    let body: BridgeBody?
}

private struct BridgeBody: Decodable {
    let method: String?
    let eventId: String?
    let args: [JSONValue]?
}

final class AppBridge: NSObject {

    static let handlerName = "Bridge"

    private static let methods: [String] = [
        "openExternalBrowser",
        "shareInviteCode",
        "shareSchedule",
        "openNaverMap",
        "getCurrentPosition",
        "getLocationPermissionStatus",
        "openLocationSettings",
        "reissueToken",
        "pickProfileImage",
        "getAppVersion"
    ]

    static func userScript(accessToken: String?, authStatus: String?) -> WKUserScript {
        let list = methods.map { "\"\($0)\"" }.joined(separator: ", ")
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
            window.__bridgeMethods__ = [\(list)];
            window.__bridgeInitialState__ = {};
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

    init(viewController: UIViewController) {
        self.viewController = viewController
    }

    func respondVoid(method: String, eventId: String) {
        emit(method: method, eventId: eventId, valueExpr: "null", threw: false)
    }

    func respondString(method: String, eventId: String, value: String) {
        guard let encoded = try? JSONEncoder().encode(value),
              let expr = String(data: encoded, encoding: .utf8) else {
            respondError(method: method, eventId: eventId); return
        }
        emit(method: method, eventId: eventId, valueExpr: expr, threw: false)
    }

    func respondObject(method: String, eventId: String, value: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: value),
              let expr = String(data: data, encoding: .utf8) else {
            respondError(method: method, eventId: eventId); return
        }
        emit(method: method, eventId: eventId, valueExpr: expr, threw: false)
    }

    func respondError(method: String, eventId: String) {
        emit(method: method, eventId: eventId, valueExpr: "null", threw: true)
    }

    private func emit(method: String, eventId: String, valueExpr: String, threw: Bool) {
        let js = "window.nativeEmitter?.emit('\(method)-\(eventId)', \(valueExpr), \(threw ? "true" : "false"))"
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

        switch msg.type {
        case "getBridgeState":
            handleGetBridgeState()
        case "bridge":
            guard let body = msg.body,
                  let method = body.method,
                  let eventId = body.eventId
            else { return }
            handleMethod(method: method, eventId: eventId, args: body.args ?? [])
        default:
            break
        }
    }

    private func handleGetBridgeState() {
        let list = Self.methods.map { "\"\($0)\"" }.joined(separator: ", ")
        let js = "window.nativeEmitter?.emit('hydrate', { bridgeMethods: [\(list)], nativeInitialState: {} })"
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    private func handleMethod(method: String, eventId: String, args: [JSONValue]) {
        switch method {

        case "openExternalBrowser", "shareInviteCode", "shareSchedule", "openNaverMap":
            handleExternalMethod(method: method, eventId: eventId, args: args)

        case "getCurrentPosition":
            locationHandler.getCurrentPosition(method: method, eventId: eventId)

        case "getLocationPermissionStatus":
            locationHandler.getLocationPermissionStatus(method: method, eventId: eventId)

        case "openLocationSettings":
            if let url = URL(string: UIApplication.openSettingsURLString) {
                DispatchQueue.main.async { UIApplication.shared.open(url) }
            }
            respondVoid(method: method, eventId: eventId)

        case "reissueToken":
            handleReissueToken(method: method, eventId: eventId)

        case "pickProfileImage":
            guard let source = args[safe: 0]?.string else {
                respondError(method: method, eventId: eventId); return
            }
            imagePickerHandler.pickProfileImage(source: source, method: method, eventId: eventId)

        case "getAppVersion":
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            respondString(method: method, eventId: eventId, value: version)

        default:
            break
        }
    }

    private func handleExternalMethod(method: String, eventId: String, args: [JSONValue]) {
        switch method {

        case "openExternalBrowser":
            guard let urlStr = args[safe: 0]?.string, let url = URL(string: urlStr) else {
                respondError(method: method, eventId: eventId); return
            }
            DispatchQueue.main.async { UIApplication.shared.open(url) }
            respondVoid(method: method, eventId: eventId)

        case "shareInviteCode":
            guard let code = args[safe: 0]?.string,
                  let crewName = args[safe: 1]?.string else {
                respondError(method: method, eventId: eventId); return
            }
            let webURL = AppConfig.webURL.absoluteString
            let text = "[AZIT] '\(crewName)' 크루에서 당신을 초대했어요!\n\n초대 코드: \(code)\n\n\(webURL)/onboarding?inviteCode=\(code)"
            showShareSheet(text: text, method: method, eventId: eventId)

        case "shareSchedule":
            guard let scheduleId = args[safe: 0]?.string else {
                respondError(method: method, eventId: eventId); return
            }
            let webURL = AppConfig.webURL.absoluteString
            let text = "[AZIT 일정] 이번 주 정기런/번개런 일정 확정!\n상세 일정을 확인하고, 지금 바로 AZIT 앱에서 신청해 주세요.\n\(webURL)/schedule/\(scheduleId)"
            showShareSheet(text: text, method: method, eventId: eventId)

        case "openNaverMap":
            guard let address = args[safe: 0]?.string,
                  let lat = args[safe: 1]?.number,
                  let lng = args[safe: 2]?.number else {
                respondError(method: method, eventId: eventId); return
            }
            openNaverMap(address: address, lat: lat, lng: lng, method: method, eventId: eventId)

        default:
            break
        }
    }

    private func handleReissueToken(method: String, eventId: String) {
        Task { @MainActor in
            do {
                let result = try await AuthManager.shared.reissue()
                self.respondObject(method: method, eventId: eventId, value: [
                    "accessToken": result.accessToken
                ])
            } catch {
                self.respondObject(method: method, eventId: eventId, value: [
                    "success": false,
                    "message": error.localizedDescription
                ])
            }
        }
    }

    private func showShareSheet(text: String, method: String, eventId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let vc = self?.viewController else { return }
            let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            activity.completionWithItemsHandler = { [weak self] _, _, _, _ in
                self?.respondVoid(method: method, eventId: eventId)
            }
            vc.present(activity, animated: true)
        }
    }

    private func openNaverMap(address: String, lat: Double, lng: Double, method: String, eventId: String) {
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
            self?.respondVoid(method: method, eventId: eventId)
        }
    }
}
