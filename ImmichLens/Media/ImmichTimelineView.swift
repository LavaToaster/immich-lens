import Nuke
import NukeUI
import SwiftUI

struct ImmichTimelineView: View {
    @EnvironmentObject var apiService: APIService
    @Namespace private var namespace
    @State private var assets: [Asset] = []
    @State private var isLoading = true
    @State private var selectedAssetIndex: Int?

    var body: some View {
        ScrollView {
            if isLoading && assets.isEmpty {
                ProgressView("Loading your media...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            } else if !isLoading && assets.isEmpty {
                ContentUnavailableView(
                    "No Assets",
                    systemImage: "photo.on.rectangle",
                    description: Text("Your media will appear here")
                )
            } else {
                AssetGridView(
                    assets: assets,
                    columns: 4,
                    spacing: 8,
                    onAssetTap: { asset in
                        if let index = assets.firstIndex(where: { $0.id == asset.id }) {
                            selectedAssetIndex = index
                        }
                    }
                )
            }
        }
        .task {
            await loadAssets()
        }
        .scrollClipDisabled()
        .fullScreenCover(
            isPresented: Binding(
                get: { selectedAssetIndex != nil },
                set: { if !$0 { selectedAssetIndex = nil } }
            )
        ) {
            if let index = selectedAssetIndex {
                AssetDetailView(
                    assets: assets,
                    currentIndex: Binding(
                        get: { selectedAssetIndex ?? index },
                        set: { selectedAssetIndex = $0 }
                    )
                )
                .environmentObject(apiService)
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

                self.assets.append(contentsOf: assets)
            }
        } catch {
            logger.error("Failed to fetch time buckets: \(error.localizedDescription)")
        }
    }

}
