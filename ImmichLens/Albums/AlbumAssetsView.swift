import SwiftUI

struct AlbumAssetsView: View {
    let album: Album
    @EnvironmentObject var apiService: APIService
    @State private var assets: [Asset] = []
    @State private var isLoading = true
    @State private var navigationPath: [Int] = []
    @State private var currentIndex: Int = 0
    @FocusState private var focusedIndex: Int?

    var body: some View {
        gridContent
            .navigationTitle(album.name)
            .navigationDestination(for: Int.self) { _ in
                AssetDetailView(
                    assets: assets,
                    currentIndex: $currentIndex
                )
                .environmentObject(apiService)
            }
            .task {
                await loadAssets()
            }
    }

    private var gridContent: some View {
        Group {
            if isLoading && assets.isEmpty {
                ProgressView("Loading photos...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .focusable()
            } else if !isLoading && assets.isEmpty {
                ContentUnavailableView(
                    "No Photos",
                    systemImage: "photo.on.rectangle",
                    description: Text("No photos found in \(album.name)")
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
                query: .init(albumId: album.id, visibility: .timeline))

            let bucketsResponse = try response.ok.body.json
            logger.info("Loaded \(bucketsResponse.count) time buckets for album \(album.name)")

            guard !bucketsResponse.isEmpty else {
                logger.info("No time buckets for album \(album.name)")
                return
            }

            var allAssets: [Asset] = []
            for bucket in bucketsResponse {
                let bucketResponse = try await client.getTimeBucket(
                    query: .init(
                        albumId: album.id,
                        timeBucket: bucket.timeBucket,
                        visibility: .timeline))

                let bucketAssets = try bucketResponse.ok.body.json
                let assets = bucketAssets.id.enumerated().map {
                    Asset(from: bucketAssets, idx: $0.offset, serverUrl: serverUrl)
                }

                allAssets.append(contentsOf: assets)
            }
            self.assets = allAssets
            if !allAssets.isEmpty {
                focusedIndex = 0
            }
        } catch {
            logger.error(
                "Failed to fetch assets for album \(album.name): \(error.localizedDescription)")
        }
    }
}
