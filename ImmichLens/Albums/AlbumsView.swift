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
                    AlbumAssetsView(album: album)
                        .environment(apiService)
                }
                #if os(macOS)
                .navigationTitle("Albums")
                #endif
        }
        .refreshNavigationOnTabSwitch(tab: .library(.albums)) {
            navigationPath = NavigationPath()
        }
        .task {
            await loadAlbums()
        }
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

        defer { isLoading = false }

        do {
            let response = try await client.getAllAlbums()
            let dtos = try response.ok.body.json

            self.albums = dtos
                .map { Album(from: $0, serverUrl: serverUrl) }
                .filter { $0.assetCount > 0 }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            logger.error("Failed to fetch albums: \(error.localizedDescription)")
        }
    }
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
                    }
                }
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
