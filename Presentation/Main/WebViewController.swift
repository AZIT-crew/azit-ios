import UIKit
import WebKit

final class WebViewController: UIViewController {

    private let policy: WebPolicy
    private let startURL: URL
    private let accessToken: String?
    private let authStatus: String?
    private var appBridge: AppBridge?

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private let errorContainerView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 16
        stackView.isHidden = true
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private var webView: WKWebView!

    init(policy: WebPolicy, startURL: URL, accessToken: String? = nil, authStatus: String? = nil) {
        self.policy = policy
        self.startURL = startURL
        self.accessToken = accessToken
        self.authStatus = authStatus
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func makeForApp(
        startURL: URL? = nil,
        accessToken: String?,
        authStatus: String?
    ) -> WebViewController {
        let policy = WebPolicy.app
        let url = startURL ?? policy.baseURL
        return WebViewController(policy: policy, startURL: url, accessToken: accessToken, authStatus: authStatus)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupWebView()
        setupErrorView()
        load(startURL)
    }

    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: AppBridge.handlerName)
    }

    func load(_ url: URL) {
        hideError()
        webView.load(URLRequest(url: url))
    }

    private func setupWebView() {
        let bridge = AppBridge(viewController: self)

        let config = WKWebViewConfiguration()
        config.applicationNameForUserAgent = "AZIT iOS"
        config.allowsInlineMediaPlayback = true
        config.userContentController.add(bridge, name: AppBridge.handlerName)
        config.userContentController.addUserScript(
            AppBridge.userScript(accessToken: accessToken, authStatus: authStatus)
        )

        webView = WKWebView(frame: .zero, configuration: config)
        bridge.webView = webView
        appBridge = bridge

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.translatesAutoresizingMaskIntoConstraints = false
        #if DEBUG
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        #endif

        view.addSubview(webView)
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupErrorView() {
        let label = UILabel()
        label.text = "페이지를 불러올 수 없습니다."
        label.font = .systemFont(ofSize: 16)

        var config = UIButton.Configuration.filled()
        config.title = "다시 시도"
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            guard let self else { return }
            self.hideError()
            if self.webView.url != nil {
                self.webView.reload()
            } else {
                self.load(self.startURL)
            }
        })

        errorContainerView.addArrangedSubview(label)
        errorContainerView.addArrangedSubview(button)
        view.addSubview(errorContainerView)
        NSLayoutConstraint.activate([
            errorContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func showError() {
        errorContainerView.isHidden = false
        webView.isHidden = true
    }

    private func hideError() {
        errorContainerView.isHidden = true
        webView.isHidden = false
    }
}

extension WebViewController: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel); return
        }
        switch policy.decide(for: url) {
        case .loadInApp:
            decisionHandler(.allow)
        case .openExternally:
            decisionHandler(.cancel)
            UIApplication.shared.open(url)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        hideError()
        activityIndicator.startAnimating()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleLoadFailure(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleLoadFailure(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    private func handleLoadFailure(_ error: Error) {
        activityIndicator.stopAnimating()
        let nsError = error as NSError
        let isCancelled = (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled)
            || (nsError.domain == "WebKitErrorDomain" && nsError.code == 102)
        if !isCancelled { showError() }
    }
}

extension WebViewController: WKUIDelegate {

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil, let url = navigationAction.request.url else { return nil }
        switch policy.decide(for: url) {
        case .loadInApp:
            webView.load(navigationAction.request)
        case .openExternally:
            UIApplication.shared.open(url)
        }
        return nil
    }
}
