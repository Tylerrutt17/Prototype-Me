import SwiftUI

struct LockScreen: View {
    @EnvironmentObject private var lockManager: LockManager
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundStyle(.secondary)
            Text("Unlock PrototypeMe")
                .font(.title2.bold())
            Button("Use Face ID") {
                lockManager.unlockWithBiometrics()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    LockScreen()
        .environmentObject(LockManager())
}
