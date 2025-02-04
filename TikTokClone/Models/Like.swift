import Foundation

struct Like: Identifiable, Codable {
    let id: String
    let userId: String
    let videoId: String
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case videoId
        case timestamp
    }
} 