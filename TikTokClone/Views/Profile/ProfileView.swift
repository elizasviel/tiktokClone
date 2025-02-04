import SwiftUI

struct ProfileView: View {
    @StateObject var viewModel = AuthService.shared
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack {
            // Profile header
            Text("Profile")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 20) {
                Button(action: {
                    viewModel.signOut()
                }) {
                    Text("Sign Out")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Text("Delete Account")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 50)
        }
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    try? await viewModel.deleteAccount()
                }
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
    }
} 