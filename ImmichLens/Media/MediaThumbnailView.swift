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
  private let logger = Logger(subsystem: "dev.lav.immichlens", category: "MediaThumbnailView")

  @EnvironmentObject var apiService: APIService
  @FocusState.Binding var focusedIndex: Int?
  let index: Int
  let asset: Asset?

  // var body: some View {
  //   Rectangle()
  //     .frame(width: 256, height: 256)
  //     .foregroundColor(.gray.opacity(0.2))
  //     .overlay {
  //       Text("\(index)")
  //     }
  //     .cornerRadius(8)
  //     .hoverEffect(.highlight)
  //     .focusable()
  //     .focused($focusedIndex, equals: index)
  // }

  var body: some View {
    if let asset = asset {
      // Render actual asset
      NavigationLink(value: asset) {
        ZStack(alignment: .bottomTrailing) {
          LazyImage(
            url: asset.imageUrl(size: .thumbnail)
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
                #if !os(macOS)
                .hoverEffectDisabled()
                #endif
            }
          }

          // Video indicator and duration
          if asset.type == .video {
            VideoDurationOverlay(duration: asset.duration)
          }
        }
        .focusable()
        #if !os(macOS)
        .hoverEffect(.highlight)
        #endif
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
        #if !os(macOS)
        .hoverEffect(.highlight)
        #endif
        .focusable()
        .focused($focusedIndex, equals: index)
    }
  }
}
