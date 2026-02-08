import SwiftUI

/// Defines a source that can provide assets for display in a grid.
protocol AssetSource {
    var title: String { get }
    var emptyMessage: String { get }
    func loadAssets(client: Client, serverUrl: String) async throws -> [Asset]
}

/// Fetches all assets across time buckets for the given filter parameters.
func fetchTimeBucketAssets(
    client: Client,
    serverUrl: String,
    personId: String? = nil,
    albumId: String? = nil,
    visibility: Components.Schemas.AssetVisibility? = nil,
    withPartners: Bool? = nil,
    withStacked: Bool? = nil
) async throws -> [Asset] {
    let buckets = try await client.getTimeBuckets(
        query: .init(
            albumId: albumId, personId: personId, visibility: visibility,
            withPartners: withPartners, withStacked: withStacked)
    ).ok.body.json

    guard !buckets.isEmpty else { return [] }

    var allAssets: [Asset] = []
    for bucket in buckets {
        let bucketAssets = try await client.getTimeBucket(
            query: .init(
                albumId: albumId, personId: personId, timeBucket: bucket.timeBucket,
                visibility: visibility, withPartners: withPartners, withStacked: withStacked)
        ).ok.body.json
        let assets = bucketAssets.id.enumerated().map {
            Asset(from: bucketAssets, idx: $0.offset, serverUrl: serverUrl)
        }
        allAssets.append(contentsOf: assets)
    }
    return allAssets
}

/// Shared view for displaying a grid of assets from any AssetSource.
struct AssetCollectionView<Source: AssetSource>: View {
    let source: Source

    @EnvironmentObject var apiService: APIService
    @State private var assets: [Asset] = []
    @State private var isLoading = true
    @State private var currentIndex: Int = 0
    @FocusState private var focusedIndex: Int?

    var body: some View {
        gridContent
            .navigationTitle(source.title)
            .navigationDestination(for: Int.self) { _ in
                AssetDetailView(
                    assets: assets,
                    currentIndex: $currentIndex
                )
                .environmentObject(apiService)
            }
            .task {
                await load()
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
                    description: Text(source.emptyMessage)
                )
            } else {
                AssetGridView(
                    assets: assets,
                    focusedIndex: $focusedIndex,
                    onAssetTap: { asset in
                        if let index = assets.firstIndex(where: { $0.id == asset.id }) {
                            currentIndex = index
                        }
                    }
                )
            }
        }
    }

    private func load() async {
        guard let client = apiService.client, let serverUrl = apiService.serverUrl else {
            logger.error("API client or server URL not available")
            isLoading = false
            return
        }

        defer { isLoading = false }

        do {
            self.assets = try await source.loadAssets(client: client, serverUrl: serverUrl)
            if !assets.isEmpty {
                focusedIndex = 0
            }
        } catch {
            logger.error("Failed to load assets: \(error.localizedDescription)")
        }
    }
}
