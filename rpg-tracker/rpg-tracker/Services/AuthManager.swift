import Foundation
import FirebaseAuth
import Combine

@MainActor
final class AuthManager: ObservableObject {
    @Published var isAnonymous: Bool = true
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: FirebaseAuth.User?
    @Published var authError: String? = nil
    @Published var isConnecting: Bool = true
    
    static let shared = AuthManager()

    private init() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            self.currentUser = user
            self.isAnonymous = user?.isAnonymous ?? true
            self.isAuthenticated = user != nil && !(user?.isAnonymous ?? true)
            
            if user != nil {
                self.isConnecting = false
                self.authError = nil
            } else {
                self.signInAnonymously()
            }
        }
    }
    
    private func signInAnonymously() {
        isConnecting = true
        Auth.auth().signInAnonymously { [weak self] authResult, error in
            guard let self = self else { return }
            if let error = error {
                print("Error signing in anonymously: \(error.localizedDescription)")
                self.isConnecting = false
                self.authError = error.localizedDescription
            } else {
                print("Signed in anonymously with uid: \(authResult?.user.uid ?? "")")
                self.isConnecting = false
                self.authError = nil
            }
        }
    }

    func retryAnonymousSignIn() {
        authError = nil
        signInAnonymously()
    }

    var currentUserEmail: String? {
        currentUser?.email
    }

    func deleteCurrentUser() async throws {
        try await currentUser?.delete()
        self.currentUser = nil
    }

    func signOut() async throws {
        try Auth.auth().signOut()
        self.currentUser = nil
        // A new anonymous user will be created by the state listener since currentUser is nil
    }
}
