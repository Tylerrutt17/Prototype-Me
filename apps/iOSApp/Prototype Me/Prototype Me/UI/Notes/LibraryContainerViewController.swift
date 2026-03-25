import UIKit

/// Container VC with sub-tab bar that switches between Notes, Directives, and Balloons.
final class LibraryContainerViewController: BaseViewController {

    // MARK: - Child VCs (set by coordinator)

    var notesVC: UIViewController?
    var directivesVC: UIViewController?
    var balloonsVC: UIViewController?

    // MARK: - Callbacks (set by coordinator)

    var onAddNoteTapped: (() -> Void)?
    var onAddFolderTapped: (() -> Void)?
    var onAddDirectiveTapped: (() -> Void)?

    // MARK: - UI

    private let segmentedControl = UISegmentedControl(items: ["Notes", "Directives", "Balloons"])
    private let containerView = UIView()
    private var currentChild: UIViewController?
    private var currentIndex = 0

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle("Library", animated: false)

        setupSegmentedControl()
        setupContainer()
        showChild(at: 0, animated: false)
    }

    private func setupSegmentedControl() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: contentTopAnchor, constant: DesignTokens.Spacing.sm),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    private func setupContainer() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: DesignTokens.Spacing.sm),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    @objc private func segmentChanged() {
        showChild(at: segmentedControl.selectedSegmentIndex, animated: true)
    }

    private func showChild(at index: Int, animated: Bool) {
        currentIndex = index

        let vc: UIViewController?
        switch index {
        case 0: vc = notesVC
        case 1: vc = directivesVC
        case 2: vc = balloonsVC
        default: return
        }

        guard let child = vc, child !== currentChild else { return }
        let old = currentChild

        // Add new child
        addChild(child)
        child.view.frame = containerView.bounds
        child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.addSubview(child.view)
        child.didMove(toParent: self)

        if animated {
            child.view.alpha = 0
            UIView.animate(withDuration: 0.2) {
                child.view.alpha = 1
                old?.view.alpha = 0
            } completion: { _ in
                old?.willMove(toParent: nil)
                old?.view.removeFromSuperview()
                old?.removeFromParent()
                old?.view.alpha = 1
            }
        } else {
            old?.willMove(toParent: nil)
            old?.view.removeFromSuperview()
            old?.removeFromParent()
        }

        currentChild = child
        updateNavButtons(for: index)

        // Reset balloon animations when switching to balloons tab
        if index == 2, let balloons = child as? BalloonsViewController {
            balloons.refreshAnimations()
        }
    }

    // MARK: - Dynamic Nav Buttons

    private func updateNavButtons(for index: Int) {
        switch index {
        case 0:
            navBar.setRightButtons([
                NavBarButton(systemImage: "folder.badge.plus", action: { [weak self] in self?.onAddFolderTapped?() }),
                NavBarButton(systemImage: "plus", action: { [weak self] in self?.onAddNoteTapped?() }),
            ])
        case 1:
            navBar.setRightButtons([
                NavBarButton(systemImage: "plus", action: { [weak self] in self?.onAddDirectiveTapped?() }),
            ])
        case 2:
            navBar.setRightButtons([])
        default:
            break
        }
    }

    private func showNotesAddMenu() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "New Note", style: .default) { [weak self] _ in
            self?.onAddNoteTapped?()
        })
        sheet.addAction(UIAlertAction(title: "New Folder", style: .default) { [weak self] _ in
            self?.onAddFolderTapped?()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }
}
