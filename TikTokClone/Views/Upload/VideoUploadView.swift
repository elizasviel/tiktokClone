import SwiftUI
import PhotosUI

struct VideoUploadView: View {
    @StateObject private var videoService = VideoService.shared
    @State private var selectedItem: PhotosPickerItem?
    @State private var caption = ""
    @State private var isUploading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                PhotosPicker(selection: $selectedItem, matching: .videos) {
                    VStack {
                        Image(systemName: "video.badge.plus")
                            .font(.largeTitle)
                        Text("Select Video")
                    }
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                }
                
                TextField("Add caption...", text: $caption)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button(action: uploadVideo) {
                    Text(isUploading ? "Uploading..." : "Post")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isUploading ? Color.gray : Color.blue)
                        .cornerRadius(10)
                }
                .disabled(isUploading)
                .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Upload Video")
            .alert("Upload Status", isPresented: $showAlert) {
                Button("OK") { 
                    if !alertMessage.contains("Error") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    func uploadVideo() {
        guard let selectedItem = selectedItem else { return }
        isUploading = true
        
        Task {
            do {
                let videoData = try await selectedItem.loadTransferable(type: Data.self)
                guard let videoData = videoData else { throw URLError(.badServerResponse) }
                
                // Save video data to temporary file
                let tempDir = FileManager.default.temporaryDirectory
                let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".mp4")
                try videoData.write(to: tempFile)
                
                // Upload video
                let _ = try await videoService.uploadVideo(videoUrl: tempFile, caption: caption)
                
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