import Foundation
import Firebase
import FirebaseFirestore

struct User: Identifiable {
    let id: String
    let username: String
    let email: String
    let dateJoined: Timestamp
    
    init(id: String, username: String, email: String, dateJoined: Timestamp) {
        self.id = id
        self.username = username
        self.email = email
        self.dateJoined = dateJoined
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
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "username": username,
            "email": email,
            "dateJoined": dateJoined
        ]
    }
} 