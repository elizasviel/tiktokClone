import SwiftUI
import FirebaseAuth

struct CommentsView: View {
    let videoId: String
    @StateObject private var videoService = VideoService.shared
    @State private var newComment = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            HStack {
                Text("Comments")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    dismiss()
                }
            }
            .padding()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(videoService.comments[videoId] ?? []) { comment in
                        CommentRow(comment: comment)
                    }
                }
                .padding()
            }
            
            HStack {
                TextField("Add a comment...", text: $newComment)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Post") {
                    Task {
                        guard !newComment.isEmpty else { return }
                        try? await videoService.addComment(newComment, to: videoId)
                        newComment = ""
                    }
                }
                .disabled(newComment.isEmpty)
            }
            .padding()
        }
    }
}

struct CommentRow: View {
    let comment: Comment
    @StateObject private var videoService = VideoService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(comment.username ?? "User")
                .font(.subheadline)
                .fontWeight(.bold)
            Text(comment.text)
                .font(.subheadline)
            
            if comment.userId == Auth.auth().currentUser?.uid {
                Button("Delete") {
                    Task {
                        try? await videoService.deleteComment(comment.id, from: comment.videoId)
                    }
                }
                .foregroundColor(.red)
                .font(.caption)
            }
        }
    }
} 