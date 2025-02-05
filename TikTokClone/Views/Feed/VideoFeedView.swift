import SwiftUI
import AVKit
import FirebaseAuth

struct VideoFeedView: View {
    @StateObject private var videoService = VideoService.shared
    @State private var currentIndex = 0
    @State private var showComments = false
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $currentIndex) {
                ForEach(videoService.videos.indices, id: \.self) { index in
                    ZStack(alignment: .bottomLeading) {
                        // Video Player
                        FullScreenVideoPlayer(video: videoService.videos[index])
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        
                        // Overlay Content
                        VStack(alignment: .leading, spacing: 10) {
                            // Video Info
                            VStack(alignment: .leading, spacing: 8) {
                                // Username
                                Text("@\(videoService.videos[index].user?.username ?? "user")")
                                    .font(.system(size: 16, weight: .bold))
                                
                                // Caption
                                Text(videoService.videos[index].caption)
                                    .font(.system(size: 15))
                                    .lineLimit(2)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                        }
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                        
                        // Right Side Buttons
                        VStack(spacing: 20) {
                            // Profile Image
                            Button(action: {
                                // Profile action
                            }) {
                                CircularProfileImage(user: videoService.videos[index].user)
                                    .frame(width: 44, height: 44)
                            }
                            
                            // Like Button
                            let isLiked = videoService.likes[videoService.videos[index].id]?.contains { $0.userId == Auth.auth().currentUser?.uid } ?? false
                            Button(action: {
                                Task {
                                    if isLiked {
                                        try? await videoService.unlikeVideo(videoService.videos[index].id)
                                    } else {
                                        try? await videoService.likeVideo(videoService.videos[index].id)
                                    }
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(isLiked ? .red : .white)
                                    
                                    Text("\(videoService.likes[videoService.videos[index].id]?.count ?? 0)")
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // Comments Button
                            Button(action: { showComments = true }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "bubble.right.fill")
                                        .font(.system(size: 26))
                                    
                                    Text("\(videoService.comments[videoService.videos[index].id]?.count ?? 0)")
                                        .font(.caption)
                                        .bold()
                                }
                            }
                            .sheet(isPresented: $showComments) {
                                CommentsView(videoId: videoService.videos[index].id)
                            }
                            
                            // Share Button
                            Button(action: {
                                // Share action
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "arrowshape.turn.up.forward.fill")
                                        .font(.system(size: 26))
                                    
                                    Text("Share")
                                        .font(.caption)
                                        .bold()
                                }
                            }
                        }
                        .padding(.trailing, 12)
                        .padding(.bottom, 20)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(width: geometry.size.width, height: geometry.size.height)
            .rotationEffect(.degrees(0)) // Ensures proper orientation
            .task {
                do {
                    try await videoService.fetchVideos()
                } catch {
                    print("Error fetching videos: \(error)")
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark) // Forces dark mode for better visibility
    }
}

struct FullScreenVideoPlayer: View {
    let video: Video
    @StateObject private var videoService = VideoService.shared
    @State private var player: AVPlayer?
    @State private var isPlaying = true
    @State private var showControls = false
    @State private var showComments = false
    @State private var isLiked = false
    
    var body: some View {
        ZStack {
            if let player = player {
                CustomVideoPlayer(player: player)
                    .onTapGesture {
                        showControls.toggle()
                    }
            }
            
            // Caption overlay at bottom left
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("@\(video.user?.username ?? "user")")
                            .font(.headline)
                        Text(video.caption)
                            .font(.subheadline)
                    }
                    .foregroundColor(.white)
                    .shadow(radius: 5)
                    Spacer()
                }
                .padding()
            }
        }
        .onAppear {
            if let url = URL(string: video.videoUrl) {
                player = AVPlayer(url: url)
                player?.play()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .task {
            do {
                try await videoService.fetchLikesAndComments(for: video.id)
                isLiked = videoService.likes[video.id]?.contains { $0.userId == Auth.auth().currentUser?.uid } ?? false
            } catch {
                print("Error fetching likes and comments: \(error)")
            }
        }
    }
}

struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

// Supporting Views
struct CircularProfileImage: View {
    let user: User?
    
    var body: some View {
        Group {
            if let profileImageUrl = user?.profileImageUrl,
               let url = URL(string: profileImageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.white)
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white, lineWidth: 2)
        )
        .overlay(
            Circle()
                .fill(Color.blue)
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                )
                .offset(y: 30)
        )
    }
}

struct SideBarButton: View {
    let icon: String
    let count: Int
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(isActive ? .red : .white)
            
            Text("\(count)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
    }
}