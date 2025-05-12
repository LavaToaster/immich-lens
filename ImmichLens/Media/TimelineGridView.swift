//
//  TimelineGridView.swift
//  ImmichLens
//
//  Created on 10/05/2025.
//

import SwiftUI
import os

struct TimelineGridView: View {
  private let logger = Logger(subsystem: "dev.lav.immichlens", category: "TimelineGridView")
  
  let assets: [Asset]
  let count: Int
  let onLoadMore: (Int) -> Void
  
  @State private var lastVisibleIndex: Int = 0
  @State private var startCount: Int = 50
  @FocusState.Binding var focusedIndex: Int?

  // Layout constants
  private let gridSpacing: CGFloat = 64
  private let minItemWidth: CGFloat = 256

  // Configure column layout with fixed grid items
  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: minItemWidth), spacing: gridSpacing)]
  }

  var body: some View {
    LazyVGrid(columns: columns, spacing: gridSpacing) {
      // Only render active chunks plus a small buffer - creates much fewer view objects
      ForEach(0..<min(startCount, count), id: \.self) { index in
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
  
  // Calculate estimated remaining height based on grid layout
  private func calculateEstimatedHeight(for remainingItems: Int, width: CGFloat) -> CGFloat {
    // Calculate how many columns we have based on provided width
    let columnsCount = max(1, Int(width / (minItemWidth + gridSpacing)))
    
    // Calculate how many rows the remaining items will take
    let rowsCount = ceil(Double(remainingItems) / Double(columnsCount))
    
    // Calculate total height: rows * (thumbnail height + spacing)
    return CGFloat(rowsCount) * (256 + gridSpacing)
  }

  private func updateVisibleIndex(_ index: Int) {
    if index > lastVisibleIndex {
      lastVisibleIndex = index
      
      // If we're approaching the end of displayed items, load more
      if index > startCount - 40 && startCount < count {
        logger.debug("Loading more items at index \(index)")
        startCount = min(startCount + 100, count)
      }

      let loadTriggerThreshold = assets.count - 20
      if index > Int(loadTriggerThreshold) {
        logger.debug("Approaching end of loaded assets at index \(index), loading more")
        onLoadMore(index)
      }
    }
  }
}
