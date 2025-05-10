//
//  ServerConnectionView.swift
//  ImmichLens
//
//  Created by Adam Lavin on 04/05/2025.
//

import OpenAPIRuntime
import OpenAPIURLSession
import SwiftUI

// TODO: Do people care about multiple server connections?
struct ServerConnectionView: View {
  @EnvironmentObject var apiService: APIService
  @State var isLoading: Bool = false
  @State var serverUrl: String = ""
  @State var errorMessage: String? = nil
  @State private var shouldNavigateToLogin: Bool = false
  
  // Add FocusState property and enum
  enum FocusField {
    case serverUrl
    case connectButton
  }
  @FocusState private var focusedField: FocusField?

  var body: some View {
    NavigationStack {
      VStack(spacing: 30) {
        Text("Welcome to Immich Lens")
          .font(.largeTitle)
          .fontWeight(.bold)

        Text("Please enter the URL of your Immich server.")
          .font(.headline)

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

        if let errorMessage = errorMessage {
          Text(errorMessage)
            .foregroundColor(.red)
            .padding()
        }
      }
      .navigationDestination(isPresented: $shouldNavigateToLogin) {
        AccountLoginView(serverUrl: serverUrl + "/api")
      }
    }
  }

  func connectToServer() async {
    // Implement the connection logic here
    // Log to console
    print("Connecting to server...")

    isLoading = true
    defer { isLoading = false }
    let serverUrl = self.serverUrl + "/api"

    let client = Client(
      serverURL: URL(string: serverUrl)!,
      transport: URLSessionTransport(),
    )

    do {
      _ = try await client.pingServer()

      print("Successfully connected to server")
      
      // Trigger navigation to login view
      shouldNavigateToLogin = true
      
    } catch {
      print("Error connecting to server: \(error)")
      errorMessage = "Error connecting to server: \(error.localizedDescription)"
    }
  }
}

#Preview {
  ServerConnectionView()
}