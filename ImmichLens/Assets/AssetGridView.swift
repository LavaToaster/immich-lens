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
    let title: String?
    var focusedIndex: FocusState<Int?>.Binding

    #if os(tvOS)
    static let defaultSpacing: CGFloat = 40
    static let defaultColumns: Int = 5
    #else
    static let defaultSpacing: CGFloat = 2
    static let defaultColumns: Int = 0  // 0 = auto-calculate on macOS
    #endif

    var visibleRange: Binding<Range<Int>>?

    init(
        assets: [Asset],
        columns: Int = AssetGridView.defaultColumns,
        spacing: CGFloat = AssetGridView.defaultSpacing,
        title: String? = nil,
        focusedIndex: FocusState<Int?>.Binding,
        visibleRange: Binding<Range<Int>>? = nil
    ) {
        self.assets = assets
        self.columns = columns
        self.spacing = spacing
        self.title = title
        self.focusedIndex = focusedIndex
        self.visibleRange = visibleRange
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
    private static let targetCellSize: CGFloat = 200

    @State private var macColumns: Int = 5

    private var macOSGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: macColumns),
                spacing: spacing
            ) {
                ForEach(Array(assets.enumerated()), id: \.element.id) { index, asset in
                    NavigationLink(value: asset) {
                        AssetGridCell(asset: asset)
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                    }
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .focused(focusedIndex, equals: index)
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { geo in
            geo.size.width
        } action: { width in
            if columns > 0 {
                macColumns = columns
            } else {
                let count = max(3, Int(floor((width + spacing) / (Self.targetCellSize + spacing))))
                macColumns = count
            }
        }
        .onScrollGeometryChange(for: Range<Int>.self) { geo in
            let cols = self.macColumns
            let cellSize = (geo.containerSize.width - CGFloat(cols - 1) * self.spacing) / CGFloat(cols)
            let rowH = cellSize + self.spacing
            guard rowH > 0, !self.assets.isEmpty else { return 0..<0 }
            let offset = max(0, geo.contentOffset.y)
            let firstRow = Int(floor(offset / rowH))
            let lastRow = Int(ceil((offset + geo.containerSize.height) / rowH))
            let firstIdx = firstRow * cols
            let lastIdx = min((lastRow + 1) * cols, self.assets.count)
            return firstIdx..<lastIdx
        } action: { _, newRange in
            visibleRange?.wrappedValue = newRange
        }
    }
    #else
    private static let headerHeight: CGFloat = 80

    private var hasHeader: Bool {
        if let title, !title.isEmpty { return true }
        return false
    }

    private var headerOffset: CGFloat {
        hasHeader ? Self.headerHeight + spacing : 0
    }

    private var tvOSGrid: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let title, !title.isEmpty {
                    Text(title)
                        .font(.title)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, spacing)
                        .frame(height: Self.headerHeight)
                        .padding(.bottom, spacing)
                }

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
                        focusedIndex: focusedIndex
                    )
                    .frame(height: rowHeight)
                }

                let rowsBelow = totalRows - visibleRows.upperBound
                if rowsBelow > 0 {
                    Color.clear
                        .frame(height: CGFloat(rowsBelow) * rowHeight)
                }
            }
            .frame(height: CGFloat(totalRows) * rowHeight + headerOffset, alignment: .top)
        }
        .onGeometryChange(for: CGFloat.self) { geo in
            geo.size.width
        } action: { newWidth in
            containerWidth = newWidth
        }
        .onScrollGeometryChange(for: Range<Int>.self) { geo in
            let offset = max(0, geo.contentOffset.y - headerOffset)
            let vpHeight = geo.containerSize.height
            let rowH = self.rowHeight
            let rows = self.totalRows
            guard rowH > 0, rows > 0 else { return 0..<0 }
            let first = max(0, Int(floor(offset / rowH)) - Self.bufferRows)
            let last = min(rows - 1, Int(ceil((offset + vpHeight) / rowH)) + Self.bufferRows)
            return first..<(last + 1)
        } action: { _, newRange in
            visibleRows = newRange
            let firstIdx = newRange.lowerBound * columns
            let lastIdx = min(newRange.upperBound * columns, assets.count)
            visibleRange?.wrappedValue = firstIdx..<lastIdx
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

    var body: some View {
        let startIndex = row * columns
        let endIndex = min(startIndex + columns, assets.count)

        HStack(spacing: spacing) {
            ForEach(startIndex..<endIndex, id: \.self) { index in
                NavigationLink(value: assets[index]) {
                    AssetGridCell(asset: assets[index])
                        .frame(width: cellSize, height: cellSize)
                }
                .focused(focusedIndex, equals: index)
                #if os(tvOS)
                .buttonStyle(.borderless)
                .overlay(alignment: .bottomLeading) {
                    if assets[index].isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                            .padding(8)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if assets[index].type == .video {
                        VideoIndicatorOverlay(duration: assets[index].duration)
                            .padding(8)
                    }
                }
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
        guard let url = asset.imageUrl(.thumbnail) else { return nil }
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
                        Color.gray.opacity(0.2)
                    }
                }
            } else {
                placeholderView(systemName: "photo")
            }

            #if !os(tvOS)
            if asset.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(8)
            }
            #endif

            #if !os(tvOS)
            if asset.type == .video {
                VideoIndicatorOverlay(duration: asset.duration)
                    .padding(8)
            }
            #endif
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
                .foregroundStyle(.gray)
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
