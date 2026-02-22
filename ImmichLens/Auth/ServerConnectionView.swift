//
//  ServerConnectionView.swift
//  ImmichLens
//
//  Created by Adam Lavin on 04/05/2025.
//

import OpenAPIRuntime
import OpenAPIURLSession
import SwiftUI

struct ServerConnectionView: View {
  @Environment(APIService.self) private var apiService
  @State private var isLoading: Bool = false
  @State private var serverUrl: String = ""
  @State private var errorMessage: String? = nil
  @State private var shouldNavigateToLogin: Bool = false

  enum FocusField {
    case serverUrl
    case connectButton
  }
  @FocusState private var focusedField: FocusField?

  #if os(tvOS)
  private let logoSize: CGFloat = 140
  #else
  private let logoSize: CGFloat = 100
  #endif

  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        Spacer()

        Image("Logo")
          .resizable()
          .scaledToFit()
          .frame(width: logoSize, height: logoSize)
          .clipShape(.rect(cornerRadius: logoSize * 0.2))

        VStack(spacing: 8) {
          Text("Immich Lens")
            .font(.largeTitle.bold())

          Text("Enter the URL of your Immich server to get started.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }

        VStack(spacing: 16) {
          TextField("Server URL", text: $serverUrl)
            .textFieldStyle(.automatic)
            .focused($focusedField, equals: .serverUrl)
            .submitLabel(.continue)
            .onSubmit {
              if !serverUrl.isEmpty {
                focusedField = .connectButton
              }
            }
            .onAppear {
              focusedField = .serverUrl
              if let testUrl = ProcessInfo.processInfo.environment["IMMICH_TEST_SERVER_URL"] {
                // Strip /api suffix since connectToServer() adds it back
                serverUrl = testUrl.hasSuffix("/api") ? String(testUrl.dropLast(4)) : testUrl
                Task { await connectToServer() }
              }
            }
            .disabled(isLoading)

          Button(action: {
            errorMessage = nil
            Task {
              await connectToServer()
            }
          }) {
            if isLoading {
              ProgressView()
                .progressViewStyle(.circular)
                .padding()
            } else {
              Text("Connect")
                .frame(width: 200)
            }
          }
          .buttonStyle(.borderedProminent)
          .focused($focusedField, equals: .connectButton)
          .disabled(serverUrl.isEmpty || isLoading)
        }
        #if os(macOS)
        .frame(maxWidth: 400)
        #endif

        if let errorMessage = errorMessage {
          Text(errorMessage)
            .foregroundStyle(.red)
            .font(.callout)
        }

        Spacer()
      }
      .padding()
      .navigationDestination(isPresented: $shouldNavigateToLogin) {
        AccountLoginView(serverUrl: serverUrl + "/api")
      }
    }
  }

  private func connectToServer() async {
    logger.info("Connecting to server...")

    isLoading = true
    defer { isLoading = false }
    let serverUrl = self.serverUrl + "/api"

    guard let url = URL(string: serverUrl) else {
      errorMessage = "Invalid server URL"
      return
    }

    let client = Client(
      serverURL: url,
      transport: URLSessionTransport(),
    )

    do {
      _ = try await client.pingServer()
      logger.info("Successfully connected to server")
      shouldNavigateToLogin = true
    } catch {
      logger.error("Error connecting to server: \(error.localizedDescription)")
      errorMessage = "Error connecting to server: \(error.localizedDescription)"
    }
  }
}

#Preview {
  ServerConnectionView()
    .environment(APIService())
}
