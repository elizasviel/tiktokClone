import Foundation
import Firebase
import FirebaseFirestore

struct User: Identifiable {
    let id: String
    let username: String
    let email: String
    let dateJoined: Timestamp
    let profileImageUrl: String?
    
    init(id: String, username: String, email: String, dateJoined: Timestamp, profileImageUrl: String? = nil) {
        self.id = id
        self.username = username
        self.email = email
        self.dateJoined = dateJoined
        self.profileImageUrl = profileImageUrl
    }
    
    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let username = dict["username"] as? String,
              let email = dict["email"] as? String,
              let dateJoined = dict["dateJoined"] as? Timestamp else {
            return nil
        }
        
        self.id = id
        self.username = username
        self.email = email
        self.dateJoined = dateJoined
        self.profileImageUrl = dict["profileImageUrl"] as? String
    }
    
    func toDictionary() -> [String: Any] {
        var dict = [
            "id": id,
            "username": username,
            "email": email,
            "dateJoined": dateJoined
        ] as [String: Any]
        
        if let profileImageUrl = profileImageUrl {
            dict["profileImageUrl"] = profileImageUrl
        }
        
        return dict
    }
} 