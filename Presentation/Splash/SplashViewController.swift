import UIKit

/// 앱 시작 시 보여주는 스플래시 화면이에요.
/// 배경 그라데이션이 파랑↔남색으로 오가며 움직여요.
final class SplashViewController: UIViewController {

    private enum Palette {
        static let light = UIColor(red: 0x00 / 255, green: 0x34 / 255, blue: 0x83 / 255, alpha: 1) // #003483
        static let dark = UIColor(red: 0x00 / 255, green: 0x0B / 255, blue: 0x1D / 255, alpha: 1) // #000B1D
    }

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

    private let largeShape = SplashViewController.makeShape(named: "SplashShapeLarge")
    private let smallShape = SplashViewController.makeShape(named: "SplashShapeSmall")

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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startGradientAnimation()
    }

    // MARK: - Setup

    private func setupGradient() {
        gradientLayer.colors = [Palette.light.cgColor, Palette.dark.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        view.layer.insertSublayer(gradientLayer, at: 0)
    }

    private func setupLayout() {
        [titleLabel, subtitleLabel, largeShape, smallShape].forEach(view.addSubview)

        // Figma 기준 375x812. 도형은 화면 하단 기준으로 배치해요.
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
            smallShape.heightAnchor.constraint(equalToConstant: 233.77)
        ])
    }

    private static func makeShape(named name: String) -> UIImageView {
        let imageView = UIImageView(image: UIImage(named: name))
        imageView.contentMode = .scaleToFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }

    // MARK: - Animation

    /// 위→아래 그라데이션의 색 순서를 뒤집었다가 되돌리며 반복해요.
    private func startGradientAnimation() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        let animation = CABasicAnimation(keyPath: "colors")
        animation.fromValue = [Palette.light.cgColor, Palette.dark.cgColor]
        animation.toValue = [Palette.dark.cgColor, Palette.light.cgColor]
        animation.duration = 2.0
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradientLayer.add(animation, forKey: "gradientColors")
    }
}
