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
                            VStack {
                                Image(systemName: "house")
                                    .environment(\.symbolVariants, .none)
                                Text("Home")
                                    .font(.caption)
                            }
                        }
                    
                    Text("Discover")
                        .tabItem {
                            VStack {
                                Image(systemName: "magnifyingglass")
                                    .environment(\.symbolVariants, .none)
                                Text("Discover")
                                    .font(.caption)
                            }
                        }
                    
                    VideoUploadView()
                        .tabItem {
                            VStack {
                                Image(systemName: "plus")
                                    .environment(\.symbolVariants, .none)
                                Text("Create")
                                    .font(.caption)
                            }
                        }
                    
                    Text("Inbox")
                        .tabItem {
                            VStack {
                                Image(systemName: "message")
                                    .environment(\.symbolVariants, .none)
                                Text("Inbox")
                                    .font(.caption)
                            }
                        }
                    
                    ProfileView()
                        .tabItem {
                            VStack {
                                Image(systemName: "person")
                                    .environment(\.symbolVariants, .none)
                                Text("Profile")
                                    .font(.caption)
                            }
                        }
                }
                .tint(.primary) // Use primary color for selected items
                .onAppear {
                    // Customize tab bar appearance
                    let appearance = UITabBarAppearance()
                    appearance.configureWithDefaultBackground()
                    appearance.backgroundColor = .systemBackground
                    
                    // Use this to ensure the tab bar is opaque
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                    UITabBar.appearance().standardAppearance = appearance
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
