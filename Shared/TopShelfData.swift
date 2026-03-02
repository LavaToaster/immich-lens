import Foundation

// MARK: - Settings

struct TopShelfSettings {
    private static let suiteName = "group.dev.lav.ImmichLens"
    private static let enabledKey = "topShelf.isEnabled"
    private static let sourceModeKey = "topShelf.sourceMode"
    private static let albumIdKey = "topShelf.selectedAlbumId"
    private static let albumNameKey = "topShelf.selectedAlbumName"

    private let defaults: UserDefaults?

    init() {
        defaults = UserDefaults(suiteName: Self.suiteName)
    }

    var isEnabled: Bool {
        get { defaults?.bool(forKey: Self.enabledKey) ?? false }
        nonmutating set { defaults?.set(newValue, forKey: Self.enabledKey) }
    }

    var sourceMode: SourceMode {
        get {
            guard let raw = defaults?.string(forKey: Self.sourceModeKey),
                  let mode = SourceMode(rawValue: raw) else { return .everything }
            return mode
        }
        nonmutating set { defaults?.set(newValue.rawValue, forKey: Self.sourceModeKey) }
    }

    var selectedAlbumId: String? {
        get { defaults?.string(forKey: Self.albumIdKey) }
        nonmutating set { defaults?.set(newValue, forKey: Self.albumIdKey) }
    }

    var selectedAlbumName: String? {
        get { defaults?.string(forKey: Self.albumNameKey) }
        nonmutating set { defaults?.set(newValue, forKey: Self.albumNameKey) }
    }

    enum SourceMode: String, Hashable {
        case everything
        case album
    }
}

// MARK: - Cache data

struct TopShelfItemData: Codable {
    let id: String
    let imageFileName: String
    /// Album ID if sourced from a specific album, used for deep link routing
    let albumId: String?
}

struct TopShelfCache: Codable {
    let items: [TopShelfItemData]
    let lastUpdated: Date
}

// MARK: - File manager

enum TopShelfFileManager {
    private static let suiteName = "group.dev.lav.ImmichLens"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
    }

    /// On tvOS, writing to the app group root is not permitted — use Library/Caches instead.
    private static var cachesURL: URL? {
        containerURL?.appendingPathComponent("Library/Caches", isDirectory: true)
    }

    static var imagesDirectory: URL? {
        cachesURL?.appendingPathComponent("TopShelfImages", isDirectory: true)
    }

    static var manifestURL: URL? {
        cachesURL?.appendingPathComponent("topshelf-manifest.json")
    }

    static func imageURL(for fileName: String) -> URL? {
        imagesDirectory?.appendingPathComponent(fileName)
    }

    static func ensureDirectories() throws {
        if let dir = imagesDirectory {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    static func clearCache() {
        if let dir = imagesDirectory {
            try? FileManager.default.removeItem(at: dir)
        }
        if let manifest = manifestURL {
            try? FileManager.default.removeItem(at: manifest)
        }
    }
}
