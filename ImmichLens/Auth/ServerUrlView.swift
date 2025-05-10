//
//  ServerUrlView.swift
//  ImmichLens
//
//  Created by Adam Lavin on 04/05/2025.
//

import OpenAPIRuntime
import OpenAPIURLSession
import SwiftUI

struct ServerUrlView: View {
  @State var isLoading: Bool = false
  @State var serverUrl: String = ""
  @State var errorMessage: String? = nil

  var onNext: ((String) -> Void)? = nil

  var body: some View {
    VStack(spacing: 30) {
      Text("Welcome to Immich Lens")
        .font(.largeTitle)
        .fontWeight(.bold)

      Text("Please enter the URL of your Immich server.")
        .font(.headline)

      TextField("Server URL", text: $serverUrl)
        .textFieldStyle(.automatic)
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
        }
      }
      .buttonStyle(.borderedProminent)
      .disabled(serverUrl.isEmpty || isLoading)

      if let errorMessage = errorMessage {
        Text(errorMessage)
          .foregroundColor(.red)
          .padding()
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

      onNext?(serverUrl)
    } catch {
      print("Error connecting to server: \(error)")
      errorMessage = "Error connecting to server: \(error.localizedDescription)"
    }
  }
}

#Preview {
  ServerUrlView()
}
