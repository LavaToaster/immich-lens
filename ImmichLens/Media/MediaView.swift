import SwiftUI
import os

struct MediaView: View {
  @EnvironmentObject var apiService: APIService
  @State private var isLoading: Bool = false
  @State private var error: Error? = nil
  @State private var data: [Components.Schemas.TimeBucketResponseDto] = []
  @State private var navigationPath = NavigationPath()
  @FocusState private var focusedAssetID: String?

  var body: some View {
    NavigationStack(path: $navigationPath) {
      ScrollView(.vertical) {
        if isLoading {
          ProgressView()
        } else if let error = error {
          Text("Error: \(error.localizedDescription)")
        } else {
          ForEach(data, id: \.timeBucket) { bucket in
            BucketView(
              bucket: bucket,
              focusedAssetID: $focusedAssetID,
            )
          }
        }
      }
      .navigationDestination(for: Components.Schemas.AssetResponseDto.self) { asset in
        MediaDetailView(asset: asset)
      }
    }
    .task {
      await fetchData()
    }
  }

  func fetchData() async {
    isLoading = true
    defer { isLoading = false }
    
    if apiService.client == nil {
      // do nothing, as far as I can tell this is only triggered on logout for some reason
      return
    }

    do {
      let response = try await apiService.client!.getTimeBuckets(
        query: .init(isArchived: false, size: .day, withPartners: true, withStacked: true))

      data = try response.ok.body.json
    } catch {
      self.error = error
    }
  }
}

// Helper component for displaying header information of a bucket
struct BucketHeaderView: View {
  let title: String
  let count: Int

  var body: some View {
    HStack {
      Text(title)
        .font(.headline)
        .padding()

      Text("Count: \(count)")
        .font(.subheadline)
        .padding()
    }
  }
}

// Component to display video duration overlay
struct VideoDurationOverlay: View {
  let duration: String?

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "play.fill")
        .foregroundColor(.white)

      Text(duration?.prefix(8).description ?? "00:00")
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundColor(.white)
    }
    .padding(6)
    .background(Color.black.opacity(0.6))
    .cornerRadius(6)
    .padding(8)
  }

  func formatDuration(_ duration: Int) -> String {
    let minutes = duration / 60
    let seconds = duration % 60
    return String(format: "%02d:%02d", minutes, seconds)
  }
}

// Component to render a single media asset
struct AssetThumbnailView: View {
  @EnvironmentObject var apiService: APIService
  @FocusState.Binding var focusedAssetID: String?
  let asset: Components.Schemas.AssetResponseDto

  var body: some View {
    NavigationLink(value: asset) {
      ZStack(alignment: .topTrailing) {
        AsyncImage(
          url: URL(
            string: apiService.serverUrl!
              + "/assets/\(asset.id)/thumbnail?size=thumbnail&c=\(asset.thumbhash ?? "1234")")
        ) { phase in
          switch phase {
          case .empty:
            ProgressView()
              .frame(width: 256, height: 256)
          case .success(let image):
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: 256, height: 256)
              .cornerRadius(8)
              .clipped()
          case .failure:
            Image(systemName: "photo")
              .frame(width: 256, height: 256)
              .background(Color.gray.opacity(0.3))
              .cornerRadius(8)
          @unknown default:
            EmptyView()
          }
        }

        // Video indicator and duration
        if asset._type.value1 == .video {
          VideoDurationOverlay(duration: asset.duration)
        }
      }
    }
    .frame(width: 256, height: 256)
    .buttonStyle(.borderless)
    .focused($focusedAssetID, equals: asset.id)
  }
}

// Grid component to display assets
struct BucketAssetsGridView: View {
  let assets: [Components.Schemas.AssetResponseDto]
  let logger: Logger
  @FocusState.Binding var focusedAssetID: String?

  // Configure column layout with fixed grid items
  private let columns = [
    GridItem(.adaptive(minimum: 256), spacing: 8)
  ]

  var body: some View {
    LazyVGrid(columns: columns, spacing: 8) {
      ForEach(assets, id: \.id) { asset in
        AssetThumbnailView(
          focusedAssetID: $focusedAssetID,
          asset: asset,
        )
        .id(asset.id)
        .onAppear {
          logger.info("Loaded asset: \(asset.id)")
          // Set focus on first asset only if no asset has been focused yet
          if focusedAssetID == nil {
            focusedAssetID = asset.id
            logger.info("Setting focus on first asset: \(asset.id)")
          }
        }
      }
    }
    .padding(.horizontal, 8)
  }
}

struct BucketView: View {
  @EnvironmentObject var apiService: APIService

  var bucket: Components.Schemas.TimeBucketResponseDto
  var logger = Logger(subsystem: "dev.lav.immichlens", category: "MediaView")
  @FocusState.Binding var focusedAssetID: String?

  @State private var isLoading: Bool = false
  @State private var error: Error? = nil
  @State private var data: [Components.Schemas.AssetResponseDto] = []

  var body: some View {
    VStack(alignment: .leading) {
      BucketHeaderView(title: bucket.timeBucket, count: bucket.count)

      if isLoading {
        ProgressView()
      } else if let error = error {
        Text("Error: \(error.localizedDescription)")
      } else {
        BucketAssetsGridView(
          assets: data,
          logger: logger,
          focusedAssetID: $focusedAssetID,
        )
      }
    }
    .task {
      await fetchData()
    }
  }

  func fetchData() async {
    isLoading = true
    defer { isLoading = false }

    do {
      let response = try await apiService.client!.getTimeBucket(
        query: .init(
          isArchived: false, size: .day, timeBucket: bucket.timeBucket, withPartners: true,
          withStacked: true))
      data = try response.ok.body.json
    } catch {
      self.error = error
      logger.error("Failed to fetch data: \(error.localizedDescription)")
    }
  }
}

//#Preview {
//    MediaView()
//}
