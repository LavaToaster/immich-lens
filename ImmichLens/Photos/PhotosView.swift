import SwiftUI

struct TimelineSource: AssetSource {
    var title: String { "" }
    var emptyMessage: String { "Your media will appear here" }

    func loadAssets(client: Client, serverUrl: String) async throws -> [Asset] {
        try await fetchTimeBucketAssets(
            client: client, serverUrl: serverUrl,
            visibility: .timeline, withPartners: true, withStacked: true)
    }
}

struct PhotosView: View {
    @EnvironmentObject var apiService: APIService
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            AssetCollectionView(source: TimelineSource())
        }
    }
}
