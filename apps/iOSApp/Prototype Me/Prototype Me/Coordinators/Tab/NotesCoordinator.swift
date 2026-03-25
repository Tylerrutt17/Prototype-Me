import UIKit
import GRDB

class NotesCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    let navigationController: UINavigationController
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        self.navigationController = UINavigationController()
        navigationController.tabBarItem = UITabBarItem(
            title: "Library",
            image: UIImage(systemName: "books.vertical"),
            selectedImage: UIImage(systemName: "books.vertical.fill")
        )
    }

    func start() {
        let container = LibraryContainerViewController()
        container.dbQueue = environment.db.dbQueue

        // Notes sub-tab
        let notesVC = makeNoteListVC(folderId: nil, folderName: nil)
        notesVC.isEmbedded = true
        container.notesVC = notesVC

        // Directives sub-tab
        let directivesVC = makeDirectiveListVC()
        directivesVC.isEmbedded = true
        container.directivesVC = directivesVC

        // Balloons sub-tab
        let balloonsVC = makeBalloonsVC()
        balloonsVC.isEmbedded = true
        container.balloonsVC = balloonsVC

        // Container nav button callbacks
        container.onAddNoteTapped = { [weak self] in
            self?.presentNoteEditor(noteId: nil, folderId: nil)
        }
        container.onAddFolderTapped = { [weak self] in
            self?.presentFolderEditor(folderId: nil, parentFolderId: nil)
        }
        container.onAddDirectiveTapped = { [weak self] in
            self?.presentDirectiveEditor(directiveId: nil)
        }

        navigationController.viewControllers = [container]
    }

    private func makeDirectiveListVC() -> DirectiveListViewController {
        let vc = DirectiveListViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.directiveService = environment.directiveService
        vc.onDirectiveSelected = { [weak self] directiveId in
            self?.showDirectiveDetail(directiveId: directiveId)
        }
        vc.onAddTapped = { [weak self] in
            self?.presentDirectiveEditor(directiveId: nil)
        }
        return vc
    }

    private func makeBalloonsVC() -> BalloonsViewController {
        let vc = BalloonsViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.onDirectiveSelected = { [weak self] directiveId in
            self?.showDirectiveDetail(directiveId: directiveId)
        }
        return vc
    }

    // MARK: - Note List (reusable for any folder level)

    private func makeNoteListVC(folderId: UUID?, folderName: String?) -> NoteListViewController {
        let vc = NoteListViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.noteService = environment.noteService
        vc.folderService = environment.folderService
        vc.currentFolderId = folderId
        vc.folderName = folderName
        vc.onNoteSelected = { [weak self] noteId in
            self?.routeToNote(noteId: noteId)
        }
        vc.onEditNoteTapped = { [weak self] noteId in
            self?.presentNoteEditor(noteId: noteId, folderId: nil)
        }
        vc.onFolderSelected = { [weak self] folderId in
            self?.pushFolder(folderId: folderId)
        }
        vc.onEditFolderTapped = { [weak self] folderId in
            self?.presentFolderEditor(folderId: folderId, parentFolderId: nil)
        }
        vc.onAddNoteTapped = { [weak self] in
            self?.presentNoteEditor(noteId: nil, folderId: folderId)
        }
        vc.onAddFolderTapped = { [weak self] in
            self?.presentFolderEditor(folderId: nil, parentFolderId: folderId)
        }
        return vc
    }

    // MARK: - Folder Navigation

    private func pushFolder(folderId: UUID) {
        let name = try? environment.db.dbQueue.read { db in
            try Folder.fetchOne(db, key: folderId)?.name
        }
        let vc = makeNoteListVC(folderId: folderId, folderName: name)
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - Note Routing

    private func routeToNote(noteId: UUID) {
        let kind = try? environment.db.dbQueue.read { db in
            try NotePage.fetchOne(db, key: noteId)?.kind
        }
        if kind == .mode {
            showModeDetail(noteId: noteId)
        } else {
            showNoteDetail(noteId: noteId)
        }
    }

    private func showNoteDetail(noteId: UUID) {
        let vc = NoteDetailViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.noteService = environment.noteService
        vc.noteId = noteId
        vc.onDirectiveSelected = { [weak self] directiveId in
            self?.showDirectiveDetail(directiveId: directiveId)
        }
        vc.onEditTapped = { [weak self] noteId in
            self?.presentNoteEditor(noteId: noteId, folderId: nil)
        }
        vc.onLinkDirectiveTapped = { [weak self] noteId in
            self?.presentDirectivePicker(forNoteId: noteId)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    private func showModeDetail(noteId: UUID) {
        let vc = ModeDetailViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.noteId = noteId
        vc.onDirectiveSelected = { [weak self] directiveId in
            self?.showDirectiveDetail(directiveId: directiveId)
        }
        vc.onEditTapped = { [weak self] noteId in
            self?.presentNoteEditor(noteId: noteId, folderId: nil)
        }
        vc.onLinkDirectiveTapped = { [weak self] noteId in
            self?.presentDirectivePicker(forNoteId: noteId)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - Directives

    private func showDirectiveList() {
        let vc = DirectiveListViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.directiveService = environment.directiveService
        vc.onDirectiveSelected = { [weak self] directiveId in
            self?.showDirectiveDetail(directiveId: directiveId)
        }
        vc.onAddTapped = { [weak self] in
            self?.presentDirectiveEditor(directiveId: nil)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    private func showDirectiveDetail(directiveId: UUID) {
        let vc = DirectiveDetailViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.directiveId = directiveId
        vc.onEditTapped = { [weak self] directiveId in
            self?.presentDirectiveEditor(directiveId: directiveId)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    private func showBalloons() {
        let vc = BalloonsViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.onDirectiveSelected = { [weak self] directiveId in
            self?.showDirectiveDetail(directiveId: directiveId)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - Modal Editors

    private func presentNoteEditor(noteId: UUID?, folderId: UUID?) {
        let editor = NoteEditorViewController()
        editor.dbQueue = environment.db.dbQueue
        editor.noteService = environment.noteService
        editor.noteId = noteId
        // If creating a new note inside a folder, set the folderId
        if noteId == nil, let folderId {
            editor.preselectedFolderId = folderId
        }
        editor.onSave = { [weak self] in
            self?.navigationController.dismiss(animated: true)
        }
        let nav = UINavigationController(rootViewController: editor)
        navigationController.present(nav, animated: true)
    }

    private func presentFolderEditor(folderId: UUID?, parentFolderId: UUID?) {
        let editor = PlaybookEditorViewController()
        editor.dbQueue = environment.db.dbQueue
        editor.folderService = environment.folderService
        editor.folderId = folderId
        editor.parentFolderId = parentFolderId
        editor.onSave = { [weak self] in
            self?.navigationController.dismiss(animated: true)
        }
        let nav = UINavigationController(rootViewController: editor)
        navigationController.present(nav, animated: true)
    }

    private func presentDirectiveEditor(directiveId: UUID?) {
        let editor = DirectiveEditorViewController()
        editor.dbQueue = environment.db.dbQueue
        editor.directiveService = environment.directiveService
        editor.directiveId = directiveId
        editor.onSave = { [weak self] in
            self?.navigationController.dismiss(animated: true)
        }
        let nav = UINavigationController(rootViewController: editor)
        navigationController.present(nav, animated: true)
    }

    private func presentDirectivePicker(forNoteId noteId: UUID) {
        let picker = DirectivePickerViewController()
        picker.dbQueue = environment.db.dbQueue
        picker.noteService = environment.noteService
        picker.directiveService = environment.directiveService
        picker.noteId = noteId
        picker.onDirectiveLinked = { [weak self] in
            self?.navigationController.dismiss(animated: true)
        }
        let nav = UINavigationController(rootViewController: picker)
        navigationController.present(nav, animated: true)
    }

}
