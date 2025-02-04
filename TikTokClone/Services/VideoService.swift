import Firebase
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import SwiftUI

class VideoService: ObservableObject {
    static let shared = VideoService()
    @Published var videos = [Video]()
    
    func uploadVideo(videoUrl: URL, caption: String) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else { throw URLError(.badServerResponse) }
        
        // Create unique video ID
        let videoId = UUID().uuidString
        
        // Create storage reference
        let videoRef = Storage.storage().reference().child("videos/\(videoId).mp4")
        
        // Upload video data
        do {
            let videoData = try Data(contentsOf: videoUrl)
            let _ = try await videoRef.putDataAsync(videoData)
            let downloadUrl = try await videoRef.downloadURL()
            
            let timestamp = Timestamp()
            // Create video document in Firestore
            let data: [String: Any] = [
                "id": videoId,
                "caption": caption,
                "videoUrl": downloadUrl.absoluteString,
                "userId": uid,
                "timestamp": timestamp
            ]
            
            try await Firestore.firestore().collection("videos").document(videoId).setData(data)
            return videoId
        } catch {
            throw error
        }
    }
    
    func fetchVideos() async throws {
        let snapshot = try await Firestore.firestore().collection("videos")
            .order(by: "timestamp", descending: true)
            .getDocuments()
        
        self.videos = snapshot.documents.compactMap { document in
            let data = document.data()
            
            guard let timestamp = data["timestamp"] as? Timestamp else { return nil }
            
            return Video(
                id: data["id"] as? String ?? "",
                caption: data["caption"] as? String ?? "",
                videoUrl: data["videoUrl"] as? String ?? "",
                thumbnailUrl: data["thumbnailUrl"] as? String,
                userId: data["userId"] as? String ?? "",
                timestamp: timestamp.dateValue()
            )
        }
    }
    
    func deleteVideo(_ videoId: String) async throws {
        // Delete from Storage
        let videoRef = Storage.storage().reference().child("videos/\(videoId).mp4")
        try await videoRef.delete()
        
        // Delete from Firestore
        try await Firestore.firestore().collection("videos").document(videoId).delete()
        
        // Update local videos array
        self.videos.removeAll { $0.id == videoId }
    }
} 