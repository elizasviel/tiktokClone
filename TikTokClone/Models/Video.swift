import Foundation
import Firebase

struct Video: Identifiable, Codable {
    let id: String
    let caption: String
    let videoUrl: String
    let thumbnailUrl: String?
    let userId: String
    let timestamp: Date
    
    var user: User?
    
    enum CodingKeys: String, CodingKey {
        case id
        case caption
        case videoUrl
        case thumbnailUrl
        case userId
        case timestamp
    }
} 