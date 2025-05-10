//
//  MediaThumbnailView.swift
//  ImmichLens
//
//  Created on 10/05/2025.
//

import Nuke
import NukeUI
import SwiftUI
import os

struct MediaThumbnailView: View {
  @EnvironmentObject var apiService: APIService
  @FocusState.Binding var focusedIndex: Int?
  let index: Int
  let asset: Components.Schemas.AssetResponseDto?

  private let logger = Logger(subsystem: "dev.lav.immichlens", category: "MediaThumbnailView")

  var body: some View {
    if let asset = asset {
      // Render actual asset
      NavigationLink(value: asset) {
        ZStack(alignment: .bottomTrailing) {
          let thumbnailUrl =
            apiService.serverUrl!
            + "/assets/\(asset.id)/thumbnail?size=thumbnail&c=\(asset.thumbhash!)"

          LazyImage(
            url: URL(string: thumbnailUrl)
          ) { state in
            if state.isLoading {
              ProgressView()
                .frame(width: 256, height: 256)
            }
            if state.error != nil {
              Image(systemName: "photo")
                .background(Color.gray.opacity(0.3))
                .cornerRadius(8)
                .frame(width: 256, height: 256)
            }
            if let image = state.image {
              // Image loaded successfully
              image
                .frame(width: 256, height: 256)
                .aspectRatio(contentMode: .fill)
                .cornerRadius(8)
                .clipped()
                .hoverEffectDisabled()
            }
          }

          // Video indicator and duration
          if asset._type.value1 == .video {
            VideoDurationOverlay(duration: asset.duration)
          }
        }
        .focusable()
        .hoverEffect(.highlight)
        .focused($focusedIndex, equals: index)
      }
      .buttonStyle(.borderless)
    } else {
      // Placeholder for assets that haven't loaded yet
      Rectangle()
        .frame(width: 256, height: 256)
        .foregroundColor(.gray.opacity(0.2))
        .overlay {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
            .scaleEffect(1.5)
        }
        .cornerRadius(8)
        .hoverEffect(.highlight)
        .focusable()
      // .focused($focusedIndex, equals: index)
    }
  }
}
