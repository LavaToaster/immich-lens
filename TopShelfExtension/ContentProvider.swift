import TVServices
import os

private let logger = Logger(subsystem: "dev.lav.immichlens.topshelf", category: "ContentProvider")

class ContentProvider: TVTopShelfContentProvider {
    private let settings = TopShelfSettings()

    override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
        logger.info("loadTopShelfContent called, isEnabled=\(self.settings.isEnabled)")

        guard settings.isEnabled,
              let items = loadCachedItems(), !items.isEmpty
        else {
            completionHandler(nil)
            return
        }

        let carouselItems = items.compactMap { makeCarouselItem(from: $0) }
        guard !carouselItems.isEmpty else {
            completionHandler(nil)
            return
        }

        logger.info("Returning \(carouselItems.count) carousel items")
        completionHandler(TVTopShelfCarouselContent(style: .actions, items: carouselItems))
    }

    // MARK: - Private

    private func loadCachedItems() -> [TopShelfItemData]? {
        guard let manifestURL = TopShelfFileManager.manifestURL,
              let data = try? Data(contentsOf: manifestURL),
              let cache = try? JSONDecoder().decode(TopShelfCache.self, from: data)
        else { return nil }
        return cache.items
    }

    private func makeCarouselItem(from itemData: TopShelfItemData) -> TVTopShelfCarouselItem? {
        guard let imageURL = TopShelfFileManager.imageURL(for: itemData.imageFileName),
              FileManager.default.fileExists(atPath: imageURL.path)
        else { return nil }

        let item = TVTopShelfCarouselItem(identifier: itemData.id)
        item.setImageURL(imageURL, for: .screenScale1x)
        item.setImageURL(imageURL, for: .screenScale2x)

        let deepLinkURL: URL?
        if let albumId = itemData.albumId {
            deepLinkURL = URL(string: "immichlens://albums/\(albumId)/assets/\(itemData.id)")
        } else {
            deepLinkURL = URL(string: "immichlens://asset/\(itemData.id)")
        }
        if let url = deepLinkURL {
            item.displayAction = TVTopShelfAction(url: url)
        }


        return item
    }
}
