import Foundation
@testable import ImmichLens

/// Factory functions for constructing generated DTOs in tests.
/// Each function fills required fields with sensible defaults so tests
/// only need to specify the fields they care about.
enum TestData {
    static let serverUrl = "https://immich.example.com/api"
    private static let now = Date()

    // MARK: - TimeBucketAssetResponseDto (single-element arrays)

    static func timeBucketDto(
        id: String = "asset-1",
        thumbhash: String? = "abc123",
        isImage: Bool = true,
        duration: String? = nil,
        city: String? = nil,
        country: String? = nil,
        fileCreatedAt: String = "2025-01-01T00:00:00.000Z",
        isFavorite: Bool = false
    ) -> Components.Schemas.TimeBucketAssetResponseDto {
        Components.Schemas.TimeBucketAssetResponseDto(
            city: [city],
            country: [country],
            duration: [duration],
            fileCreatedAt: [fileCreatedAt],
            id: [id],
            isFavorite: [isFavorite],
            isImage: [isImage],
            isTrashed: [false],
            livePhotoVideoId: [nil],
            localOffsetHours: [0],
            ownerId: ["owner-1"],
            projectionType: [nil],
            ratio: [1.0],
            thumbhash: [thumbhash],
            visibility: [.timeline]
        )
    }

    // MARK: - AssetResponseDto

    static func assetResponseDto(
        id: String = "asset-1",
        thumbhash: String? = "abc123",
        type: Components.Schemas.AssetTypeEnum = .image,
        duration: String = "0:00:00",
        city: String? = nil,
        country: String? = nil,
        isFavorite: Bool = false
    ) -> Components.Schemas.AssetResponseDto {
        let exif: Components.Schemas.ExifResponseDto? =
            (city != nil || country != nil)
            ? Components.Schemas.ExifResponseDto(city: city, country: country)
            : nil

        return Components.Schemas.AssetResponseDto(
            checksum: "checksum",
            createdAt: now,
            deviceAssetId: "device-asset-1",
            deviceId: "device-1",
            duration: duration,
            exifInfo: exif,
            fileCreatedAt: now,
            fileModifiedAt: now,
            hasMetadata: true,
            id: id,
            isArchived: false,
            isEdited: false,
            isFavorite: isFavorite,
            isOffline: false,
            isTrashed: false,
            localDateTime: now,
            originalFileName: "test.jpg",
            originalPath: "/test.jpg",
            ownerId: "owner-1",
            thumbhash: thumbhash,
            _type: .init(value1: type),
            updatedAt: now,
            visibility: .init(value1: .timeline)
        )
    }

    // MARK: - AlbumResponseDto

    static func albumResponseDto(
        id: String = "album-1",
        albumName: String = "Test Album",
        assetCount: Int = 0,
        albumThumbnailAssetId: String? = nil
    ) -> Components.Schemas.AlbumResponseDto {
        Components.Schemas.AlbumResponseDto(
            albumName: albumName,
            albumThumbnailAssetId: albumThumbnailAssetId,
            albumUsers: [],
            assetCount: assetCount,
            assets: [],
            createdAt: now,
            description: "",
            hasSharedLink: false,
            id: id,
            isActivityEnabled: false,
            owner: userResponseDto(),
            ownerId: "owner-1",
            shared: false,
            updatedAt: now
        )
    }

    // MARK: - PersonResponseDto

    static func personResponseDto(
        id: String = "person-1",
        name: String = "Test Person"
    ) -> Components.Schemas.PersonResponseDto {
        Components.Schemas.PersonResponseDto(
            id: id,
            isHidden: false,
            name: name,
            thumbnailPath: "/path"
        )
    }

    // MARK: - UserResponseDto

    static func userResponseDto() -> Components.Schemas.UserResponseDto {
        Components.Schemas.UserResponseDto(
            avatarColor: .init(value1: .primary),
            email: "test@example.com",
            id: "user-1",
            name: "Test User",
            profileChangedAt: now,
            profileImagePath: ""
        )
    }
}
