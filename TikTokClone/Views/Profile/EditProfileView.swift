import SwiftUI
import FirebaseFirestore

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @State private var username = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Information") {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section {
                    Button("Save Changes") {
                        Task {
                            await updateProfile()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                username = authService.currentUser?.username ?? ""
            }
            .alert("Profile Update", isPresented: $showAlert) {
                Button("OK") { 
                    if alertMessage.contains("successfully") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func updateProfile() async {
        guard let uid = authService.userSession?.uid,
              !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "Please enter a valid username"
            showAlert = true
            return
        }
        
        do {
            let data = ["username": username]
            try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .updateData(data)
            
            // Update local user data
            if var currentUser = authService.currentUser {
                currentUser = User(
                    id: currentUser.id,
                    username: username,
                    email: currentUser.email,
                    dateJoined: currentUser.dateJoined
                )
                await MainActor.run {
                    authService.currentUser = currentUser
                }
            }
            
            alertMessage = "Profile updated successfully!"
            showAlert = true
        } catch {
            alertMessage = "Error updating profile: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

#Preview {
    EditProfileView()
} 