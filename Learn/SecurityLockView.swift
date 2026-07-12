import SwiftUI
import LocalAuthentication
import os

struct SecurityLockView: View {
    private let logger = Logger(subsystem: "com.MCCANN.Border", category: "Security")

    @Binding var isUnlocked: Bool
    let canAuthenticate: Bool
    @State private var authenticationError: String?
    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                Button {
                    authenticate()
                } label: {
                    Label("Retry Biometrics", systemImage: "faceid")
                        .font(.headline)
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!canAuthenticate || isAuthenticating)

                if let error = authenticationError {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.top)
                }
            }
        }
        .onAppear {
            authenticate()
        }
        .onChange(of: canAuthenticate) { _, canAuthenticate in
            if canAuthenticate {
                authenticate()
            }
        }
    }

    private func authenticate() {
        guard canAuthenticate, !isAuthenticating else { return }
        isAuthenticating = true

        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Unlock BorderLog to access your travel data."
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                let wasNeutrallyCancelled = isNeutralAuthenticationCancellation(authError)
                if let authError, !wasNeutrallyCancelled {
                    self.logger.error("Device authentication failed: \(authError, privacy: .private)")
                }
                DispatchQueue.main.async {
                    self.isAuthenticating = false
                    if success {
                        self.isUnlocked = true
                        self.authenticationError = nil
                    } else if wasNeutrallyCancelled {
                        self.isUnlocked = false
                        self.authenticationError = nil
                    } else {
                        self.isUnlocked = false
                        self.authenticationError = "Authentication failed. Please try again."
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                self.isAuthenticating = false
                self.isUnlocked = false
                self.authenticationError = "Biometrics and device passcode are unavailable."
            }
        }
    }
}

func isNeutralAuthenticationCancellation(_ error: Error?) -> Bool {
    guard let error else { return false }

    let nsError = error as NSError
    guard nsError.domain == LAError.errorDomain,
          let code = LAError.Code(rawValue: nsError.code) else {
        return false
    }

    return code == .appCancel || code == .systemCancel
}
