import LocalAuthentication
import Combine
import SwiftUI

final class LockManager: ObservableObject {
    @Published var isLocked: Bool
    
    @AppStorage("lockEnabled") private var lockEnabled: Bool = true {
        didSet {
            // If the user disables the lock, immediately unlock the app
            if !lockEnabled {
                DispatchQueue.main.async { [weak self] in
                    self?.isLocked = false
                }
            }
        }
    }
    
    var lockEnabledPublic: Bool { lockEnabled }

    // MARK: - Init
    init() {
        // Start locked only when the feature is enabled
        self.isLocked = UserDefaults.standard.bool(forKey: "lockEnabled")
    }
    
    private var lastUnlockDate: Date?
    
    // MARK: - Lock Handling
    func requireUnlock() {
        // If the lock feature is disabled, make sure we clear any existing lock state
        guard lockEnabled else {
            DispatchQueue.main.async { [weak self] in
                self?.isLocked = false
            }
            return
        }
        let now = Date()
        if let last = lastUnlockDate, now.timeIntervalSince(last) < 2 { return } // grace period
        DispatchQueue.main.async { [weak self] in
            self?.isLocked = true
        }
    }
    
    private func markUnlocked() {
        lastUnlockDate = Date()
        isLocked = false
    }
    
    /// Attempts to unlock the app with biometrics. Falls back to passcode-only auth automatically.
    func unlockWithBiometrics(reason: String = "Unlock PrototypeMe") {
        let context = LAContext()
        var error: NSError?
        let policy: LAPolicy = .deviceOwnerAuthentication
        guard context.canEvaluatePolicy(policy, error: &error) else {
            print("⚠️ Biometrics unavailable: \(error?.localizedDescription ?? "unknown")")
            return
        }
        context.evaluatePolicy(policy, localizedReason: reason) { [weak self] success, authError in
            DispatchQueue.main.async {
                if success {
                    self?.markUnlocked()
                } else {
                    print("⚠️ Authentication failed: \(authError?.localizedDescription ?? "unknown")")
                }
            }
        }
    }
}
