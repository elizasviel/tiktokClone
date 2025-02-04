//
//  ContentView.swift
//  TikTokClone
//
//  Created by Norman Qian on 2/3/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var authService = AuthService.shared
    
    var body: some View {
        Group {
            if authService.userSession != nil {
                TabView {
                    VideoFeedView()
                        .tabItem {
                            Image(systemName: "play.circle")
                            Text("Feed")
                        }
                    
                    ProfileView()
                        .tabItem {
                            Image(systemName: "person")
                            Text("Profile")
                        }
                }
            } else {
                LoginView()
            }
        }
    }
}

#Preview {
    ContentView()
}
