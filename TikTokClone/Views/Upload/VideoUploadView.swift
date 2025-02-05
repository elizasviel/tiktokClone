import SwiftUI
import PhotosUI
import AVKit

struct VideoUploadView: View {
    @StateObject private var videoService = VideoService.shared
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedVideoURL: URL?
    @State private var caption = ""
    @State private var isUploading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var player: AVPlayer?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Video Preview Section
                    Group {
                        if let player = player {
                            VideoPlayer(player: player)
                                .frame(height: 400)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        } else {
                            PhotosPicker(selection: $selectedItem, matching: .videos) {
                                VStack(spacing: 12) {
                                    Image(systemName: "video.badge.plus")
                                        .font(.system(size: 40))
                                        .foregroundColor(.blue)
                                    
                                    Text("Tap to select video")
                                        .font(.headline)
                                    
                                    Text("MP4 or MOV format")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 400)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                    
                    // Caption Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Caption")
                            .font(.headline)
                        
                        TextField("Write a caption...", text: $caption, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...5)
                    }
                    
                    // Upload Button
                    Button(action: uploadVideo) {
                        HStack {
                            if isUploading {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 5)
                            }
                            
                            Text(isUploading ? "Uploading..." : "Post")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isUploading ? Color.gray : Color.blue)
                        .cornerRadius(25)
                    }
                    .disabled(isUploading || selectedVideoURL == nil)
                    .opacity(selectedVideoURL == nil ? 0.6 : 1.0)
                }
                .padding()
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .alert("Upload Status", isPresented: $showAlert) {
                Button("OK") { 
                    if !alertMessage.contains("Error") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .onChange(of: selectedItem) { _ in
                handleVideoSelection()
            }
        }
    }
    
    private func handleVideoSelection() {
        guard let selectedItem = selectedItem else { return }
        
        Task {
            do {
                let videoData = try await selectedItem.loadTransferable(type: Data.self)
                guard let videoData = videoData else { return }
                
                // Save video data to temporary file
                let tempDir = FileManager.default.temporaryDirectory
                let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".mp4")
                try videoData.write(to: tempFile)
                
                await MainActor.run {
                    selectedVideoURL = tempFile
                    player = AVPlayer(url: tempFile)
                    player?.play()
                }
            } catch {
                print("Error loading video: \(error)")
            }
        }
    }
    
    private func uploadVideo() {
        guard let videoURL = selectedVideoURL else { return }
        isUploading = true
        
        Task {
            do {
                let _ = try await videoService.uploadVideo(videoUrl: videoURL, caption: caption)
                
                await MainActor.run {
                    alertMessage = "Video uploaded successfully!"
                    showAlert = true
                    isUploading = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Error: \(error.localizedDescription)"
                    showAlert = true
                    isUploading = false
                }
            }
        }
    }
}

#Preview {
    VideoUploadView()
} 