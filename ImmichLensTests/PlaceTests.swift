import XCTest
@testable import ImmichLens

final class PlaceTests: XCTestCase {
    private let serverUrl = TestData.serverUrl

    func testCity_fromExifData() {
        let dto = TestData.assetResponseDto(id: "asset-1", city: "London")
        let place = Place(from: dto, serverUrl: serverUrl)
        XCTAssertEqual(place.city, "London")
    }

    func testCity_fallback() {
        let dto = TestData.assetResponseDto(id: "asset-1")
        let place = Place(from: dto, serverUrl: serverUrl)
        XCTAssertEqual(place.city, "Unknown")
    }

    func testThumbnailUrl() {
        let dto = TestData.assetResponseDto(id: "asset-1")
        let place = Place(from: dto, serverUrl: serverUrl)

        XCTAssertEqual(
            place.thumbnailUrl?.absoluteString,
            "\(serverUrl)/assets/asset-1/thumbnail?size=thumbnail"
        )
    }
}
