import Nuke
import NukeUI
import SwiftUI

struct AlbumsView: View {
    @Environment(APIService.self) private var apiService
    @State private var albums: [Album] = []
    @State private var isLoading = true

    #if os(tvOS)
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 40), count: 4)
    private let spacing: CGFloat = 40
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    #else
    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 16)]
    private let spacing: CGFloat = 16
    #endif

    @State private var navigationPath = NavigationPath()
    @FocusState private var focusedAlbum: String?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            gridContent
                .navigationDestination(for: Album.self) { album in
                    #if os(tvOS)
                    let assetId = deepLinkAssetId
                    AlbumAssetsView(album: album, initialAssetId: assetId)
                        .environment(apiService)
                        .onAppear { deepLinkAssetId = nil }
                    #else
                    AlbumAssetsView(album: album)
                        .environment(apiService)
                    #endif
                }
                #if os(macOS)
                .navigationTitle("Albums")
                #endif
        }
        .refreshNavigationOnTabSwitch(tab: .library(.albums)) {
            navigationPath = NavigationPath()
        }
        .task(id: apiService.token) {
            await loadAlbums()
            #if os(tvOS)
            await handlePendingDeepLink()
            #endif
        }
        .onChange(of: apiService.token) {
            navigationPath = NavigationPath()
        }
        #if os(tvOS)
        .onChange(of: deepLinkRouter.pending) { _, link in
            guard !isLoading else { return }
            guard case .albumAsset = link else { return }
            Task { await handlePendingDeepLink() }
        }
        #endif
    }

    private var gridContent: some View {
        Group {
            if isLoading && albums.isEmpty {
                ProgressView("Loading albums...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !isLoading && albums.isEmpty {
                ContentUnavailableView(
                    "No Albums",
                    systemImage: "photo.on.rectangle",
                    description: Text("Your albums will appear here")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: spacing) {
                        ForEach(albums) { album in
                            NavigationLink(value: album) {
                                AlbumCell(album: album)
                            }
                            .focused($focusedAlbum, equals: album.id)
                            #if os(tvOS)
                            .buttonStyle(.borderless)
                            #else
                            .buttonStyle(.plain)
                            #endif
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func loadAlbums() async {
        guard let client = apiService.client, let serverUrl = apiService.serverUrl else {
            logger.error("API client or server URL not available")
            isLoading = false
            return
        }

        albums = []
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await client.getAllAlbums()
            let dtos = try response.ok.body.json

            self.albums = dtos
                .map { Album(from: $0, serverUrl: serverUrl) }
                .filter { $0.assetCount > 0 }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            guard !Task.isCancelled else { return }
            logger.error("Failed to fetch albums: \(error.localizedDescription)")
        }
    }

    #if os(tvOS)
    @State private var deepLinkAssetId: String?

    private func handlePendingDeepLink() async {
        guard case .albumAsset(let albumId, let assetId) = deepLinkRouter.pending else { return }
        deepLinkRouter.pending = nil
        await navigateToAlbumAsset(albumId: albumId, assetId: assetId)
    }

    private func navigateToAlbumAsset(albumId: String, assetId: String) async {
        guard let client = apiService.client, let serverUrl = apiService.serverUrl else { return }
        do {
            let albumResponse = try await client.getAlbumInfo(path: .init(id: albumId))
            let albumDto = try albumResponse.ok.body.json
            let album = Album(from: albumDto, serverUrl: serverUrl)

            deepLinkAssetId = assetId
            navigationPath = NavigationPath()
            navigationPath.append(album)
        } catch {
            logger.error("Deep link: failed to navigate to album \(albumId) asset \(assetId): \(error.localizedDescription)")
        }
    }
    #endif
}

private struct AlbumCell: View {
    let album: Album

    private static let thumbnailSize = CGSize(width: 300, height: 300)
    private static let thumbnailProcessors: [ImageProcessing] = [
        .resize(size: thumbnailSize, crop: true),
    ]

    private var thumbnailRequest: ImageRequest? {
        guard let url = album.thumbnailUrl else { return nil }
        return ImageRequest(url: url, processors: Self.thumbnailProcessors)
    }

    var body: some View {
        VStack {
            if let request = thumbnailRequest {
                LazyImage(request: request) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else if state.error != nil {
                        Color.gray.opacity(0.2)
                            .overlay {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(.gray)
                            }
                    } else {
                        Color.gray.opacity(0.2)
                    }
                }
                .aspectRatio(1, contentMode: .fill)
                #if os(macOS)
                .clipShape(.rect(cornerRadius: 8))
                #endif
            } else {
                Color.gray.opacity(0.2)
                    .aspectRatio(1, contentMode: .fill)
                    #if os(macOS)
                    .clipShape(.rect(cornerRadius: 8))
                    #endif
            }

            Text(album.name)
                .font(.caption)
                .lineLimit(1)

            Text("\(album.assetCount) items")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
