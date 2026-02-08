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
    var focusedIndex: FocusState<Int?>.Binding
    let onAssetTap: (Asset) -> Void

    #if os(tvOS)
    static let defaultSpacing: CGFloat = 40
    #else
    static let defaultSpacing: CGFloat = 8
    #endif

    init(
        assets: [Asset],
        columns: Int = 5,
        spacing: CGFloat = AssetGridView.defaultSpacing,
        focusedIndex: FocusState<Int?>.Binding,
        onAssetTap: @escaping (Asset) -> Void = { _ in }
    ) {
        self.assets = assets
        self.columns = columns
        self.spacing = spacing
        self.focusedIndex = focusedIndex
        self.onAssetTap = onAssetTap
    }

    private var totalRows: Int {
        (assets.count + columns - 1) / columns
    }

    private static let bufferRows = 3

    @State private var visibleRows: Range<Int> = 0..<1
    @State private var containerWidth: CGFloat = 0

    private var cellSize: CGFloat {
        guard containerWidth > 0 else { return 0 }
        let totalSpacing = spacing * CGFloat(columns - 1) + spacing * 2
        return (containerWidth - totalSpacing) / CGFloat(columns)
    }

    private var rowHeight: CGFloat {
        cellSize + spacing
    }

    var body: some View {
        #if os(macOS)
        macOSGrid
        #else
        tvOSGrid
        #endif
    }

    #if os(macOS)
    private var macOSGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
                spacing: spacing
            ) {
                ForEach(Array(assets.enumerated()), id: \.offset) { index, asset in
                    Button {
                        onAssetTap(asset)
                    } label: {
                        AssetGridCell(asset: asset)
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                    }
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .focused(focusedIndex, equals: index)
                }
            }
            .padding()
        }
    }
    #else
    private var tvOSGrid: some View {
        ScrollView {
            VStack(spacing: 0) {
                if visibleRows.lowerBound > 0 {
                    Color.clear
                        .frame(height: CGFloat(visibleRows.lowerBound) * rowHeight)
                }

                ForEach(Array(visibleRows), id: \.self) { row in
                    AssetGridRow(
                        assets: assets,
                        row: row,
                        columns: columns,
                        cellSize: cellSize,
                        spacing: spacing,
                        focusedIndex: focusedIndex,
                        onAssetTap: onAssetTap
                    )
                    .frame(height: rowHeight)
                }

                let rowsBelow = totalRows - visibleRows.upperBound
                if rowsBelow > 0 {
                    Color.clear
                        .frame(height: CGFloat(rowsBelow) * rowHeight)
                }
            }
            .frame(height: CGFloat(totalRows) * rowHeight, alignment: .top)
        }
        .onGeometryChange(for: CGFloat.self) { geo in
            geo.size.width
        } action: { newWidth in
            containerWidth = newWidth
        }
        .onScrollGeometryChange(for: Range<Int>.self) { geo in
            let offset = geo.contentOffset.y
            let vpHeight = geo.containerSize.height
            let rowH = self.rowHeight
            let rows = self.totalRows
            guard rowH > 0, rows > 0 else { return 0..<0 }
            let first = max(0, Int(floor(offset / rowH)) - Self.bufferRows)
            let last = min(rows - 1, Int(ceil((offset + vpHeight) / rowH)) + Self.bufferRows)
            return first..<(last + 1)
        } action: { _, newRange in
            visibleRows = newRange
        }
    }
    #endif
}

#if !os(macOS)
private struct AssetGridRow: View {
    let assets: [Asset]
    let row: Int
    let columns: Int
    let cellSize: CGFloat
    let spacing: CGFloat
    var focusedIndex: FocusState<Int?>.Binding
    let onAssetTap: (Asset) -> Void

    var body: some View {
        let startIndex = row * columns
        let endIndex = min(startIndex + columns, assets.count)

        HStack(spacing: spacing) {
            ForEach(startIndex..<endIndex, id: \.self) { index in
                let asset = assets[index]
                Button {
                    onAssetTap(asset)
                } label: {
                    AssetGridCell(asset: asset)
                        .frame(width: cellSize, height: cellSize)
                }
                .focused(focusedIndex, equals: index)
                #if os(tvOS)
                .buttonStyle(.borderless)
                #else
                .buttonStyle(.plain)
                #endif
            }
        }
    }
}
#endif

struct AssetGridCell: View {
    let asset: Asset

    private static let thumbnailSize = CGSize(width: 200, height: 200)
    private static let thumbnailProcessors: [ImageProcessing] = [
        .resize(size: thumbnailSize, crop: true),
    ]

    private var thumbnailRequest: ImageRequest? {
        guard let url = asset.imageUrl(.preview) else { return nil }
        return ImageRequest(url: url, processors: Self.thumbnailProcessors)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
