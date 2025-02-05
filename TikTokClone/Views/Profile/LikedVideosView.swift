import SwiftUI
import FirebaseAuth

struct LikedVideosView: View {
    @StateObject private var videoService = VideoService.shared
    @State private var likedVideos: [Video] = []
    
    var body: some View {
        Group {
            if likedVideos.isEmpty {
                Text("No liked videos yet")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                VideosGridView(videos: likedVideos)
            }
        }
        .task {
            await fetchLikedVideos()
        }
    }
    
    private func fetchLikedVideos() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // Filter videos that the current user has liked
        likedVideos = videoService.videos.filter { video in
            videoService.likes[video.id]?.contains { like in
                like.userId == uid
            } ?? false
        }
    }
} 