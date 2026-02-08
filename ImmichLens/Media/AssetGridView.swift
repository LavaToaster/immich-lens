//
//  AssetGridView.swift
//  ImmichLens
//

import Nuke
import NukeUI
import SwiftUI

struct AssetGridView: View {
    let assets: [Asset]
    let columns: Int
    let spacing: CGFloat
    let onAssetTap: (Asset) -> Void

    #if os(tvOS)
    static let defaultSpacing: CGFloat = 40
    #else
    static let defaultSpacing: CGFloat = 8
    #endif

    init(
        assets: [Asset],
        columns: Int = 4,
        spacing: CGFloat = AssetGridView.defaultSpacing,
        onAssetTap: @escaping (Asset) -> Void = { _ in }
    ) {
        self.assets = assets
        self.columns = columns
        self.spacing = spacing
        self.onAssetTap = onAssetTap
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: spacing) {
            ForEach(assets) { asset in
                Button {
                    onAssetTap(asset)
                } label: {
                    AssetGridCell(asset: asset)
                        .aspectRatio(1, contentMode: .fit)
                }
                #if os(tvOS)
                .buttonStyle(.borderless)
                #else
                .buttonStyle(.plain)
                #endif
            }
        }
        .padding(spacing)
    }
}

struct AssetGridCell: View {
    let asset: Asset

    /// Nuke request that crops the thumbnail to a square at the decode level.
    /// The resulting image is already 1:1 so no view-level .clipped() is needed,
    /// which allows the tvOS borderless button style to render focus effects
    /// (shadow, lift, specular lighting) outside the view bounds.
    private var thumbnailRequest: ImageRequest? {
        guard let url = asset.imageUrl(.thumbnail) else { return nil }
        return ImageRequest(url: url, processors: [
            .resize(size: CGSize(width: 300, height: 300), crop: true),
        ])
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Thumbnail image
            if let request = thumbnailRequest {
                LazyImage(request: request) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else if state.error != nil {
                        placeholderView(systemName: "exclamationmark.triangle")
                    } else {
                        placeholderView(systemName: "photo")
                    }
                }
            } else {
                placeholderView(systemName: "photo")
            }

            // Video indicator overlay
            if asset.type == .video {
                VideoIndicatorOverlay(duration: asset.duration)
                    .padding(8)
            }
        }
    }

    private func placeholderView(systemName: String) -> some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .foregroundColor(.gray)
        }
    }
}

struct VideoIndicatorOverlay: View {
    let duration: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "play.fill")
                .font(.caption2)

            if let duration = duration, let formatted = formatDuration(duration) {
                Text(formatted)
                    .font(.caption2)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func formatDuration(_ duration: String) -> String? {
        // Immich returns duration in "H:MM:SS.ffffff" format (e.g., "0:00:05.230000")
        let parts = duration.split(separator: ":")
        guard parts.count == 3 else { return nil }

        let hours = Int(parts[0]) ?? 0
        let minutes = Int(parts[1]) ?? 0
        let secs = Int(Double(String(parts[2])) ?? 0)

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}
