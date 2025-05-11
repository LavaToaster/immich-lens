import Foundation
import OpenAPIRuntime

/// Asset represents a media item (photo or video) in Immich
struct Asset: Codable, Hashable {
    /// The unique identifier of the asset
    let id: String
    
    /// The thumbhash used for caching and URL generation
    let thumbhash: String?
    
    /// The type of the asset (photo or video)
    let type: AssetType
    
    /// The duration of the asset (only for videos)
    let duration: String?
    
    /// The server URL used for generating asset URLs
    private let serverUrl: String
    
    enum AssetType: String, Codable {
        case photo
        case video
    }
    
    enum ImageSize: String {
        case fullsize = "full"
        case preview = "preview"
        case thumbnail = "thumbnail"
    }
    
    init(from dto: Components.Schemas.AssetResponseDto, serverUrl: String) {
        self.id = dto.id
        self.thumbhash = dto.thumbhash
        self.type = dto._type.value1 == Components.Schemas.AssetTypeEnum.video ? .video : .photo
        self.duration = dto.duration
        self.serverUrl = serverUrl
    }
    
    /// Get the URL for an image at the specified size
    /// - Parameter size: The desired size of the image
    /// - Returns: URL for the image, or nil if the asset has no thumbhash
    func imageUrl(size: ImageSize) -> URL? {
        guard let thumbhash = thumbhash else { return nil }
        return URL(string: "\(serverUrl)/assets/\(id)/thumbnail?size=\(size.rawValue)&c=\(thumbhash)")
    }
    
    /// URL for video playback (only valid for video assets)
    var videoUrl: URL? {
        guard type == .video, let thumbhash = thumbhash else { return nil }
        return URL(string: "\(serverUrl)/assets/\(id)/video/playback?c=\(thumbhash)")
    }
}

extension Asset: Identifiable {}
