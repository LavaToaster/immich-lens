//
//  AssetViewerView.swift
//  ImmichLens
//
//  Created on 10/05/2025.
//

import SwiftUI
import os

struct AssetViewerView: View {
  @EnvironmentObject var apiService: APIService
  let asset: Asset

  private let logger = Logger(subsystem: "dev.lav.immichlens", category: "AssetViewerView")

  var body: some View {
    Group {
      if asset.type == .video {
        // Show video player for video assets
        VideoPlayerView(asset: asset)
      } else {
        // Show image viewer for photos
        ImageViewerView(asset: asset)
      }
    }
    #if !os(macOS)
    .toolbarVisibility(.hidden, for: .tabBar)
    #endif
  }
}
