import Foundation
import AVFoundation
import OpenAPIRuntime

/// Asset represents a media item (photo or video) in Immich
struct Asset: Codable, Hashable, Identifiable {
    /// The unique identifier of the asset
    let id: String

    /// The thumbhash used for caching and URL generation
    let thumbhash: String?

    /// The type of the asset (photo or video)
    let type: AssetType

    /// The duration of the asset (only for videos)
    let duration: String?

    /// The city where the asset was taken (from EXIF GPS)
    let city: String?

    /// The country where the asset was taken (from EXIF GPS)
    let country: String?

    /// The file creation timestamp in UTC
    let fileCreatedAt: Date?

    /// Whether the asset has been favourited
    let isFavorite: Bool

    /// The server URL used for generating asset URLs
    private let serverUrl: String

    enum AssetType: String, Codable {
        case photo
        case video
    }

    enum ImageSize: String {
        case fullsize = "fullsize"
        case preview = "preview"
        case thumbnail = "thumbnail"
    }

    private static let dateParsers: [ISO8601DateFormatter] = {
        let variants: [[ISO8601DateFormatter.Options]] = [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime],
            [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime],
        ]
        return variants.map { opts in
            let f = ISO8601DateFormatter()
            f.formatOptions = ISO8601DateFormatter.Options(opts)
            return f
        }
    }()

    private static func parseDate(_ string: String) -> Date? {
        for parser in dateParsers {
            if let date = parser.date(from: string) { return date }
        }
        return nil
    }

    init(from dto: Components.Schemas.TimeBucketAssetResponseDto, idx: Int, serverUrl: String) {
        self.id = dto.id[idx]
        self.thumbhash = dto.thumbhash[idx]
        self.type = dto.isImage[idx] ? .photo : .video
        self.duration = dto.duration[idx]
        self.city = dto.city[idx]
        self.country = dto.country[idx]
        self.fileCreatedAt = Self.parseDate(dto.fileCreatedAt[idx])
        self.isFavorite = dto.isFavorite[idx]
        self.serverUrl = serverUrl
    }

    init(from dto: Components.Schemas.AssetResponseDto, serverUrl: String) {
        self.id = dto.id
        self.thumbhash = dto.thumbhash
        self.type = dto._type.value1 == .image ? .photo : .video
        self.duration = dto.duration
        self.city = dto.exifInfo?.city
        self.country = dto.exifInfo?.country
        self.fileCreatedAt = dto.fileCreatedAt
        self.isFavorite = dto.isFavorite
        self.serverUrl = serverUrl
    }

    /// Get the URL for an image at the specified size
    /// - Parameter size: The desired size of the image
    /// - Returns: URL for the image, or nil if the asset has no thumbhash
    func imageUrl(_ size: ImageSize) -> URL? {
        guard let thumbhash = thumbhash else { return nil }
        return URL(
            string: "\(serverUrl)/assets/\(id)/thumbnail?size=\(size.rawValue)&c=\(thumbhash)")
    }

    enum VideoEndpoint {
        case transcoded
        case original
    }

    /// URL for video playback at the specified endpoint
    func videoUrl(_ endpoint: VideoEndpoint = .transcoded) -> URL? {
        guard type == .video else { return nil }
        switch endpoint {
        case .transcoded:
            guard let thumbhash = thumbhash else { return nil }
            return URL(string: "\(serverUrl)/assets/\(id)/video/playback?c=\(thumbhash)")
        case .original:
            return URL(string: "\(serverUrl)/assets/\(id)/original")
        }
    }

    /// Creates an AVAsset with Bearer token authentication for video playback
    func createVideoAsset(token: String?, endpoint: VideoEndpoint = .transcoded) -> AVURLAsset? {
        guard let url = videoUrl(endpoint) else { return nil }

        var headers: [String: String] = [:]
        if let token = token {
            headers["Authorization"] = "Bearer \(token)"
        }

        return AVURLAsset(
            url: url,
            options: ["AVURLAssetHTTPHeaderFieldsKey": headers]
        )
    }



    // MARK: - Display helpers

    /// Location string for the title bar (e.g. "London" or "London, United Kingdom")
    var locationTitle: String {
        switch (city, country) {
        case let (city?, country?): return "\(city) – \(country)"
        case let (city?, nil): return city
        case let (nil, country?): return country
        case (nil, nil): return type == .video ? "Video" : "Photo"
        }
    }

    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .medium
        return f
    }()

    /// Subtitle for the detail title bar (e.g. "8 February 2026 at 13:14:35 · 15,831 of 15,834")
    func detailSubtitle(index: Int, total: Int) -> String {
        var parts: [String] = []
        if let date = fileCreatedAt {
            parts.append(Self.displayDateFormatter.string(from: date))
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let pos = formatter.string(from: NSNumber(value: index + 1)) ?? "\(index + 1)"
        let tot = formatter.string(from: NSNumber(value: total)) ?? "\(total)"
        parts.append("\(pos) of \(tot)")
        return parts.joined(separator: "  ·  ")
    }
}
