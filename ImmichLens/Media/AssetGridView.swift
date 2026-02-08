//
//  AssetGridView.swift
//  ImmichLens
//

import NukeUI
import SwiftUI

struct AssetGridView: View {
    let assets: [Asset]
    let columns: Int
    let spacing: CGFloat
    let onAssetTap: (Asset) -> Void

    init(
        assets: [Asset],
        columns: Int = 4,
        spacing: CGFloat = 8,
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
                .buttonStyle(.plain)
            }
        }
        .padding(spacing)
    }
}

struct AssetGridCell: View {
    let asset: Asset
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                // Thumbnail image
                if let thumbnailUrl = asset.imageUrl(.thumbnail) {
                    LazyImage(url: thumbnailUrl) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(
                                    width: geometry.size.width,
                                    height: geometry.size.height
                                )
                                .clipped()
                        } else if state.error != nil {
                            placeholderView(
                                geometry: geometry, systemName: "exclamationmark.triangle")
                        } else {
                            placeholderView(geometry: geometry, systemName: "photo")
                        }
                    }
                } else {
                    placeholderView(geometry: geometry, systemName: "photo")
                }

                // Video indicator overlay
                if asset.type == .video {
                    VideoIndicatorOverlay(duration: asset.duration)
                        .padding(8)
                }

                // Focus effect for tvOS
                if isFocused {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white, lineWidth: 4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func placeholderView(geometry: GeometryProxy, systemName: String) -> some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: geometry.size.width * 0.3)
                .foregroundColor(.gray)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
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
