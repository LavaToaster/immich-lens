import Foundation

enum SlideshowMode: Equatable {
    case off, ordered, shuffle
}

struct SlideshowLaunch: Hashable {
    let id = UUID()
    let asset: Asset
    let mode: SlideshowMode

    static func == (lhs: SlideshowLaunch, rhs: SlideshowLaunch) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
