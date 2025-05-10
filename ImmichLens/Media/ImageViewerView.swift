//
//  ImageViewerView.swift
//  ImmichLens
//
//  Created on 10/05/2025.
//

import SwiftUI
import os

struct ImageViewerView: View {
  @EnvironmentObject var apiService: APIService
  let assetId: String
  let thumbhash: String
  
  private let logger = Logger(subsystem: "dev.lav.immichlens", category: "ImageViewerView")

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
        case .failure(let error):
          VStack {
            Image(systemName: "photo")
              .font(.system(size: 70))
              .foregroundColor(.gray)
            
            Text(error.localizedDescription)
              .font(.caption)
              .multilineTextAlignment(.center)
              .padding()
              .foregroundColor(.gray)
          }
          .onAppear {
            logger.error("Failed to load image: \(error.localizedDescription)")
          }
        @unknown default:
          EmptyView()
        }
      }
      .focusable()
    }
    .ignoresSafeArea()
  }
}
