import Foundation

struct Place: Identifiable, Hashable {
    let id: String
    let city: String
    let thumbnailUrl: URL?

    init(from dto: Components.Schemas.AssetResponseDto, serverUrl: String) {
        let city = dto.exifInfo?.city ?? "Unknown"
        self.id = city
        self.city = city
        self.thumbnailUrl = URL(string: "\(serverUrl)/assets/\(dto.id)/thumbnail?size=thumbnail")
    }
}
