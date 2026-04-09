import UIKit

final class SplashViewController: UIViewController {

    var onFinished: (() -> Void)?

    private let iconImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "SplashIcon"))
        iv.contentMode = .scaleAspectFit
        iv.layer.cornerRadius = 24
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Prototype Me"
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textColor = DesignTokens.Colors.textPrimary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignTokens.Colors.background

        view.addSubview(iconImageView)
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            iconImageView.widthAnchor.constraint(equalToConstant: 100),
            iconImageView.heightAnchor.constraint(equalToConstant: 100),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            UIView.animate(withDuration: 0.3, animations: {
                self?.view.alpha = 0
            }, completion: { _ in
                self?.onFinished?()
            })
        }
    }
}
