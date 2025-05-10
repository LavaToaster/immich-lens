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
  let asset: Components.Schemas.AssetResponseDto

  private let logger = Logger(subsystem: "dev.lav.immichlens", category: "AssetViewerView")

  var body: some View {
    if asset._type.value1 == .video {
      // Show video player for video assets
      VideoPlayerView(assetId: asset.id, thumbhash: asset.thumbhash!)
    } else {
      // Show image viewer for photos
      ImageViewerView(assetId: asset.id, thumbhash: asset.thumbhash!)
    }
  }
}
