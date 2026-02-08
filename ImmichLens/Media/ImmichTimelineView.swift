import Nuke
import NukeUI
import SwiftUI

struct ImmichTimelineView: View {
    @EnvironmentObject var apiService: APIService
    @State private var assets: [Asset] = []
    @State private var isLoading = true
    @State private var navigationPath: [Int] = []
    @State private var currentIndex: Int = 0
    @FocusState private var focusedIndex: Int?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            gridContent
                .navigationDestination(for: Int.self) { _ in
                    AssetDetailView(
                        assets: assets,
                        currentIndex: $currentIndex
                    )
                    .environmentObject(apiService)
                }
        }
        .task {
            await loadAssets()
        }
    }

    private var gridContent: some View {
        Group {
            if isLoading && assets.isEmpty {
                ProgressView("Loading your media...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .focusable()
            } else if !isLoading && assets.isEmpty {
                ContentUnavailableView(
                    "No Assets",
                    systemImage: "photo.on.rectangle",
                    description: Text("Your media will appear here")
                )
            } else {
                AssetGridView(
                    assets: assets,
                    focusedIndex: $focusedIndex,
                    onAssetTap: { asset in
                        if let index = assets.firstIndex(where: { $0.id == asset.id }) {
                            currentIndex = index
                            navigationPath.append(index)
                        }
                    }
                )
            }
        }
    }

    private func loadAssets() async {
        guard let client = apiService.client, let serverUrl = apiService.serverUrl else {
            logger.error("API client or server URL not available")
            isLoading = false
            return
        }

        defer { isLoading = false }

        do {
            let response = try await client.getTimeBuckets(
                query: .init(visibility: .timeline, withPartners: true, withStacked: true))

            let bucketsResponse = try response.ok.body.json
            logger.info("Loaded \(bucketsResponse.count) time buckets")

            guard !bucketsResponse.isEmpty else {
                logger.info("No time buckets available, nothing to load")
                return
            }

            var allAssets: [Asset] = []
            for bucket in bucketsResponse {
                logger.info("Time bucket: \(bucket.timeBucket), asset count: \(bucket.count)")

                let bucketResponse = try await client.getTimeBucket(
                    query: .init(
                        timeBucket: bucket.timeBucket, visibility: .timeline, withPartners: true,
                        withStacked: true))

                let bucketAssets = try bucketResponse.ok.body.json
                let assets = bucketAssets.id.enumerated().map {
                    Asset(from: bucketAssets, idx: $0.offset, serverUrl: serverUrl)
                }

                logger.info(
                    "Loaded \(bucketAssets.id.count) assets for time bucket \(bucket.timeBucket)")

                allAssets.append(contentsOf: assets)
            }
            self.assets = allAssets
            if !allAssets.isEmpty {
                focusedIndex = 0
            }
        } catch {
            logger.error("Failed to fetch time buckets: \(error.localizedDescription)")
        }
    }

}
