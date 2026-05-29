import SwiftUI
import LocalAuthentication

struct LockScreenView: View {
    let onUnlock: () -> Void
    @State private var biometryType: LABiometryType = .none

    private var biometricIcon: String { biometryType == .faceID ? "faceid" : "touchid" }
    private var biometricLabel: String { biometryType == .faceID ? "Face ID 解锁" : "Touch ID 解锁" }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 28) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)

                VStack(spacing: 8) {
                    Text("碎片已锁定")
                        .font(.title2).fontWeight(.semibold)
                    Text("需要验证身份才能继续")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button { authenticate() } label: {
                    Label(biometricLabel, systemImage: biometricIcon)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
        }
        .onAppear {
            let ctx = LAContext()
            _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            biometryType = ctx.biometryType
            authenticate()
        }
    }

    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "解锁碎片") { success, _ in
            DispatchQueue.main.async {
                if success { onUnlock() }
            }
        }
    }
}
