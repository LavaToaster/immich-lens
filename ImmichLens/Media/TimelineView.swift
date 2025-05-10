//
//  TimelineView.swift
//  ImmichLens
//
//  Created on 10/05/2025.
//

import SwiftUI
import os

struct TimelineView: View {
  @EnvironmentObject var apiService: APIService
  @State private var isReady: Bool = false
  @State private var error: Error? = nil
  @State private var timeBuckets: [Components.Schemas.TimeBucketResponseDto] = []
  @State private var assets: [Components.Schemas.AssetResponseDto] = []
  @State private var loadedBucketIds: Set<String> = []
  @State private var hasLoadedAllAssets: Bool = false
  @State private var navigationPath = NavigationPath()
  @State private var totalAssets: Int = 0

  private let logger = Logger(subsystem: "dev.lav.immichlens", category: "TimelineView")

  var body: some View {
    NavigationStack(path: $navigationPath) {
      ScrollView(.vertical) {
        if !isReady {
          ProgressView()
            .padding(.top, 100)
        } else if let error: any Error = error {
          Text("Error: \(error.localizedDescription)")
            .padding(.top, 100)
        } else {
          TimelineGridView(
            assets: assets,
            count: totalAssets,
            onLoadMore: { index in
              self.checkAndLoadMoreAssets(index)
            }
          )
        }
      }
      .navigationDestination(for: Components.Schemas.AssetResponseDto.self) { asset in
        AssetViewerView(asset: asset)
      }
    }
    .task {
      // Only load data if we haven't loaded any assets yet
      if assets.isEmpty {
        await initialise()
      }
    }
  }

  /// Initialises the view by loading the list of time buckets and the first set of assets.
  func initialise() async {
    isReady = false
    defer { isReady = true }

    if apiService.client == nil {
      // Do nothing if client isn't initialised (e.g., during logout)
      logger.error("API client is not initialised")
      return
    }

    do {
      let response = try await apiService.client!.getTimeBuckets(
        query: .init(isArchived: false, size: .month, withPartners: true, withStacked: true))

      timeBuckets = try response.ok.body.json
      logger.info("Loaded \(timeBuckets.count) time buckets")

      guard !timeBuckets.isEmpty else {
        logger.info("No time buckets available, nothing to load")
        return
      }

      totalAssets = timeBuckets.reduce(into: 0) { $0 += $1.count }

      await loadAssetsForBucket(timeBuckets[0])
    } catch {
      self.error = error
      logger.error("Failed to fetch time buckets: \(error.localizedDescription)")
    }
  }

  func checkAndLoadMoreAssets(_ lastVisibleIndex: Int) {
    guard !hasLoadedAllAssets, isReady else {
      if hasLoadedAllAssets {
        logger.debug("All assets loaded, no need to load more")
      }

      if !isReady {
        logger.debug("Not ready to load more assets")
      }
      return
    }

    // First, find which bucket contains the lastVisibleIndex
    var assetIndex = 0
    var bucketsToLoad = [Components.Schemas.TimeBucketResponseDto]()
    
    // Find which bucket contains the lastVisibleIndex
    for (_, bucket) in timeBuckets.enumerated() {
      let nextIndex = assetIndex + bucket.count
      
      if lastVisibleIndex >= assetIndex && !loadedBucketIds.contains(bucket.timeBucket) {
        // Add any bucket that contains or precedes our last visible index
        bucketsToLoad.append(bucket)
      }
      
      assetIndex = nextIndex
    }
    
    // If we have buckets to load, start loading them
    if !bucketsToLoad.isEmpty {
      Task {
        for bucket in bucketsToLoad {
          await loadAssetsForBucket(bucket)
        }
        
        if assets.count >= totalAssets {
          hasLoadedAllAssets = true
          logger.info("All assets loaded")
        }
      }
    }
  }

  func loadAssetsForBucket(_ bucket: Components.Schemas.TimeBucketResponseDto) async {
    guard !loadedBucketIds.contains(bucket.timeBucket) else {
      logger.debug("Already loaded assets for bucket \(bucket.timeBucket)")
      return
    }
    self.loadedBucketIds.insert(bucket.timeBucket)

    logger.info("Loading assets for bucket: \(bucket.timeBucket)")

    do {
      let response = try await apiService.client!.getTimeBucket(
        query: .init(
          isArchived: false, size: .month, timeBucket: bucket.timeBucket, withPartners: true,
          withStacked: true))

      let newAssets = try response.ok.body.json

      self.assets.append(contentsOf: newAssets)
      logger.info("Total assets loaded: \(self.assets.count)/\(self.totalAssets)")
      logger.info("Loaded \(newAssets.count) assets from bucket \(bucket.timeBucket)")
    } catch {
      logger.error(
        "Failed to fetch assets for bucket \(bucket.timeBucket): \(error.localizedDescription)")
      self.error = error
    }
  }
}
