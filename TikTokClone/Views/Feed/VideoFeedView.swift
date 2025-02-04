import SwiftUI
import AVKit
import FirebaseAuth

struct VideoFeedView: View {
    @StateObject private var videoService = VideoService.shared
    @State private var currentIndex = 0
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $currentIndex) {
                ForEach(videoService.videos.indices, id: \.self) { index in
                    FullScreenVideoPlayer(video: videoService.videos[index])
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(width: geometry.size.width, height: geometry.size.height)
            .task {
                do {
                    try await videoService.fetchVideos()
                } catch {
                    print("Error fetching videos: \(error)")
                }
            }
        }
        .ignoresSafeArea()
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
            
            VStack {
                Spacer()
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("@\(video.user?.username ?? "user")")
                            .font(.headline)
                        Text(video.caption)
                            .font(.subheadline)
                    }
                    .foregroundColor(.white)
                    .shadow(radius: 5)
                    
                    Spacer()
                    
                    VStack(spacing: 20) {
                        Button(action: {
                            Task {
                                if isLiked {
                                    try? await videoService.unlikeVideo(video.id)
                                } else {
                                    try? await videoService.likeVideo(video.id)
                                }
                                isLiked.toggle()
                            }
                        }) {
                            VStack {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.title)
                                    .foregroundColor(isLiked ? .red : .white)
                                Text("\(videoService.likes[video.id]?.count ?? 0)")
                                    .font(.caption)
                            }
                        }
                        
                        Button(action: { showComments = true }) {
                            VStack {
                                Image(systemName: "message.fill")
                                    .font(.title)
                                Text("\(videoService.comments[video.id]?.count ?? 0)")
                                    .font(.caption)
                            }
                        }
                        
                        Button(action: { /* Share action */ }) {
                            VStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title)
                                Text("Share")
                                    .font(.caption)
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .shadow(radius: 5)
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
        .sheet(isPresented: $showComments) {
            CommentsView(videoId: video.id)
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