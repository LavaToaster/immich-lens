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
  @State private var startCount: Int = 20 // TODO: Compute this based on screen size
  @FocusState.Binding var focusedIndex: Int?
  @State private var scrollOffset: CGFloat = 0

  // Layout constants
  private let gridSpacing: CGFloat = 64
  private let thumbnailSize: CGFloat = 256
  private let overscanRows: Int = 4

  var body: some View {
    GeometryReader { geometry in
      let columnsCount = max(1, Int(geometry.size.width / (thumbnailSize + gridSpacing)))
      let rowCount = Int(ceil(Double(count) / Double(columnsCount)))
      let rowHeight = thumbnailSize + gridSpacing
      let visibleRows = Int(ceil(geometry.size.height / rowHeight))
      
      // Calculate visible rows with safety bounds
      let firstVisibleRow = max(0, Int(scrollOffset / rowHeight) - overscanRows)
      let lastVisibleRow = min(rowCount, firstVisibleRow + visibleRows + (overscanRows * 2))

      ScrollView(.vertical, showsIndicators: true) {
        VStack(alignment: .center, spacing: 0) {
          // Spacer at the top to position content correctly - Making it visible but transparent for debugging
          if firstVisibleRow > 0 {
            Color.clear
              .frame(height: CGFloat(firstVisibleRow) * rowHeight)
          }
          
          let _ = logger.debug("Layout: columns=\(columnsCount), rowCount=\(rowCount), rowHeight=\(rowHeight)")
          let _ = logger.debug("Viewport: visibleRows=\(visibleRows), firstVisible=\(firstVisibleRow), lastVisible=\(lastVisibleRow)")
          let _ = logger.debug("Content: startCount=\(startCount)/\(count), assetsLoaded=\(assets.count)/\(count), lastVisibleIndex=\(lastVisibleIndex)")
          
          // Only render the visible rows plus buffer
          ForEach(firstVisibleRow..<max(firstVisibleRow+1, lastVisibleRow), id: \.self) { row in
            HStack(spacing: gridSpacing) {
              ForEach(0..<columnsCount, id: \.self) { col in
                let index = row * columnsCount + col
                if index < count {
                  MediaThumbnailView(
                    focusedIndex: $focusedIndex,
                    index: index,
                    asset: index < assets.count ? assets[index] : nil
                  )
                  .frame(width: thumbnailSize, height: thumbnailSize)
                  .id(index)
                } else {
                  // Empty spacer for grid alignment
                  Color.clear
                    .frame(width: thumbnailSize, height: thumbnailSize)
                }
              }
            }
            .padding(.vertical, gridSpacing / 2)
          }
          
          // Spacer at the bottom to maintain scroll size
          if lastVisibleRow < rowCount {
            Color.clear
              .frame(height: CGFloat(rowCount - lastVisibleRow) * rowHeight)
          }
        }
        // Ensure sufficient height for scrolling with all content
        .frame(minHeight: geometry.size.height)
        .frame(height: CGFloat(rowCount) * rowHeight, alignment: .top)
        .background(
          GeometryReader { proxy in
            Color.clear.preference(
              key: ScrollOffsetPreferenceKey.self,
              value: -proxy.frame(in: .named("scrollView")).origin.y
            )
          }
        )
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
          scrollOffset = value
          
          let visibleBottom = scrollOffset + geometry.size.height
          let contentHeight = CGFloat(rowCount) * rowHeight

          let loadMoreThreshold = contentHeight - (3 * rowHeight)
          
          if visibleBottom > loadMoreThreshold {
            // Calculate the last visible index
            let lastVisibleRow = Int((visibleBottom + rowHeight - 1) / rowHeight)
            let lastVisibleIndex = min((lastVisibleRow * columnsCount) - 1, count - 1)
            updateVisibleIndex(lastVisibleIndex)
          }
        }
      }
      .coordinateSpace(name: "scrollView")
      .onAppear {
        let initialRowCount = min(visibleRows + overscanRows, rowCount)
        let initialIndex = min((initialRowCount * columnsCount) - 1, count - 1)
        updateVisibleIndex(initialIndex)
      }
    }
  }
  
  private func calculateEstimatedHeight(for remainingItems: Int, width: CGFloat) -> CGFloat {
    let columnsCount = max(1, Int(width / (thumbnailSize + gridSpacing)))
    let rowsCount = ceil(Double(remainingItems) / Double(columnsCount))
    
    return CGFloat(rowsCount) * (thumbnailSize + gridSpacing)
  }

  private func updateVisibleIndex(_ index: Int) {
    lastVisibleIndex = index
    onLoadMore(index)
  }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value += nextValue() 
  }
}
