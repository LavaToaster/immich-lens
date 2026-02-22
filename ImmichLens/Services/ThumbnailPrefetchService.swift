//
//  ThumbnailPrefetchService.swift
//  ImmichLens
//

import Nuke
import Observation
import os

@MainActor
@Observable
class ThumbnailPrefetchService {
    private let apiService: APIService
    private var prefetcher: ImagePrefetcher?
    private var prefetchTask: Task<Void, Never>?

    init(apiService: APIService) {
        self.apiService = apiService
    }

    func startPrefetching() {
        stopPrefetching()

        guard ImagePipeline.shared.configuration.dataCache != nil else {
            logger.warning("Prefetch skipped: no data cache configured on pipeline")
            return
        }

        logger.info("Starting thumbnail prefetch")
        let prefetcher = ImagePrefetcher(destination: .diskCache)
        self.prefetcher = prefetcher

        prefetchTask = Task {
            await prefetchAll(prefetcher: prefetcher)
        }
    }

    func stopPrefetching() {
        prefetchTask?.cancel()
        prefetchTask = nil
        prefetcher?.stopPrefetching()
        prefetcher = nil
    }

    // MARK: - Private

    private func prefetchAll(prefetcher: ImagePrefetcher) async {
        guard let client = apiService.client, let serverUrl = apiService.serverUrl else { return }

        // Prefetch timeline thumbnails first (highest priority)
        await prefetchTimelineThumbnails(
            client: client, serverUrl: serverUrl, prefetcher: prefetcher)

        guard !Task.isCancelled else { return }

        // Then prefetch people, places, and album thumbnails in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.prefetchPeopleThumbnails(
                    client: client, serverUrl: serverUrl, prefetcher: prefetcher)
            }
            group.addTask {
                await self.prefetchPlaceThumbnails(
                    client: client, serverUrl: serverUrl, prefetcher: prefetcher)
            }
            group.addTask {
                await self.prefetchAlbumThumbnails(
                    client: client, serverUrl: serverUrl, prefetcher: prefetcher)
            }
        }

        logger.info("Thumbnail prefetching complete")
    }

    private func prefetchTimelineThumbnails(
        client: Client, serverUrl: String, prefetcher: ImagePrefetcher
    ) async {
        do {
            let buckets = try await client.getTimeBuckets(
                query: .init(visibility: .timeline, withPartners: true, withStacked: true)
            ).ok.body.json

            var totalQueued = 0
            for bucket in buckets {
                guard !Task.isCancelled else { return }

                let bucketAssets = try await client.getTimeBucket(
                    query: .init(
                        timeBucket: bucket.timeBucket,
                        visibility: .timeline,
                        withPartners: true,
                        withStacked: true
                    )
                ).ok.body.json

                let urls = bucketAssets.id.enumerated().compactMap { index, _ in
                    Asset(from: bucketAssets, idx: index, serverUrl: serverUrl)
                        .imageUrl(.thumbnail)
                }

                prefetcher.startPrefetching(with: urls)
                totalQueued += urls.count
            }
            logger.info("Queued \(totalQueued) timeline thumbnails across \(buckets.count) buckets")
        } catch {
            logger.error("Prefetch timeline thumbnails failed: \(error.localizedDescription)")
        }
    }

    private func prefetchPeopleThumbnails(
        client: Client, serverUrl: String, prefetcher: ImagePrefetcher
    ) async {
        do {
            let response = try await client.getAllPeople(query: .init(withHidden: false))
            let dto = try response.ok.body.json

            let urls = dto.people.compactMap {
                Person(from: $0, serverUrl: serverUrl).thumbnailUrl
            }

            prefetcher.startPrefetching(with: urls)
        } catch {
            logger.error("Prefetch people thumbnails failed: \(error.localizedDescription)")
        }
    }

    private func prefetchPlaceThumbnails(
        client: Client, serverUrl: String, prefetcher: ImagePrefetcher
    ) async {
        do {
            let response = try await client.getAssetsByCity()
            let assets = try response.ok.body.json

            let urls = assets.compactMap {
                Place(from: $0, serverUrl: serverUrl).thumbnailUrl
            }

            prefetcher.startPrefetching(with: urls)
        } catch {
            logger.error("Prefetch place thumbnails failed: \(error.localizedDescription)")
        }
    }

    private func prefetchAlbumThumbnails(
        client: Client, serverUrl: String, prefetcher: ImagePrefetcher
    ) async {
        do {
            let response = try await client.getAllAlbums()
            let dtos = try response.ok.body.json

            let urls = dtos.compactMap {
                Album(from: $0, serverUrl: serverUrl).thumbnailUrl
            }

            prefetcher.startPrefetching(with: urls)
        } catch {
            logger.error("Prefetch album thumbnails failed: \(error.localizedDescription)")
        }
    }
}
