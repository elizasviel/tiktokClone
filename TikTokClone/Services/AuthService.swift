import Foundation
import Firebase
import FirebaseAuth

class AuthService: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    
    static let shared = AuthService()
    
    init() {
        self.userSession = Auth.auth().currentUser
    }
    
    func createUser(email: String, password: String, username: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.userSession = result.user
            
            // Create user profile in Firestore
            let userData: [String: Any] = [
                "email": email,
                "username": username,
                "id": result.user.uid,
                "dateJoined": Timestamp()
            ]
            
            try await Firestore.firestore().collection("users").document(result.user.uid).setData(userData)
        } catch {
            print("DEBUG: Failed to create user with error: \(error.localizedDescription)")
            throw error
        }
    }
    
    func signIn(withEmail email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = result.user
        } catch {
            print("DEBUG: Failed to sign in with error: \(error.localizedDescription)")
            throw error
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
        } catch {
            print("DEBUG: Failed to sign out with error: \(error.localizedDescription)")
        }
    }
    
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        
        do {
            // Delete user data from Firestore
            try await Firestore.firestore().collection("users").document(user.uid).delete()
            
            // Delete the user account
            try await user.delete()
            
            // Set userSession to nil
            self.userSession = nil
        } catch {
            print("DEBUG: Failed to delete account with error: \(error.localizedDescription)")
            throw error
        }
    }
} 