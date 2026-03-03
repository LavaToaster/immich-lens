import SwiftUI

private func formatDateRange(from start: Date, to end: Date) -> String {
    let cal = Calendar.current
    let startComps = cal.dateComponents([.day, .month, .year], from: start)
    let endComps = cal.dateComponents([.day, .month, .year], from: end)

    if startComps == endComps {
        // Same day: "16 Feb 2026"
        return start.formatted(.dateTime.day().month(.abbreviated).year())
    } else if startComps.year == endComps.year && startComps.month == endComps.month {
        // Same month: "16 – 22 Feb 2026"
        let day1 = start.formatted(.dateTime.day())
        let day2end = end.formatted(.dateTime.day().month(.abbreviated).year())
        return "\(day1) – \(day2end)"
    } else if startComps.year == endComps.year {
        // Same year: "16 Jan – 22 Feb 2026"
        let startPart = start.formatted(.dateTime.day().month(.abbreviated))
        let endPart = end.formatted(.dateTime.day().month(.abbreviated).year())
        return "\(startPart) – \(endPart)"
    } else {
        // Different years: "16 Jan 2025 – 22 Feb 2026"
        let startPart = start.formatted(.dateTime.day().month(.abbreviated).year())
        let endPart = end.formatted(.dateTime.day().month(.abbreviated).year())
        return "\(startPart) – \(endPart)"
    }
}

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
    isFavorite: Bool? = nil,
    visibility: Components.Schemas.AssetVisibility? = nil,
    withPartners: Bool? = nil,
    withStacked: Bool? = nil
) async throws -> [Asset] {
    let buckets = try await client.getTimeBuckets(
        query: .init(
            albumId: albumId, isFavorite: isFavorite, personId: personId,
            visibility: visibility, withPartners: withPartners, withStacked: withStacked)
    ).ok.body.json

    guard !buckets.isEmpty else { return [] }

    var allAssets: [Asset] = []
    for bucket in buckets {
        let bucketAssets = try await client.getTimeBucket(
            query: .init(
                albumId: albumId, isFavorite: isFavorite, personId: personId,
                timeBucket: bucket.timeBucket, visibility: visibility,
                withPartners: withPartners, withStacked: withStacked)
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
    var initialAssetId: String? = nil

    @Environment(APIService.self) private var apiService
    @State private var assets: [Asset] = []
    @State private var isLoading = true
    @State private var visibleRange: Range<Int> = 0..<0
    @State private var initialNavigationDone = false
    @FocusState private var focusedIndex: Int?
    @State private var slideshowLaunch: SlideshowLaunch?

    var body: some View {
        gridContent
            .navigationDestination(for: Asset.self) { asset in
                AssetDetailView(assets: assets, initialAsset: asset)
                    .environment(apiService)
            }
            #if os(macOS)
            .navigationTitle(source.title.isEmpty ? "Photos" : source.title)
            .navigationSubtitle(visibleSubtitle)
            #else
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .task(id: apiService.token) {
                await load(force: true)
            }
            .onChange(of: isLoading) { _, loading in
                guard !loading, !initialNavigationDone, let targetId = initialAssetId else { return }
                initialNavigationDone = true
                if let asset = assets.first(where: { $0.id == targetId }) {
                    navigationToInitialAsset = asset
                }
            }
            .navigationDestination(item: $navigationToInitialAsset) { asset in
                AssetDetailView(assets: assets, initialAsset: asset)
                    .environment(apiService)
            }
            .navigationDestination(item: $slideshowLaunch) { launch in
                AssetDetailView(
                    assets: assets,
                    initialAsset: launch.asset,
                    slideshowMode: launch.mode
                )
                .environment(apiService)
            }
            #if os(macOS)
            .toolbar {
                ToolbarItem {
                    Menu {
                        Button("Play", systemImage: "play.circle") {
                            launchSlideshow(mode: .ordered)
                        }
                        Button("Shuffle", systemImage: "shuffle.circle") {
                            launchSlideshow(mode: .shuffle)
                        }
                    } label: {
                        Label("Slideshow", systemImage: "play.square.stack")
                    }
                    .disabled(photoAssets.isEmpty)
                }
            }
            #endif
    }

    @State private var navigationToInitialAsset: Asset?

    private var gridContent: some View {
        ZStack {
            if isLoading && assets.isEmpty {
                ProgressView("Loading photos...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !isLoading && assets.isEmpty {
                ContentUnavailableView(
                    "No Photos",
                    systemImage: "photo.on.rectangle",
                    description: Text(source.emptyMessage)
                )
            } else {
                #if os(macOS)
                AssetGridView(
                    assets: assets,
                    focusedIndex: $focusedIndex,
                    visibleRange: $visibleRange
                )
                #else
                AssetGridView(
                    assets: assets,
                    title: tvOSTitle,
                    subtitle: tvOSSubtitle,
                    focusedIndex: $focusedIndex,
                    visibleRange: $visibleRange,
                    onSlideshow: photoAssets.isEmpty ? nil : {
                        launchSlideshow(mode: .ordered)
                    },
                    onShuffle: photoAssets.isEmpty ? nil : {
                        launchSlideshow(mode: .shuffle)
                    }
                )
                #endif
            }
        }
    }

    private func load(force: Bool = false) async {
        guard let client = apiService.client, let serverUrl = apiService.serverUrl else {
            isLoading = false
            return
        }

        guard force || assets.isEmpty else { return }

        isLoading = assets.isEmpty
        defer { isLoading = false }

        do {
            let loaded = try await source.loadAssets(client: client, serverUrl: serverUrl)
            self.assets = loaded
        } catch {
            guard !Task.isCancelled else { return }
            logger.error("Failed to load assets: \(error.localizedDescription)")
        }
    }

    private var visibleSubtitle: String {
        guard !assets.isEmpty else { return "" }
        let count = "\(assets.count) \(assets.count == 1 ? "item" : "items")"
        let clamped = visibleRange.clamped(to: assets.startIndex..<assets.endIndex)
        guard !clamped.isEmpty else { return count }
        let dates = assets[clamped].compactMap(\.fileCreatedAt)
        guard let earliest = dates.min(), let latest = dates.max() else { return count }
        let range = formatDateRange(from: earliest, to: latest)
        return "\(range) · \(count)"
    }

    private var visibleDateRange: String {
        guard !assets.isEmpty else { return "" }
        let clamped = visibleRange.clamped(to: assets.startIndex..<assets.endIndex)
        guard !clamped.isEmpty else { return "" }
        let dates = assets[clamped].compactMap(\.fileCreatedAt)
        guard let earliest = dates.min(), let latest = dates.max() else { return "" }
        return formatDateRange(from: earliest, to: latest)
    }

    private var tvOSTitle: String {
        if source.title.isEmpty {
            let dateRange = visibleDateRange
            return dateRange.isEmpty ? "Photos" : dateRange
        }
        return source.title
    }

    private var tvOSSubtitle: String? {
        source.title.isEmpty ? nil : visibleDateRange
    }

    private var photoAssets: [Asset] {
        assets.filter { $0.type == .photo }
    }

    private func launchSlideshow(mode: SlideshowMode) {
        guard let startAsset = (mode == .shuffle ? photoAssets.randomElement() : photoAssets.first) else { return }
        slideshowLaunch = SlideshowLaunch(asset: startAsset, mode: mode)
    }
}
