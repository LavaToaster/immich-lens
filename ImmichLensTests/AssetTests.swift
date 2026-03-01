import XCTest
@testable import ImmichLens

final class AssetTests: XCTestCase {
    private let serverUrl = TestData.serverUrl

    private func makeAsset(
        id: String = "asset-1",
        thumbhash: String? = "abc123",
        isImage: Bool = true,
        duration: String? = nil,
        city: String? = nil,
        country: String? = nil,
        fileCreatedAt: String = "2025-01-01T00:00:00.000Z",
        isFavorite: Bool = false
    ) -> Asset {
        let dto = TestData.timeBucketDto(
            id: id,
            thumbhash: thumbhash,
            isImage: isImage,
            duration: duration,
            city: city,
            country: country,
            fileCreatedAt: fileCreatedAt,
            isFavorite: isFavorite
        )
        return Asset(from: dto, idx: 0, serverUrl: serverUrl)
    }

    // MARK: - imageUrl

    func testImageUrl_withThumbhash() {
        let asset = makeAsset(id: "img-1", thumbhash: "hash99")
        let url = asset.imageUrl(.preview)
        XCTAssertEqual(url?.absoluteString, "\(serverUrl)/assets/img-1/thumbnail?size=preview&c=hash99")
    }

    func testImageUrl_withoutThumbhash() {
        let asset = makeAsset(thumbhash: nil)
        XCTAssertNil(asset.imageUrl(.preview))
    }

    // MARK: - videoUrl

    func testVideoUrl_forVideo() {
        let asset = makeAsset(id: "vid-1", thumbhash: "vhash", isImage: false)
        XCTAssertEqual(asset.videoUrl()?.absoluteString, "\(serverUrl)/assets/vid-1/video/playback?c=vhash")
    }

    func testVideoUrl_forPhoto() {
        let asset = makeAsset(isImage: true)
        XCTAssertNil(asset.videoUrl())
    }

    // MARK: - createVideoAsset

    func testCreateVideoAsset_withToken() {
        let asset = makeAsset(isImage: false)
        let avAsset = asset.createVideoAsset(token: "my-token")
        XCTAssertNotNil(avAsset)
    }

    func testCreateVideoAsset_forPhoto() {
        let asset = makeAsset(isImage: true)
        XCTAssertNil(asset.createVideoAsset(token: "my-token"))
    }

    // MARK: - locationTitle

    func testLocationTitle_cityAndCountry() {
        let asset = makeAsset(city: "London", country: "United Kingdom")
        XCTAssertEqual(asset.locationTitle, "London – United Kingdom")
    }

    func testLocationTitle_cityOnly() {
        let asset = makeAsset(city: "London")
        XCTAssertEqual(asset.locationTitle, "London")
    }

    func testLocationTitle_countryOnly() {
        let asset = makeAsset(country: "United Kingdom")
        XCTAssertEqual(asset.locationTitle, "United Kingdom")
    }

    func testLocationTitle_none_photo() {
        let asset = makeAsset(isImage: true)
        XCTAssertEqual(asset.locationTitle, "Photo")
    }

    func testLocationTitle_none_video() {
        let asset = makeAsset(isImage: false)
        XCTAssertEqual(asset.locationTitle, "Video")
    }

    // MARK: - detailSubtitle

    func testDetailSubtitle_withDate() {
        let asset = makeAsset(fileCreatedAt: "2025-01-01T12:00:00.000Z")
        let subtitle = asset.detailSubtitle(index: 2, total: 100)
        XCTAssertTrue(subtitle.contains("3"), "Expected position 3 (index+1)")
        XCTAssertTrue(subtitle.contains("100"), "Expected total 100")
        XCTAssertTrue(subtitle.contains("·"), "Expected separator")
    }

    func testDetailSubtitle_withoutDate() {
        // Use an unparseable date string so fileCreatedAt is nil
        let dto = TestData.timeBucketDto(fileCreatedAt: "not-a-date")
        let asset = Asset(from: dto, idx: 0, serverUrl: serverUrl)
        let subtitle = asset.detailSubtitle(index: 0, total: 5)
        XCTAssertEqual(subtitle, "1 of 5")
    }
}
