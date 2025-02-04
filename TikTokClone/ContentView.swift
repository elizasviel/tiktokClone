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
                            Image(systemName: "house.fill")
                            Text("Home")
                        }
                    
                    Text("Discover")
                        .tabItem {
                            Image(systemName: "magnifyingglass")
                            Text("Discover")
                        }
                    
                    VideoUploadView()
                        .tabItem {
                            Image(systemName: "plus.square")
                            Text("Create")
                        }
                    
                    Text("Inbox")
                        .tabItem {
                            Image(systemName: "message.fill")
                            Text("Inbox")
                        }
                    
                    ProfileView()
                        .tabItem {
                            Image(systemName: "person.fill")
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
