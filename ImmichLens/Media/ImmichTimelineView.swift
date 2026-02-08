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

struct ImmichTimelineView: View {
    var body: some View {
        NavigationStack {
            AssetCollectionView(source: TimelineSource())
        }
    }
}
