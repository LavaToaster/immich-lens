import Foundation
import SwiftUI

@MainActor
@Observable
class AccountStore {
    private(set) var accounts: [SavedAccount] = []
    var activeAccountId: UUID?

    var activeAccount: SavedAccount? {
        accounts.first { $0.id == activeAccountId }
    }

    /// Accounts grouped by display server URL, with servers sorted alphabetically
    var accountsByServer: [(server: String, accounts: [SavedAccount])] {
        let grouped = Dictionary(grouping: accounts, by: \.displayServerUrl)
        return grouped.keys.sorted().map { key in
            (server: key, accounts: grouped[key]!)
        }
    }

    private let userDefaultsKey = "immich_saved_accounts"
    private let activeAccountKey = "immich_active_account_id"

    // MARK: - Initialise

    func initialise(apiService: APIService) async {
        loadFromDisk()

        logger.info("AccountStore loaded \(self.accounts.count) account(s), activeId=\(self.activeAccountId?.uuidString ?? "nil")")
        for account in accounts {
            logger.info("  Account: \(account.email) @ \(account.displayServerUrl) id=\(account.id.uuidString) keychainKey=\(account.keychainKey)")
        }

        // Test-mode bypass
        if ProcessInfo.processInfo.environment["IMMICH_TEST_SERVER_URL"] != nil {
            await apiService.initialise()
            return
        }

        // Migrate legacy single-account keychain if needed
        if accounts.isEmpty {
            await migrateFromLegacyKeychain(apiService: apiService)
        }

        // Activate the last-used account
        if let activeId = activeAccountId,
            let account = accounts.first(where: { $0.id == activeId })
        {
            await activate(account: account, apiService: apiService)
        }

        apiService.isReady = true
    }

    // MARK: - Account Management

    @discardableResult
    func addAccount(serverUrl: String, email: String, token: String) throws -> SavedAccount {
        let tokenPrefix = String(token.prefix(8))

        // Deduplicate by server+email: update token for existing account
        if let existing = accounts.first(where: {
            $0.serverUrl == serverUrl && $0.email == email
        }) {
            logger.info("Updating existing account \(existing.email) keychainKey=\(existing.keychainKey) token=\(tokenPrefix)...")
            try KeychainManager.shared.save(token, forKey: existing.keychainKey)
            activeAccountId = existing.id
            saveToDisk()
            return existing
        }

        let account = SavedAccount(id: UUID(), serverUrl: serverUrl, email: email)
        logger.info("Adding new account \(email) keychainKey=\(account.keychainKey) token=\(tokenPrefix)...")
        try KeychainManager.shared.save(token, forKey: account.keychainKey)
        accounts.append(account)
        activeAccountId = account.id
        saveToDisk()
        return account
    }

    func removeAccount(_ account: SavedAccount, apiService: APIService) async {
        KeychainManager.shared.delete(forKey: account.keychainKey)
        accounts.removeAll { $0.id == account.id }

        if activeAccountId == account.id {
            if let next = accounts.first {
                await activate(account: next, apiService: apiService)
            } else {
                activeAccountId = nil
                apiService.deactivate()
            }
        }

        saveToDisk()
    }

    func activate(account: SavedAccount, apiService: APIService) async {
        logger.info("Activating account: \(account.email) @ \(account.displayServerUrl) id=\(account.id.uuidString)")

        guard let token = KeychainManager.shared.get(forKey: account.keychainKey) else {
            logger.error("No token found in keychain for key: \(account.keychainKey)")
            accounts.removeAll { $0.id == account.id }
            saveToDisk()
            apiService.deactivate()
            return
        }

        let tokenPrefix = String(token.prefix(8))
        logger.info("Found token for \(account.email): \(tokenPrefix)... serverUrl=\(account.serverUrl)")

        let success = await apiService.activate(serverUrl: account.serverUrl, token: token)
        logger.info("Activation result for \(account.email): \(success ? "success" : "failed")")

        if success {
            // Verify the token actually belongs to the expected user
            if let client = apiService.client {
                do {
                    let userResponse = try await client.getMyUser()
                    let actualEmail = try userResponse.ok.body.json.email
                    if actualEmail != account.email {
                        logger.error("TOKEN MISMATCH: expected \(account.email) but token belongs to \(actualEmail). Removing stale token.")
                        KeychainManager.shared.delete(forKey: account.keychainKey)
                        accounts.removeAll { $0.id == account.id }
                        activeAccountId = nil
                        saveToDisk()
                        apiService.deactivate()
                        return
                    }
                } catch {
                    logger.warning("Could not verify user identity: \(error.localizedDescription)")
                }
            }

            activeAccountId = account.id
            saveToDisk()
        } else {
            apiService.deactivate()
        }
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
            let decoded = try? JSONDecoder().decode([SavedAccount].self, from: data)
        {
            accounts = decoded
        }
        if let idString = UserDefaults.standard.string(forKey: activeAccountKey),
            let id = UUID(uuidString: idString)
        {
            activeAccountId = id
        }
    }

    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
        if let id = activeAccountId {
            UserDefaults.standard.set(id.uuidString, forKey: activeAccountKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeAccountKey)
        }
    }

    // MARK: - Legacy Migration

    private func migrateFromLegacyKeychain(apiService: APIService) async {
        let isTestRunner = ProcessInfo.processInfo.environment["IMMICH_TEST_EMAIL"] != nil
        guard !isTestRunner else { return }

        guard let token = KeychainManager.shared.get(forKey: "immich_token"),
            let serverUrl = KeychainManager.shared.get(forKey: "immich_server_url")
        else { return }

        // Fetch email from the API
        var email = "Unknown"
        if let url = URL(string: serverUrl) {
            let client = apiService.createClient(url: url, token: token)
            do {
                let response = try await client.getMyUser()
                email = try response.ok.body.json.email
            } catch {
                logger.warning("Migration: could not fetch user email: \(error.localizedDescription)")
            }
        }

        let account = SavedAccount(id: UUID(), serverUrl: serverUrl, email: email)
        do {
            try KeychainManager.shared.save(token, forKey: account.keychainKey)
        } catch {
            logger.error("Migration: failed to save token: \(error)")
            return
        }

        accounts.append(account)
        activeAccountId = account.id
        saveToDisk()

        // Clean up legacy keys
        KeychainManager.shared.delete(forKey: "immich_token")
        KeychainManager.shared.delete(forKey: "immich_server_url")

        logger.info("Migrated legacy account to multi-account store")
    }
}
