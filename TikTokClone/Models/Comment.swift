import Foundation
import Firebase

struct Comment: Identifiable {
    let id: String
    let userId: String
    let videoId: String
    let text: String
    let timestamp: Date
    var username: String?
    
    init(id: String, userId: String, videoId: String, text: String, timestamp: Date) {
        self.id = id
        self.userId = userId
        self.videoId = videoId
        self.text = text
        self.timestamp = timestamp
    }
} 