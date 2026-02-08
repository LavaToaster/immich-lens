import Foundation

struct Album: Identifiable, Hashable {
    let id: String
    let name: String
    let assetCount: Int
    let thumbnailUrl: URL?

    init(from dto: Components.Schemas.AlbumResponseDto, serverUrl: String) {
        self.id = dto.id
        self.name = dto.albumName
        self.assetCount = dto.assetCount
        if let thumbnailAssetId = dto.albumThumbnailAssetId {
            self.thumbnailUrl = URL(
                string: "\(serverUrl)/assets/\(thumbnailAssetId)/thumbnail?size=preview")
        } else {
            self.thumbnailUrl = nil
        }
    }
}
