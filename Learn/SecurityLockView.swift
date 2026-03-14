import SwiftUI
import LocalAuthentication
import os

struct SecurityLockView: View {
    private static let logger = Logger(subsystem: "com.MCCANN.Border", category: "SecurityLockView")
    @Binding var isUnlocked: Bool
    @State private var authenticationError: String?

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
    }

    private func authenticate() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Unlock BorderLog to access your travel data."
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        self.isUnlocked = true
                        self.authenticationError = nil
                    } else {
                        self.isUnlocked = false
                        if let authError = authError {
                            Self.logger.error("Authentication failed: \(authError, privacy: .private)")
                        }
                        self.authenticationError = "Authentication failed. Please try again."
                    }
                }
            }
        } else {
            // Fallback for missing biometrics setup
            let fallbackReason = "Unlock BorderLog."
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: fallbackReason) { success, authError in
                    DispatchQueue.main.async {
                        if success {
                            self.isUnlocked = true
                            self.authenticationError = nil
                        } else {
                            self.isUnlocked = false
                            if let authError = authError {
                                Self.logger.error("Authentication failed: \(authError, privacy: .private)")
                            }
                            self.authenticationError = "Authentication failed. Please try again."
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isUnlocked = false
                    self.authenticationError = "Biometrics and device passcode are unavailable."
                }
            }
        }
    }
}
