import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    private static let splashDuration: TimeInterval = 2.0

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = SplashViewController()
        window.makeKeyAndVisible()
        self.window = window

        let deepLinkURL = connectionOptions.urlContexts.first?.url
        let universalLinkURL = connectionOptions.userActivities.first?.webpageURL

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Self.splashDuration * 1_000_000_000))
            await self.transitionAfterSplash(deepLinkURL: deepLinkURL, universalLinkURL: universalLinkURL)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        guard url.scheme?.lowercased() != "azit" || url.host?.lowercased() != "oauth" else { return }
        guard let target = WebPolicy.app.webURL(fromDeepLink: url),
              let webVC = currentWebViewController() else { return }
        webVC.load(target)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL,
              WebPolicy.app.decide(for: url) == .loadInApp,
              let webVC = currentWebViewController() else { return }
        webVC.load(url)
    }

    @MainActor
    private func transitionAfterSplash(deepLinkURL: URL?, universalLinkURL: URL?) async {
        let authResult = await AuthManager.shared.initialize()

        let rootVC: UIViewController
        if let result = authResult {
            let policy = WebPolicy.app
            var startURL = policy.baseURL
            if let deepLink = deepLinkURL, let url = policy.webURL(fromDeepLink: deepLink) {
                startURL = url
            } else if let url = universalLinkURL, policy.decide(for: url) == .loadInApp {
                startURL = url
            }
            rootVC = WebViewController.makeForApp(
                startURL: startURL,
                accessToken: result.accessToken,
                authStatus: result.status
            )
        } else {
            rootVC = LoginViewController()
        }

        guard let window else { return }
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = rootVC
        }
    }

    private func currentWebViewController() -> WebViewController? {
        window?.rootViewController as? WebViewController
    }
}
