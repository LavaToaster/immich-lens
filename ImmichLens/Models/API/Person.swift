import Foundation

struct Person: Identifiable, Hashable {
    let id: String
    let name: String
    let thumbnailUrl: URL?

    init(from dto: Components.Schemas.PersonResponseDto, serverUrl: String) {
        self.id = dto.id
        self.name = dto.name
        self.thumbnailUrl = URL(string: "\(serverUrl)/people/\(dto.id)/thumbnail")
    }
}
