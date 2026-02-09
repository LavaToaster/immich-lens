import SwiftUI

struct PlaceSource: AssetSource {
    let place: Place

    var title: String { place.city }
    var emptyMessage: String { "No photos found in \(place.city)" }

    func loadAssets(client: Client, serverUrl: String) async throws -> [Asset] {
        var allAssets: [Asset] = []
        var page: Double = 1

        while true {
            let response = try await client.searchAssets(
                body: .json(.init(city: place.city, page: page, size: 1000))
            ).ok.body.json

            let assets = response.assets.items.map { Asset(from: $0, serverUrl: serverUrl) }
            allAssets.append(contentsOf: assets)

            if response.assets.nextPage == nil {
                break
            }
            page += 1
        }

        return allAssets
    }
}

struct PlaceAssetsView: View {
    let place: Place

    var body: some View {
        AssetCollectionView(source: PlaceSource(place: place))
    }
}
