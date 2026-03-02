#if os(tvOS)
import Foundation
import Observation
import TVServices
import UIKit
import os

@MainActor
@Observable
class TopShelfService {
    private let apiService: APIService
    private var refreshTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 30 * 60 // 30 minutes

    init(apiService: APIService) {
        self.apiService = apiService
    }

    func startRefreshing() {
        stopRefreshing()
        refreshTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(refreshInterval))
            }
        }
    }

    func stopRefreshing() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func triggerRefresh() {
        stopRefreshing()
        startRefreshing()
    }

    // MARK: - Private

    private func refresh() async {
        let settings = TopShelfSettings()
        guard settings.isEnabled else { return }
        guard let client = apiService.client,
              let serverUrl = apiService.serverUrl,
              let token = apiService.token
        else { return }

        let albumId = settings.sourceMode == .album ? settings.selectedAlbumId : nil

        do {
            let dtos = try await fetchAssetDtos(client: client, settings: settings)
            guard !Task.isCancelled else { return }
            try await Self.cacheAssets(dtos, serverUrl: serverUrl, token: token, albumId: albumId)
        } catch {
            guard !Task.isCancelled else { return }
            logger.error("TopShelf refresh failed: \(error.localizedDescription)")
        }
    }

    private func fetchAssetDtos(
        client: Client, settings: TopShelfSettings
    ) async throws -> [Components.Schemas.AssetResponseDto] {
        let body: Components.Schemas.RandomSearchDto

        switch settings.sourceMode {
        case .everything:
            body = .init(size: 5, _type: .init(value1: .image), withPeople: true)
        case .album:
            if let albumId = settings.selectedAlbumId {
                body = .init(albumIds: [albumId], size: 5, _type: .init(value1: .image), withPeople: true)
            } else {
                body = .init(size: 5, _type: .init(value1: .image), withPeople: true)
            }
        }

        let response = try await client.searchRandom(body: .json(body))
        return try response.ok.body.json
    }

    private nonisolated static func cacheAssets(
        _ dtos: [Components.Schemas.AssetResponseDto], serverUrl: String, token: String, albumId: String?
    ) async throws {
        try TopShelfFileManager.ensureDirectories()

        // Clear old images
        if let dir = TopShelfFileManager.imagesDirectory {
            let existing = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
            for file in existing {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent(file))
            }
        }

        var items: [TopShelfItemData] = []
        let session = URLSession.shared

        for dto in dtos {
            guard !Task.isCancelled else { return }
            let asset = Asset(from: dto, serverUrl: serverUrl)
            guard let previewURL = asset.imageUrl(.preview) else { continue }

            let imageFileName = "\(asset.id).jpg"
            guard let localImageURL = TopShelfFileManager.imageURL(for: imageFileName) else { continue }

            var request = URLRequest(url: previewURL)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else { continue }

                let faceCenterY = extractFaceCenterY(from: dto)
                let processed = processImageForTopShelf(data, faceCenterY: faceCenterY)
                try processed.write(to: localImageURL)
            } catch {
                logger.warning("TopShelf: failed to download image for \(asset.id): \(error.localizedDescription)")
                continue
            }

            items.append(TopShelfItemData(
                id: asset.id,
                imageFileName: imageFileName,
                albumId: albumId
            ))
        }

        let cache = TopShelfCache(items: items, lastUpdated: Date())
        let data = try JSONEncoder().encode(cache)
        if let manifestURL = TopShelfFileManager.manifestURL {
            try data.write(to: manifestURL)
        }

        logger.info("TopShelf: cached \(items.count) items")
        await MainActor.run {
            TVTopShelfContentProvider.topShelfContentDidChange()
        }
    }

    /// Extract the average normalized face center Y from all faces in the asset.
    /// Returns nil if no faces detected, otherwise 0.0 = top, 1.0 = bottom.
    private nonisolated static func extractFaceCenterY(
        from dto: Components.Schemas.AssetResponseDto
    ) -> Double? {
        var allCenters: [Double] = []

        // Faces from recognized people
        if let people = dto.people {
            for person in people {
                for face in person.faces {
                    guard face.imageHeight > 0 else { continue }
                    let centerY = Double(face.boundingBoxY1 + face.boundingBoxY2) / 2.0
                    allCenters.append(centerY / Double(face.imageHeight))
                }
            }
        }

        // Unassigned faces
        if let unassigned = dto.unassignedFaces {
            for face in unassigned {
                guard face.imageHeight > 0 else { continue }
                let centerY = Double(face.boundingBoxY1 + face.boundingBoxY2) / 2.0
                allCenters.append(centerY / Double(face.imageHeight))
            }
        }

        guard !allCenters.isEmpty else { return nil }
        return allCenters.reduce(0, +) / Double(allCenters.count)
    }

    /// Fill 3840x2160 (4K) by scaling to cover, centering on face if available.
    /// tvOS will downscale for 1080p displays.
    private nonisolated static func processImageForTopShelf(_ data: Data, faceCenterY: Double?) -> Data {
        guard let image = UIImage(data: data) else { return data }

        let targetSize = CGSize(width: 3840, height: 2160)
        let imageSize = image.size

        // Scale to cover
        let scale = max(targetSize.width / imageSize.width, targetSize.height / imageSize.height)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        // Horizontal: always centered
        let originX = (targetSize.width - scaledSize.width) / 2

        // Vertical: center on face if available, otherwise center with slight upward bias
        let originY: CGFloat
        if let faceCenterY {
            // Map face center to scaled image coordinates, then offset so it lands at ~40% of target height
            // (slightly above center to account for bottom overlay)
            let faceInScaled = CGFloat(faceCenterY) * scaledSize.height
            let targetFocalPoint = targetSize.height * 0.4
            let unclamped = targetFocalPoint - faceInScaled
            // Clamp so we don't go past the image edges
            let minY = targetSize.height - scaledSize.height
            originY = min(0, max(minY, unclamped))
        } else {
            // No face data: center with slight upward bias
            originY = (targetSize.height - scaledSize.height) / 2 - (scaledSize.height - targetSize.height) * 0.1
        }

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.jpegData(withCompressionQuality: 0.85) { _ in
            image.draw(in: CGRect(origin: CGPoint(x: originX, y: originY), size: scaledSize))
        }
    }
}
#endif
