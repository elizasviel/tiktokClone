import SwiftUI
import FirebaseAuth
import Kingfisher
import PhotosUI
import FirebaseStorage
import FirebaseFirestore
import UIKit
import AVFoundation

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
                    VStack(spacing: 15) {
                        // Profile Image with Edit Button
                        ZStack(alignment: .bottomTrailing) {
                            ProfileImageView(imageUrl: currentUser?.profileImageUrl)
                                .frame(width: 100, height: 100)
                            
                            Button(action: { showImagePicker = true }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.blue)
                                    .background(Color.white)
                                    .clipShape(Circle())
                            }
                            .offset(x: 5, y: 5)
                        }
                        
                        // Username and Email
                        VStack(spacing: 4) {
                            Text("@\(currentUser?.username ?? "user")")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(currentUser?.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        // Stats Row
                        HStack(spacing: 40) {
                            StatView(value: userVideos.count, title: "Posts")
                            StatView(value: 0, title: "Followers")
                            StatView(value: 0, title: "Following")
                        }
                        .padding(.vertical, 10)
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            Button(action: { showEditProfile = true }) {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text("Edit Profile")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            
                            Button(action: { authService.signOut() }) {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Sign Out")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top)
                    
                    // Content Tabs
                    VStack(spacing: 0) {
                        HStack {
                            TabButton(title: "Videos", icon: "play.square.fill", isSelected: selectedTab == 0) {
                                withAnimation { selectedTab = 0 }
                            }
                            TabButton(title: "Liked", icon: "heart.fill", isSelected: selectedTab == 1) {
                                withAnimation { selectedTab = 1 }
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                    }
                    
                    // Content View
                    TabView(selection: $selectedTab) {
                        VideosGridView(videos: userVideos)
                            .tag(0)
                        LikedVideosView()
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: UIScreen.main.bounds.height * 0.6)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                            Label("Delete Account", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.primary)
                    }
                }
            }
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
            
            // Update user profile in Firestore - Fix for Swift 6 data race
            await MainActor.run {
                Task {
                    try await Firestore.firestore()
                        .collection("users")
                        .document(uid)
                        .updateData(["profileImageUrl": url.absoluteString])
                }
            }
            
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

// Updated Supporting Views
struct ProfileImageView: View {
    let imageUrl: String?
    
    var body: some View {
        if let imageUrl = imageUrl,
           let url = URL(string: imageUrl) {
            KFImage(url)
                .resizable()
                .placeholder {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                        )
                }
                .aspectRatio(contentMode: .fill)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
        } else {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                )
        }
    }
}

struct StatView: View {
    let value: Int
    let title: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold))
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                    Text(title)
                }
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
    let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    
    var body: some View {
        if videos.isEmpty {
            Text("No videos yet")
                .foregroundColor(.gray)
                .padding()
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(videos) { video in
                        NavigationLink(destination: VideoFeedView()) {
                            VideoThumbnail(video: video)
                                .aspectRatio(9/16, contentMode: .fill)
                                .frame(height: UIScreen.main.bounds.width / 3)
                                .clipped()
                        }
                    }
                }
                .padding(2)
            }
        }
    }
}

struct VideoThumbnail: View {
    let video: Video
    @State private var thumbnail: UIImage?
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(
                        Image(systemName: "play.fill")
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                            .font(.title3)
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .tint(.white)
                    )
                    .onAppear {
                        generateThumbnail()
                    }
            }
        }
        .frame(width: UIScreen.main.bounds.width / 3, height: UIScreen.main.bounds.width / 3)
        .clipped()
        .background(Color.black)
        .cornerRadius(4)
    }
    
    private func generateThumbnail() {
        guard let videoUrl = URL(string: video.videoUrl) else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: videoUrl)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            // Request thumbnail at 0.0 seconds
            do {
                let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
                let uiImage = UIImage(cgImage: cgImage)
                
                DispatchQueue.main.async {
                    self.thumbnail = uiImage
                }
            } catch {
                print("Error generating thumbnail: \(error)")
            }
        }
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
                TabButton(title: "Videos", icon: "play.square.fill", isSelected: selectedTab == 0) {
                    withAnimation { selectedTab = 0 }
                }
                
                TabButton(title: "Liked", icon: "heart.fill", isSelected: selectedTab == 1) {
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