import SwiftUI
import AVKit

struct VideoFeedView: View {
    @StateObject private var videoService = VideoService.shared
    @State private var showUploadSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(videoService.videos) { video in
                        VideoPlayerView(videoUrl: video.videoUrl)
                            .frame(height: 400)
                            .cornerRadius(12)
                            .overlay(alignment: .bottomLeading) {
                                Text(video.caption)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(.black.opacity(0.3))
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Videos")
            .toolbar {
                Button {
                    showUploadSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showUploadSheet) {
                VideoUploadView()
            }
            .task {
                do {
                    try await videoService.fetchVideos()
                } catch {
                    print("Error fetching videos: \(error)")
                }
            }
        }
    }
}

struct VideoPlayerView: View {
    let videoUrl: String
    
    var body: some View {
        if let url = URL(string: videoUrl) {
            VideoPlayer(player: AVPlayer(url: url))
        } else {
            Color.gray
        }
    }
} 