import Foundation

struct SavedAccount: Codable, Identifiable, Hashable {
    let id: UUID
    let serverUrl: String
    let email: String

    /// Display-friendly server URL (strips /api suffix)
    var displayServerUrl: String {
        if serverUrl.hasSuffix("/api") {
            return String(serverUrl.dropLast(4))
        }
        return serverUrl
    }

    /// Keychain key for this account's token
    var keychainKey: String {
        "immich_token_\(id.uuidString)"
    }
}
