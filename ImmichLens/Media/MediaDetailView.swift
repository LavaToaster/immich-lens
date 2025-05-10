//
//  MediaDetailView.swift
//  ImmichLens
//
//  Created on 05/05/2025.
//

import SwiftUI
import os

struct MediaDetailView: View {
  @EnvironmentObject var apiService: APIService
  let asset: Components.Schemas.AssetResponseDto

  private let logger = Logger(subsystem: "dev.lav.immichlens", category: "MediaDetailView")

  var body: some View {
    if asset._type.value1 == .video {
      // Show video player for video assets
      VideoPlayerView(assetId: asset.id, thumbhash: asset.thumbhash!)
    } else {
      // Placeholder for image viewer - to be implemented later
      PhotoView(assetId: asset.id, thumbhash: asset.thumbhash!)
    }
  }

  private func getMediaTitle() -> String {
    return asset._type.value1 == .video ? "Video" : "Photo"
  }
}

// Placeholder for photo view - to be implemented later
struct PhotoView: View {
  @EnvironmentObject var apiService: APIService
  let assetId: String
  let thumbhash: String

  var body: some View {
    ZStack {
      AsyncImage(
        url: URL(
          string: apiService.serverUrl! + "/assets/\(assetId)/thumbnail?size=preview&c=\(thumbhash)"
        )
      ) { phase in
        switch phase {
        case .empty:
          ProgressView()
        case .success(let image):
          image
            .resizable()
            .aspectRatio(contentMode: .fit)
        case .failure:
          Image(systemName: "photo")
            .font(.system(size: 70))
            .foregroundColor(.gray)
        @unknown default:
          EmptyView()
        }
      }
      .focusable()
    }
  }
}

//#Preview {
//    MediaDetailView(asset: Components.Schemas.AssetResponseDto(
//        id: "sample-id",
//        _type: OneOf2<Components.Schemas.AssetTypeEnum, String>(.image),
//        createdAt: Date()
//    ))
//    .environmentObject(APIService())
//}
