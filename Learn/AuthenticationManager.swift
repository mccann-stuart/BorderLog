import SwiftUI
import Combine

class AuthenticationManager: ObservableObject {
    // Temporary local-only mode. Flip to true to re-enable Apple Sign-In UI/flows.
    static let isAppleSignInEnabled = false

    @Published var appleUserId: String = ""
    
    private let service = "com.MCCANN.Learn"
    private let account = "appleUserId"

    init() {
        if let data = KeychainHelper.standard.read(service: service, account: account),
           let id = String(data: data, encoding: .utf8) {
            self.appleUserId = id
        }
    }

    func signIn(userId: String) {
        self.appleUserId = userId
        if let data = userId.data(using: .utf8) {
            KeychainHelper.standard.save(data, service: service, account: account)
        }
    }

    func signOut() {
        self.appleUserId = ""
        KeychainHelper.standard.delete(service: service, account: account)
    }
}
