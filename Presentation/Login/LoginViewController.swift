import AuthenticationServices
import UIKit

final class LoginViewController: UIViewController {

    private enum Palette {
        static let light = UIColor(red: 0x00 / 255, green: 0x34 / 255, blue: 0x83 / 255, alpha: 1)
        static let dark = UIColor(red: 0x00 / 255, green: 0x0B / 255, blue: 0x1D / 255, alpha: 1)
    }

    private var webAuthSession: ASWebAuthenticationSession?
    private let gradientLayer = CAGradientLayer()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.attributedText = NSAttributedString(
            string: "AZIT",
            attributes: [
                .font: UIFont(name: "TiltWarp-Regular", size: 64) ?? .systemFont(ofSize: 64, weight: .heavy),
                .foregroundColor: UIColor.white,
                .kern: 2.5
            ]
        )
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "러닝 크루를 위한 운영 & 제휴 서비스"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let largeShape: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "SplashShapeLarge"))
        imageView.contentMode = .scaleToFill
        imageView.alpha = 0.4
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let smallShape: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "SplashShapeSmall"))
        imageView.contentMode = .scaleToFill
        imageView.alpha = 0.6
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let kakaoButton: UIButton = {
        let kakaoLogo = UIImage(named: "KakaoLogo")?.withRenderingMode(.alwaysOriginal)

        var titleAttributes = AttributeContainer()
        titleAttributes.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleAttributes.foregroundColor = UIColor(white: 0, alpha: 0.85)

        var config = UIButton.Configuration.filled()
        config.image = kakaoLogo
        config.imagePadding = 8
        config.imagePlacement = .leading
        config.attributedTitle = AttributedString("카카오로 로그인", attributes: titleAttributes)
        config.baseBackgroundColor = UIColor(red: 254 / 255, green: 229 / 255, blue: 0, alpha: 1)
        config.baseForegroundColor = UIColor(white: 0, alpha: 0.85)
        config.background.cornerRadius = 12
        config.cornerStyle = .fixed
        return UIButton(configuration: config)
    }()

    private let appleButton: ASAuthorizationAppleIDButton = {
        let button = ASAuthorizationAppleIDButton(
            authorizationButtonType: .signIn,
            authorizationButtonStyle: .white
        )
        button.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.color = .white
        return indicator
    }()

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.light
        setupGradient()
        setupLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    private func setupGradient() {
        gradientLayer.colors = [Palette.light.cgColor, Palette.dark.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        view.layer.insertSublayer(gradientLayer, at: 0)
    }

    private func setupLayout() {
        kakaoButton.addAction(UIAction { [weak self] _ in self?.startKakaoLogin() }, for: .touchUpInside)
        appleButton.addTarget(self, action: #selector(startAppleLogin), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [kakaoButton, appleButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        kakaoButton.translatesAutoresizingMaskIntoConstraints = false

        [largeShape, smallShape, titleLabel, subtitleLabel, buttonStack, loadingIndicator]
            .forEach(view.addSubview)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: -3),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 280),

            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),

            largeShape.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 96.85),
            largeShape.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 31.5),
            largeShape.widthAnchor.constraint(equalToConstant: 374.3),
            largeShape.heightAnchor.constraint(equalToConstant: 330.1),

            smallShape.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 216.87),
            smallShape.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 29.5),
            smallShape.widthAnchor.constraint(equalToConstant: 134.26),
            smallShape.heightAnchor.constraint(equalToConstant: 233.77),

            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            kakaoButton.heightAnchor.constraint(equalToConstant: 52),
            appleButton.heightAnchor.constraint(equalToConstant: 52),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func startKakaoLogin() {
        guard let kakaoURL = buildKakaoOAuthURL() else { return }
        setLoading(true)

        let session = ASWebAuthenticationSession(
            url: kakaoURL,
            callbackURLScheme: "azit"
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                self?.setLoading(false)
                guard error == nil,
                      let url = callbackURL,
                      let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value
                else { return }
                await self?.handleLogin(provider: .kakao, code: code)
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        webAuthSession = session
        session.start()
    }

    private func buildKakaoOAuthURL() -> URL? {
        var components = URLComponents(string: "https://kauth.kakao.com/oauth/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: AppConfig.kakaoAppKey),
            URLQueryItem(name: "redirect_uri", value: AppConfig.kakaoRedirectURI),
            URLQueryItem(name: "response_type", value: "code")
        ]
        return components?.url
    }

    @objc private func startAppleLogin() {
        setLoading(true)
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    private func handleLogin(provider: AuthProvider, code: String) async {
        setLoading(true)
        do {
            let result = try await AuthManager.shared.login(provider: provider, authorizationCode: code)
            setLoading(false)
            transitionToWebView(authResult: result)
        } catch {
            setLoading(false)
            showError("로그인에 실패했습니다. 다시 시도해 주세요.")
        }
    }

    private func transitionToWebView(authResult: AuthResult) {
        guard let window = view.window else { return }
        let vc = WebViewController.makeForApp(accessToken: authResult.accessToken, authStatus: authResult.status)
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = vc
        }
    }

    private func setLoading(_ loading: Bool) {
        view.isUserInteractionEnabled = !loading
        if loading {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}

extension LoginViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        view.window ?? UIWindow()
    }
}

extension LoginViewController: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let codeData = credential.authorizationCode,
              let code = String(data: codeData, encoding: .utf8) else {
            setLoading(false)
            showError("애플 로그인에 실패했습니다.")
            return
        }
        Task { await handleLogin(provider: .apple, code: code) }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        setLoading(false)
        if let authError = error as? ASAuthorizationError, authError.code == .canceled { return }
        showError("애플 로그인에 실패했습니다.")
    }
}

extension LoginViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        view.window ?? UIWindow()
    }
}
