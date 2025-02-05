import SwiftUI
import FirebaseAuth
import Kingfisher
import PhotosUI
import FirebaseStorage
import FirebaseFirestore
import UIKit

struct ProfileView: View {
    @StateObject var authService = AuthService.shared
    @StateObject var videoService = VideoService.shared
    @State private var showDeleteConfirmation = false
    @State private var userVideos: [Video] = []
    @State private var selectedTab = 0
    @State private var showEditProfile = false
    @State private var showImagePicker = false
    @State private var profileImage: UIImage?
    @State private var isLoading = false
    
    private var currentUser: User? {
        authService.currentUser
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    VStack(spacing: 16) {
                        // Profile Image with edit button
                        ZStack(alignment: .bottomTrailing) {
                            Button(action: { showImagePicker = true }) {
                                if let profileImageUrl = currentUser?.profileImageUrl,
                                   let url = URL(string: profileImageUrl) {
                                    KFImage(url)
                                        .resizable()
                                        .placeholder {
                                            Circle()
                                                .fill(Color.gray.opacity(0.2))
                                                .overlay(
                                                    Image(systemName: "person.fill")
                                                        .font(.system(size: 40))
                                                        .foregroundColor(.gray)
                                                )
                                        }
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 3)
                                        )
                                        .shadow(radius: 3)
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 3)
                                        )
                                        .shadow(radius: 3)
                                }
                            }
                            
                            Image(systemName: "camera.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        
                        // User Info with Shimmer Effect
                        VStack(spacing: 4) {
                            if isLoading {
                                ShimmerView()
                                    .frame(width: 150, height: 24)
                            } else {
                                Text("@\(currentUser?.username ?? "user")")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            Text(currentUser?.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Text("Member since \(formatDate(currentUser?.dateJoined.dateValue() ?? Date()))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // Enhanced Stats Row
                        HStack(spacing: 40) {
                            StatView(value: userVideos.count, title: "Posts", icon: "video.fill")
                            StatView(value: 0, title: "Followers", icon: "person.2.fill")
                            StatView(value: 0, title: "Following", icon: "person.3.fill")
                        }
                        .padding(.vertical)
                    }
                    .padding()
                    
                    // Edit Profile Button
                    Button(action: { showEditProfile = true }) {
                        Text("Edit Profile")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    // Enhanced Content Tabs
                    CustomTabView(selectedTab: $selectedTab, userVideos: userVideos)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        ActionButton(title: "Sign Out", icon: "rectangle.portrait.and.arrow.right", color: .blue) {
                            authService.signOut()
                        }
                        
                        ActionButton(title: "Delete Account", icon: "trash", color: .red) {
                            showDeleteConfirmation = true
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await fetchUserVideos()
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $profileImage)
                    .onChange(of: profileImage) { newImage in
                        if let image = newImage {
                            Task {
                                await uploadProfileImage(image)
                            }
                        }
                    }
            }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        try? await authService.deleteAccount()
                    }
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
            .task {
                await fetchUserVideos()
            }
        }
    }
    
    private func uploadProfileImage(_ image: UIImage) async {
        isLoading = true
        defer { isLoading = false }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8),
              let uid = authService.userSession?.uid else { return }
        
        do {
            // Upload image to Firebase Storage
            let storageRef = Storage.storage().reference().child("profile_images/\(uid).jpg")
            let _ = try await storageRef.putDataAsync(imageData)
            let url = try await storageRef.downloadURL()
            
            // Update user profile in Firestore
            try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .updateData(["profileImageUrl": url.absoluteString])
            
            // Update local user data
            if var updatedUser = authService.currentUser {
                updatedUser = User(
                    id: updatedUser.id,
                    username: updatedUser.username,
                    email: updatedUser.email,
                    dateJoined: updatedUser.dateJoined,
                    profileImageUrl: url.absoluteString
                )
                await MainActor.run {
                    authService.currentUser = updatedUser
                }
            }
        } catch {
            print("DEBUG: Failed to upload profile image with error: \(error.localizedDescription)")
        }
    }
    
    private func fetchUserVideos() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        userVideos = videoService.videos.filter { $0.userId == uid }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// Supporting Views
struct StatView: View {
    let value: Int
    let title: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
            Text("\(value)")
                .font(.headline)
                .fontWeight(.bold)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? .primary : .gray)
                
                Rectangle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct VideosGridView: View {
    let videos: [Video]
    let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)
    
    var body: some View {
        if videos.isEmpty {
            Text("No videos yet")
                .foregroundColor(.gray)
                .padding()
        } else {
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(videos) { video in
                    VideoThumbnail(video: video)
                        .frame(height: UIScreen.main.bounds.width / 3)
                }
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .cornerRadius(10)
        }
    }
}

struct VideoThumbnail: View {
    let video: Video
    
    var body: some View {
        ZStack {
            if let thumbnailUrl = video.thumbnailUrl,
               let url = URL(string: thumbnailUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "play.fill")
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(height: 120)
        .clipped()
    }
}

struct ShimmerView: View {
    @State private var isAnimating = false
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [.gray.opacity(0.2), .gray.opacity(0.3), .gray.opacity(0.2)]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask(Rectangle())
        .offset(x: isAnimating ? 400 : -200)
        .onAppear {
            withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

struct CustomTabView: View {
    @Binding var selectedTab: Int
    let userVideos: [Video]
    
    var body: some View {
        VStack {
            HStack {
                TabButton(title: "Videos", isSelected: selectedTab == 0) {
                    withAnimation { selectedTab = 0 }
                }
                
                TabButton(title: "Liked", isSelected: selectedTab == 1) {
                    withAnimation { selectedTab = 1 }
                }
            }
            .padding(.horizontal)
            
            TabView(selection: $selectedTab) {
                VideosGridView(videos: userVideos)
                    .tag(0)
                
                LikedVideosView()
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: UIScreen.main.bounds.height * 0.5)
        }
    }
}