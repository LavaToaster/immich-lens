import SwiftUI

extension Album: AssetSource {
    var title: String { name }
    var emptyMessage: String { "No photos found in \(name)" }

    func loadAssets(client: Client, serverUrl: String) async throws -> [Asset] {
        try await fetchTimeBucketAssets(
            client: client, serverUrl: serverUrl, albumId: id, visibility: .timeline)
    }
}

struct AlbumAssetsView: View {
    let album: Album

    var body: some View {
        AssetCollectionView(source: album)
    }
}
