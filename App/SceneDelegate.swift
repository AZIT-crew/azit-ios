import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    private static let splashDuration: TimeInterval = 2.0

    var window: UIWindow?
    private var webViewController: WebViewController?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let policy = WebPolicy.app
        let startURL = initialURL(from: connectionOptions, policy: policy) ?? policy.baseURL
        let viewController = WebViewController(policy: policy, startURL: startURL)
        webViewController = viewController

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = SplashViewController()
        window.makeKeyAndVisible()
        self.window = window

        // 스플래시를 잠시 보여준 뒤 웹뷰로 전환해요
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.splashDuration) { [weak window] in
            guard let window else { return }
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
                window.rootViewController = viewController
            }
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url, let target = WebPolicy.app.webURL(fromDeepLink: url) else { return }
        webViewController?.load(target)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL,
              WebPolicy.app.decide(for: url) == .loadInApp else { return }
        webViewController?.load(url)
    }

    private func initialURL(from options: UIScene.ConnectionOptions, policy: WebPolicy) -> URL? {
        if let url = options.urlContexts.first?.url {
            return policy.webURL(fromDeepLink: url)
        }
        if let url = options.userActivities.first?.webpageURL, policy.decide(for: url) == .loadInApp {
            return url
        }
        return nil
    }
}
