import Foundation
import FirebaseAuth
import Combine

@MainActor
final class AuthManager: ObservableObject {
    @Published var isAnonymous: Bool = true
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: FirebaseAuth.User?
    
    static let shared = AuthManager()

    private init() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            self.currentUser = user
            self.isAnonymous = user?.isAnonymous ?? true
            self.isAuthenticated = user != nil && !(user?.isAnonymous ?? true)
            
            if user == nil {
                self.signInAnonymously()
            }
        }
    }
    
    private func signInAnonymously() {
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error {
                print("Error signing in anonymously: \(error.localizedDescription)")
            } else {
                print("Signed in anonymously with uid: \(authResult?.user.uid ?? "")")
            }
        }
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
