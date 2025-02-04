//
//  TikTokCloneApp.swift
//  TikTokClone
//
//  Created by Norman Qian on 2/3/25.
//

import SwiftUI
import Firebase

@main
struct TikTokCloneApp: App {
    init() {
        FirebaseManager.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
