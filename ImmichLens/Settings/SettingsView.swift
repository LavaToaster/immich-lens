import SwiftUI

struct SettingsView: View {
    @Environment(APIService.self) private var apiService
    @Environment(AccountStore.self) private var accountStore
    @State private var showingAddAccount = false
    @State private var accountToRemove: SavedAccount?
    @State private var activatingAccountId: UUID?

    #if os(tvOS)
    @State private var topShelfEnabled: Bool = TopShelfSettings().isEnabled
    @State private var topShelfSourceMode: TopShelfSettings.SourceMode = TopShelfSettings().sourceMode
    @State private var topShelfAlbumId: String? = TopShelfSettings().selectedAlbumId
    @State private var topShelfAlbums: [Album] = []
    @State private var isLoadingAlbums = false
    @FocusState private var focusedSection: SettingsSection?
    #endif

    private var isActivating: Bool { activatingAccountId != nil }

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
                .disabled(isActivating)
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
                } else if activatingAccountId == account.id {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Switch") {
                        activatingAccountId = account.id
                        Task {
                            await accountStore.activate(
                                account: account, apiService: apiService)
                            activatingAccountId = nil
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(isActivating)
                }

                Button(role: .destructive) {
                    accountToRemove = account
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(isActivating)
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
        private enum SettingsSection: Hashable {
            case accounts
            case topShelf
        }

        @State private var settingsDescription = ""
        @State private var topShelfDescription = "Choose which photos appear on the Apple TV Home Screen when ImmichLens is in focus."
        @FocusState private var focusedTopShelfItem: TopShelfSourceSelection?

        private var tvOSSettings: some View {
            NavigationStack {
                tvOSSettingsLayout(description: settingsDescription) {
                    List {
                        NavigationLink("Accounts", value: SettingsSection.accounts)
                            .focused($focusedSection, equals: .accounts)
                        NavigationLink("Top Shelf", value: SettingsSection.topShelf)
                            .focused($focusedSection, equals: .topShelf)
                    }
                    .listStyle(.grouped)
                }
                .onChange(of: focusedSection) { _, section in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        switch section {
                        case .accounts:
                            settingsDescription = "Switch between accounts or add a new Immich server connection."
                        case .topShelf:
                            settingsDescription = "Choose which photos appear on the Apple TV Home Screen when ImmichLens is in focus."
                        case nil:
                            settingsDescription = ""
                        }
                    }
                }
                .navigationDestination(for: SettingsSection.self) { section in
                    switch section {
                    case .accounts:
                        tvOSSettingsLayout(description: "Switch between accounts or add a new Immich server connection.") { tvOSAccountsDetail }
                    case .topShelf:
                        tvOSSettingsLayout(description: topShelfDescription) { tvOSTopShelfDetail }
                    }
                }
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

        private func tvOSSettingsLayout<Content: View>(description: String, @ViewBuilder content: () -> Content) -> some View {
            HStack(spacing: 0) {
                ZStack {
                    // Logo + name pinned to center, ignoring description height
                    VStack(spacing: 0) {
                        Image("Logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 300, height: 300)
                        Text("ImmichLens")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 16)
                        Text(appVersion)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .offset(y: -40)

                    // Description pinned below center
                    VStack {
                        Spacer()
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 400)
                            .padding(.bottom, 80)
                    }
                }
                .frame(maxWidth: .infinity)

                content()
                    .scrollClipDisabled()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }

        private var tvOSAccountsDetail: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(accountStore.accounts) { account in
                        let isActive = account.id == accountStore.activeAccountId
                        let isActivating = activatingAccountId == account.id
                        HStack(spacing: 24) {
                            Button {
                                guard !isActive && !isActivating else { return }
                                activatingAccountId = account.id
                                Task {
                                    await accountStore.activate(
                                        account: account, apiService: apiService)
                                    activatingAccountId = nil
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
                                    if isActivating {
                                        ProgressView()
                                    } else if isActive {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .disabled(isActivating)
                            .frame(maxWidth: .infinity)

                            Button {
                                accountToRemove = account
                            } label: {
                                Image(systemName: "trash")
                                    .frame(maxHeight: .infinity)
                            }
                            .disabled(isActivating)
                            .frame(width: 80)
                        }
                    }

                    Button {
                        showingAddAccount = true
                    } label: {
                        Label("Add Account", systemImage: "plus.circle")
                            .padding(.vertical, 8)
                    }
                    .disabled(isActivating)
                }
            }
        }

        private var tvOSTopShelfDetail: some View {
            List {
                Section {
                    Button {
                        selectSource(.disabled)
                    } label: {
                        HStack {
                            Text("Disabled")
                            Spacer()
                            if !topShelfEnabled {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .focused($focusedTopShelfItem, equals: .disabled)

                    Button {
                        selectSource(.everything)
                    } label: {
                        HStack {
                            Text("Show Everything")
                            Spacer()
                            if topShelfEnabled && topShelfSourceMode == .everything {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .focused($focusedTopShelfItem, equals: .everything)
                }

                Section("Albums") {
                    if isLoadingAlbums {
                        ProgressView()
                    } else {
                        ForEach(topShelfAlbums) { album in
                            Button {
                                selectSource(.album(album.id))
                            } label: {
                                HStack {
                                    Text(album.name)
                                    Spacer()
                                    if topShelfEnabled && topShelfSourceMode == .album && topShelfAlbumId == album.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .focused($focusedTopShelfItem, equals: .album(album.id))
                        }
                    }
                }
            }
            .listStyle(.grouped)
            .onChange(of: focusedTopShelfItem) { _, item in
                withAnimation(.easeInOut(duration: 0.2)) {
                    switch item {
                    case .disabled:
                        topShelfDescription = "Photos will not appear on the Home Screen."
                    case .everything:
                        topShelfDescription = "Show random photos from your entire library on the Home Screen."
                    case .album(let id):
                        let name = topShelfAlbums.first { $0.id == id }?.name ?? "this album"
                        topShelfDescription = "Show random photos from \(name) on the Home Screen."
                    case nil:
                        topShelfDescription = "Choose which photos appear on the Apple TV Home Screen when ImmichLens is in focus."
                    }
                }
            }
            .task {
                await loadAlbumsForTopShelf()
            }
        }

        private func selectSource(_ selection: TopShelfSourceSelection) {
            let settings = TopShelfSettings()
            switch selection {
            case .disabled:
                topShelfEnabled = false
                settings.isEnabled = false
            case .everything:
                topShelfEnabled = true
                topShelfSourceMode = .everything
                topShelfAlbumId = nil
                settings.isEnabled = true
                settings.sourceMode = .everything
                settings.selectedAlbumId = nil
                settings.selectedAlbumName = nil
            case .album(let id):
                topShelfEnabled = true
                topShelfSourceMode = .album
                topShelfAlbumId = id
                settings.isEnabled = true
                settings.sourceMode = .album
                settings.selectedAlbumId = id
                settings.selectedAlbumName = topShelfAlbums.first { $0.id == id }?.name
            }
            NotificationCenter.default.post(name: .topShelfSettingsChanged, object: nil)
        }

        private var currentTopShelfSelection: TopShelfSourceSelection {
            if !topShelfEnabled { return .disabled }
            if topShelfSourceMode == .album, let id = topShelfAlbumId { return .album(id) }
            return .everything
        }

        private func loadAlbumsForTopShelf() async {
            guard let client = apiService.client, let serverUrl = apiService.serverUrl else { return }
            isLoadingAlbums = true
            defer { isLoadingAlbums = false }

            do {
                let response = try await client.getAllAlbums()
                let dtos = try response.ok.body.json
                topShelfAlbums = dtos
                    .map { Album(from: $0, serverUrl: serverUrl) }
                    .filter { $0.assetCount > 0 }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            } catch {
                guard !Task.isCancelled else { return }
                logger.error("Failed to fetch albums for TopShelf settings: \(error.localizedDescription)")
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

#if os(tvOS)
enum TopShelfSourceSelection: Hashable {
    case disabled
    case everything
    case album(String)
}

extension Notification.Name {
    static let topShelfSettingsChanged = Notification.Name("topShelfSettingsChanged")
}
#endif
