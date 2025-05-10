//
//  VideoPlayerView.swift
//  ImmichLens
//
//  Created on 05/05/2025.
//

import AVKit
import SwiftUI
import os

struct VideoPlayerView: View {
  @EnvironmentObject var apiService: APIService
  @Environment(\.dismiss) var dismiss
  let assetId: String
  let thumbhash: String

  @State private var player: AVPlayer?
  @State private var isLoading = true
  @State private var error: Error?

  private let logger = Logger(subsystem: "dev.lav.immichlens", category: "VideoPlayerView")

  var body: some View {
    ZStack {
      Color.black.edgesIgnoringSafeArea(.all)  // Ensure black background

      if let player = player {
        // Use VideoPlayer with standard tvOS controls at highest z-index
        VideoPlayer(player: player)
          .edgesIgnoringSafeArea(.all)
          .zIndex(100)  // Ensure highest z-index
          .onAppear {
            player.play()
          }
          .onDisappear {
            player.pause()
          }
      } else if isLoading {
        ProgressView()
          .scaleEffect(2.0)
      } else if let error = error {
        VStack {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 60))
            .foregroundColor(.red)
            .padding()

          Text("Error loading video")
            .font(.headline)

          Text(error.localizedDescription)
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .padding()
        }
      }
    }
    //        .navigationTitle("Video")
    .task {
      await loadVideo()
    }
    .ignoresSafeArea()
    #if os(macOS)
      .toolbar {
        ToolbarItem(placement: .automatic) {
          // Only show toolbar items in macOS when not in full screen
          EmptyView()
          .opacity(
            NSApplication.shared.windows.first?.styleMask.contains(.fullScreen) == true ? 0 : 1)
        }
      }
    #else
      .toolbar(.hidden, for: .automatic)
    #endif
  }

  private func loadVideo() async {
    guard let serverUrl = apiService.serverUrl else {
      self.error = NSError(
        domain: "dev.lav.immichlens", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Server URL is missing"])
      isLoading = false
      return
    }

    do {
      guard
        let downloadUrl = URL(
          string: "\(serverUrl)/assets/\(assetId)/video/playback?c=\(thumbhash)")
      else {
        throw NSError(
          domain: "dev.lav.immichlens", code: 2,
          userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
      }

      var request = URLRequest(url: downloadUrl)
      if let token = apiService.token {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      }

      // Create player with the authenticated URL request
      let asset = AVURLAsset(
        url: downloadUrl,
        options: ["AVURLAssetHTTPHeaderFieldsKey": request.allHTTPHeaderFields ?? [:]])
      let playerItem = AVPlayerItem(asset: asset)

      // Configure player
      let player = AVPlayer(playerItem: playerItem)

      // Add observer to detect when video playback ends
      NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main
      ) { _ in
        // Exit full screen and go back when video completes
        Task { @MainActor in
          dismiss()
        }
      }

      // tvOS automatically handles playback controls with the remote
      self.player = player

      isLoading = false
    } catch {
      logger.error("Failed to load video: \(error.localizedDescription)")
      self.error = error
      isLoading = false
    }
  }
}
