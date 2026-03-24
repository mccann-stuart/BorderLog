import SwiftUI
import LocalAuthentication
import os

struct SecurityLockView: View {
    private let logger = Logger(subsystem: "com.MCCANN.Border", category: "SecurityLockView")

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

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Unlock BorderLog to access your travel data."
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                if let authError = authError {
                    self.logger.error("Device authentication failed: \(authError, privacy: .private)")
                }
                DispatchQueue.main.async {
                    if success {
                        self.isUnlocked = true
                        self.authenticationError = nil
                    } else {
                        self.isUnlocked = false
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
