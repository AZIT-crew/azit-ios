import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

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
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        self.window = window
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
