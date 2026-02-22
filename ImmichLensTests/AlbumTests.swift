import XCTest
@testable import ImmichLens

final class AlbumTests: XCTestCase {
    private let serverUrl = TestData.serverUrl

    func testThumbnailUrl_withThumbnailAssetId() {
        let dto = TestData.albumResponseDto(albumThumbnailAssetId: "thumb-asset-1")
        let album = Album(from: dto, serverUrl: serverUrl)

        XCTAssertEqual(
            album.thumbnailUrl?.absoluteString,
            "\(serverUrl)/assets/thumb-asset-1/thumbnail?size=preview"
        )
    }

    func testThumbnailUrl_nil() {
        let dto = TestData.albumResponseDto(albumThumbnailAssetId: nil)
        let album = Album(from: dto, serverUrl: serverUrl)
        XCTAssertNil(album.thumbnailUrl)
    }
}
