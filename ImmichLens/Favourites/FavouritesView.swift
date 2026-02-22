import SwiftUI

struct FavouritesSource: AssetSource {
    var title: String { "Favourites" }
    var emptyMessage: String { "Your favourite photos will appear here" }

    func loadAssets(client: Client, serverUrl: String) async throws -> [Asset] {
        try await fetchTimeBucketAssets(
            client: client, serverUrl: serverUrl,
            isFavorite: true, visibility: .timeline)
    }
}

struct FavouritesView: View {
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            AssetCollectionView(source: FavouritesSource())
        }
        .refreshNavigationOnTabSwitch(tab: .library(.favourites)) {
            navigationPath = NavigationPath()
        }
    }
}
