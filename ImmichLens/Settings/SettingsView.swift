import SwiftUI

struct SettingsView: View {
    @Environment(APIService.self) private var apiService
    @Environment(AccountStore.self) private var accountStore
    @State private var showingAddAccount = false
    @State private var accountToRemove: SavedAccount?

    var body: some View {
        #if os(macOS)
            macOSSettings
        #else
            tvOSSettings
        #endif
    }

    // MARK: - macOS

    #if os(macOS)
        private var macOSSettings: some View {
            Form {
                accountsSection
                versionSection
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAddAccount) {
                ServerConnectionView(onLoginComplete: { showingAddAccount = false })
                    .frame(minWidth: 500, minHeight: 400)
            }
            .confirmationDialog(
                "Remove account?",
                isPresented: removeDialogBinding
            ) {
                removeDialogActions
            } message: {
                removeDialogMessage
            }
        }

        private var accountsSection: some View {
            Section("Accounts") {
                ForEach(accountStore.accountsByServer, id: \.server) { group in
                    ForEach(group.accounts) { account in
                        accountRow(account)
                    }
                }

                Button("Add Account...") {
                    showingAddAccount = true
                }
            }
        }

        private func accountRow(_ account: SavedAccount) -> some View {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.email)
                    Text(account.displayServerUrl)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if account.id == accountStore.activeAccountId {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                } else {
                    Button("Switch") {
                        Task {
                            await accountStore.activate(
                                account: account, apiService: apiService)
                        }
                    }
                    .buttonStyle(.borderless)
                }

                Button(role: .destructive) {
                    accountToRemove = account
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }

        private var versionSection: some View {
            Section {
                LabeledContent("Version") {
                    Text(appVersion)
                }
            }
        }
    #endif

    // MARK: - tvOS

    #if os(tvOS)
        private var tvOSSettings: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 48) {
                    tvOSAccountsSection
                    tvOSActionsSection
                    tvOSAboutSection
                }
                .padding(48)
            }
            .sheet(isPresented: $showingAddAccount) {
                ServerConnectionView(onLoginComplete: { showingAddAccount = false })
            }
            .confirmationDialog(
                "Remove account?",
                isPresented: removeDialogBinding
            ) {
                removeDialogActions
            } message: {
                removeDialogMessage
            }
        }

        private var tvOSAccountsSection: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Accounts")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                ForEach(accountStore.accounts) { account in
                    let isActive = account.id == accountStore.activeAccountId
                    HStack(spacing: 24) {
                        Button {
                            guard !isActive else { return }
                            Task {
                                await accountStore.activate(
                                    account: account, apiService: apiService)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(account.email)
                                        .font(.body)
                                    Text(account.displayServerUrl)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if isActive {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Button {
                            accountToRemove = account
                        } label: {
                            Image(systemName: "trash")
                                .frame(maxHeight: .infinity)
                        }
                        .frame(width: 80)
                    }
                }
            }
        }

        private var tvOSActionsSection: some View {
            Button {
                showingAddAccount = true
            } label: {
                Label("Add Account", systemImage: "plus.circle")
                    .padding(.vertical, 8)
            }
        }

        private var tvOSAboutSection: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
            }
        }
    #endif

    // MARK: - Shared

    private var removeDialogBinding: Binding<Bool> {
        Binding(
            get: { accountToRemove != nil },
            set: { if !$0 { accountToRemove = nil } }
        )
    }

    @ViewBuilder
    private var removeDialogActions: some View {
        Button("Remove", role: .destructive) {
            if let account = accountToRemove {
                Task {
                    await accountStore.removeAccount(account, apiService: apiService)
                }
            }
        }
    }

    @ViewBuilder
    private var removeDialogMessage: some View {
        if let account = accountToRemove {
            Text("Remove \(account.email) on \(account.displayServerUrl)?")
        }
    }

    private var appVersion: String {
        let version =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
