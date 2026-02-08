import SwiftUI

extension Person: AssetSource {
    var title: String { name }
    var emptyMessage: String { "No photos found for \(name)" }

    func loadAssets(client: Client, serverUrl: String) async throws -> [Asset] {
        try await fetchTimeBucketAssets(
            client: client, serverUrl: serverUrl, personId: id, visibility: .timeline)
    }
}

struct PersonAssetsView: View {
    let person: Person

    var body: some View {
        AssetCollectionView(source: person)
    }
}
