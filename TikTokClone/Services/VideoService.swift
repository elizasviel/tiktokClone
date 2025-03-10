import Firebase
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import SwiftUI

class VideoService: ObservableObject {
    static let shared = VideoService()
    @Published var videos = [Video]()
    @Published var likes: [String: [Like]] = [:] // videoId: [Like]
    @Published var comments: [String: [Comment]] = [:] // videoId: [Comment]
    
    // Keep references to snapshot listeners so you can remove them if needed
    private var likesListeners: [String: ListenerRegistration] = [:]
    private var commentsListeners: [String: ListenerRegistration] = [:]
    
    // MARK: - Real-time Listeners
    func listenForLikes(for videoId: String) {
        // If we're already listening for this video, remove the old listener
        likesListeners[videoId]?.remove()
        
        let query = Firestore.firestore().collection("likes")
            .whereField("videoId", isEqualTo: videoId)
        
        likesListeners[videoId] = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            guard let snapshot = snapshot else {
                print("Error listening for likes: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            do {
                // Decode each document into a Like struct
                self.likes[videoId] = try snapshot.documents.map { document in
                    let data = try JSONSerialization.data(withJSONObject: document.data())
                    return try JSONDecoder().decode(Like.self, from: data)
                }
            } catch {
                print("Error decoding likes for \(videoId): \(error)")
            }
        }
    }
    
    func listenForComments(for videoId: String) {
        // If we're already listening for this video, remove the old listener
        commentsListeners[videoId]?.remove()
        
        let query = Firestore.firestore().collection("comments")
            .whereField("videoId", isEqualTo: videoId)
            .order(by: "timestamp", descending: true)
        
        commentsListeners[videoId] = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            guard let snapshot = snapshot else {
                print("Error listening for comments: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            // Update comments in our published dictionary
            self.comments[videoId] = snapshot.documents.compactMap { document in
                let data = document.data()
                guard let timestamp = data["timestamp"] as? Timestamp else { return nil }
                return Comment(
                    id: data["id"] as? String ?? "",
                    userId: data["userId"] as? String ?? "",
                    videoId: data["videoId"] as? String ?? "",
                    text: data["text"] as? String ?? "",
                    timestamp: timestamp.dateValue()
                )
            }
        }
    }
    
    /// (Optional) Stop listening if you ever need to detach or avoid memory leaks
    func stopListening(for videoId: String) {
        likesListeners[videoId]?.remove()
        likesListeners[videoId] = nil
        
        commentsListeners[videoId]?.remove()
        commentsListeners[videoId] = nil
    }
    
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
    
   func likeVideo(_ videoId: String) async throws {
       guard let uid = Auth.auth().currentUser?.uid else { throw URLError(.badServerResponse) }
       
       // Use userId_videoId as the doc ID to ensure uniqueness
       let likeDocId = "\(uid)_\(videoId)"
       let like = Like(id: likeDocId, userId: uid, videoId: videoId, timestamp: Date())
       
       let data = try JSONEncoder().encode(like)
       let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
       
       try await Firestore.firestore().collection("likes").document(likeDocId).setData(dict)
       
       // Update local state once
       if likes[videoId] == nil {
           likes[videoId] = []
       }
       // Make sure you remove duplicates (if any) before appending
       likes[videoId]?.removeAll { $0.userId == uid }
       likes[videoId]?.append(like)
   }
    
    func unlikeVideo(_ videoId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // Find and delete the like document
        let snapshot = try await Firestore.firestore().collection("likes")
            .whereField("videoId", isEqualTo: videoId)
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        
        for document in snapshot.documents {
            try await document.reference.delete()
        }
        
        // Update local state
        likes[videoId]?.removeAll { $0.userId == uid }
    }
    
    func addComment(_ text: String, to videoId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw URLError(.badServerResponse) }
        
        let commentId = UUID().uuidString
        let comment = Comment(id: commentId,
                             userId: uid,
                             videoId: videoId,
                             text: text,
                             timestamp: Date())
        
        let data: [String: Any] = [
            "id": comment.id,
            "userId": comment.userId,
            "videoId": comment.videoId,
            "text": comment.text,
            "timestamp": Timestamp(date: comment.timestamp)
        ]
        
        try await Firestore.firestore().collection("comments").document(commentId).setData(data)
        
        // Update local state
        if comments[videoId] == nil {
            comments[videoId] = []
        }
        comments[videoId]?.append(comment)
    }
    
    func deleteComment(_ commentId: String, from videoId: String) async throws {
        try await Firestore.firestore().collection("comments").document(commentId).delete()
        
        // Update local state
        comments[videoId]?.removeAll { $0.id == commentId }
    }
    
    func fetchLikesAndComments(for videoId: String) async throws {
        // Fetch likes
        let likesSnapshot = try await Firestore.firestore().collection("likes")
            .whereField("videoId", isEqualTo: videoId)
            .getDocuments()
        
        likes[videoId] = try likesSnapshot.documents.map { document in
            let data = try JSONSerialization.data(withJSONObject: document.data())
            return try JSONDecoder().decode(Like.self, from: data)
        }
        
        // Fetch comments
        let commentsSnapshot = try await Firestore.firestore().collection("comments")
            .whereField("videoId", isEqualTo: videoId)
            .order(by: "timestamp", descending: true)
            .getDocuments()
        
        comments[videoId] = commentsSnapshot.documents.compactMap { document in
            let data = document.data()
            guard let timestamp = data["timestamp"] as? Timestamp else { return nil }
            
            return Comment(
                id: data["id"] as? String ?? "",
                userId: data["userId"] as? String ?? "",
                videoId: data["videoId"] as? String ?? "",
                text: data["text"] as? String ?? "",
                timestamp: timestamp.dateValue()
            )
        }
    }
} 