import XCTest
@testable import ImmichLens

final class PersonTests: XCTestCase {
    private let serverUrl = TestData.serverUrl

    func testThumbnailUrl() {
        let dto = TestData.personResponseDto(id: "person-1", name: "Alice")
        let person = Person(from: dto, serverUrl: serverUrl)

        XCTAssertEqual(
            person.thumbnailUrl?.absoluteString,
            "\(serverUrl)/people/person-1/thumbnail"
        )
    }
}
