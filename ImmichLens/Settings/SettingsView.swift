import SwiftUI

struct SettingsView: View {
    @Environment(APIService.self) private var apiService

    var body: some View {
        #if os(macOS)
            macOSSettings
        #else
            tvOSSettings
        #endif
    }

    // MARK: - macOS

    #if os(macOS)
        @State private var showingLogoutConfirmation = false

        private var macOSSettings: some View {
            Form {
                Section("Server") {
                    LabeledContent("URL") {
                        Text(displayServerUrl)
                            .textSelection(.enabled)
                    }
                }

                Section {
                    Button("Log Out", role: .destructive) {
                        showingLogoutConfirmation = true
                    }
                }

                Section {
                    LabeledContent("Version") {
                        Text(appVersion)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .confirmationDialog("Log out?", isPresented: $showingLogoutConfirmation) {
                Button("Log Out", role: .destructive) {
                    apiService.logout()
                }
            } message: {
                Text("You will need to sign in again to access your photos.")
            }
        }
    #endif

    // MARK: - tvOS

    #if os(tvOS)
        private var tvOSSettings: some View {
            VStack(spacing: 40) {
                Spacer()

                Text("Settings")
                    .font(.title)
                    .bold()

                VStack(spacing: 12) {
                    Text("Connected to")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(displayServerUrl)
                        .font(.body)
                }

                Button("Log Out") {
                    apiService.logout()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Text("Version \(appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
    #endif

    // MARK: - Helpers

    private var displayServerUrl: String {
        guard let url = apiService.serverUrl else { return "Not connected" }
        // Strip the /api suffix for display
        if url.hasSuffix("/api") {
            return String(url.dropLast(4))
        }
        return url
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
