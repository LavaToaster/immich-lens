//
//  TimelineGridView.swift
//  ImmichLens
//
//  Created on 10/05/2025.
//

import SwiftUI
import os

struct TimelineGridView: View {
  let assets: [Components.Schemas.AssetResponseDto]
  let count: Int
  let onLoadMore: (Int) -> Void
  
  @State private var lastVisibleIndex: Int = 0

  private let logger = Logger(subsystem: "dev.lav.immichlens", category: "TimelineGridView")
  
  @FocusState private var focusedIndex: Int?

  // Layout constants
  private let gridSpacing: CGFloat = 64
  private let minItemWidth: CGFloat = 256

  // Configure column layout with fixed grid items
  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: minItemWidth), spacing: gridSpacing)]
  }

  var body: some View {
    LazyVGrid(columns: columns, spacing: gridSpacing) {
      ForEach(0..<count, id: \.self) { index in
        MediaThumbnailView(
          focusedIndex: $focusedIndex,
          index: index,
          asset: index < assets.count ? assets[index] : nil
        )
        .id(index)
        .onAppear {
          updateVisibleIndex(index)
        }
      }
    }
  }

  private func updateVisibleIndex(_ index: Int) {
    if index > lastVisibleIndex {
      lastVisibleIndex = index

      let loadTriggerThreshold = assets.count - 20
      if index > Int(loadTriggerThreshold) {
        logger.debug("Approaching end of loaded assets at index \(index), loading more")
        onLoadMore(index)
      }
    }
  }
}
