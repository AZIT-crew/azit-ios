import UIKit
import WebKit

final class WebViewController: UIViewController {

    private let policy: WebPolicy
    private let startURL: URL
    private var webView: WKWebView!

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

    init(policy: WebPolicy, startURL: URL) {
        self.policy = policy
        self.startURL = startURL
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupWebView()
        setupErrorView()
        load(startURL)
    }

    func load(_ url: URL) {
        hideError()
        webView.load(URLRequest(url: url))
    }

    // MARK: - Setup

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        // 웹이 UA로 앱 여부를 판별할 수 있게 앱 이름을 붙여요
        config.applicationNameForUserAgent = "AZIT iOS"
        config.allowsInlineMediaPlayback = true

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        // 상·하단 safe area를 풀고 웹이 viewport-fit=cover + env(safe-area-inset-*)로 처리해요
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.translatesAutoresizingMaskIntoConstraints = false
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
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

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
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
        // 정책으로 취소한 네비게이션(-999, WebKit 102)도 실패로 들어와서 걸러야 해요
        let isCancelled = (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled)
            || (nsError.domain == "WebKitErrorDomain" && nsError.code == 102)
        if !isCancelled {
            showError()
        }
    }
}

// MARK: - WKUIDelegate

extension WebViewController: WKUIDelegate {

    // target=_blank 링크는 새 창을 만들지 않고 같은 웹뷰에서 정책대로 처리해요
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
