import SwiftUI
import AVKit

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
    @State private var player: AVPlayer?
    @State private var isPlaying = true
    @State private var showControls = false
    
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
                        Button(action: { /* Like action */ }) {
                            VStack {
                                Image(systemName: "heart.fill")
                                    .font(.title)
                                Text("Like")
                                    .font(.caption)
                            }
                        }
                        
                        Button(action: { /* Comment action */ }) {
                            VStack {
                                Image(systemName: "message.fill")
                                    .font(.title)
                                Text("Comment")
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