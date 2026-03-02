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
    @Environment(APIService.self) private var apiService
    @State private var navigationPath = NavigationPath()
    #if os(tvOS)
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    #endif

    var body: some View {
        NavigationStack(path: $navigationPath) {
            AssetCollectionView(source: TimelineSource())
        }
        .refreshNavigationOnTabSwitch(tab: .photos) {
            navigationPath = NavigationPath()
        }
        .onChange(of: apiService.token) {
            navigationPath = NavigationPath()
        }
        #if os(tvOS)
        .onChange(of: deepLinkRouter.pending, initial: true) { _, link in
            guard case .asset(let assetId) = link else { return }
            Task {
                await navigateToAsset(id: assetId)
                deepLinkRouter.pending = nil
            }
        }
        #endif
    }

    #if os(tvOS)
    private func navigateToAsset(id: String) async {
        guard let client = apiService.client, let serverUrl = apiService.serverUrl else { return }
        do {
            let response = try await client.getAssetInfo(path: .init(id: id))
            let dto = try response.ok.body.json
            let asset = Asset(from: dto, serverUrl: serverUrl)
            navigationPath = NavigationPath()
            navigationPath.append(asset)
        } catch {
            logger.error("Deep link: failed to fetch asset \(id): \(error.localizedDescription)")
        }
    }
    #endif
}
