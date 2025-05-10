//
//  APIService.swift
//  ImmichLens
//
//  Created by Adam Lavin on 04/05/2025.
//

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession
import SwiftUI

@MainActor
class APIService: ObservableObject, @unchecked Sendable {
  @Published var isAuthenticated = false
  @Published var isLoading = false
  @Published var isReady = false

  private(set) var client: Client?
  private(set) var serverUrl: String?
  private(set) var token: String?

  init() {
    Task {
      await setupFromKeychain()
    }
  }

  private func setupFromKeychain() async {
    defer { self.isReady = true }

    if let token = KeychainManager.shared.get(forKey: "immich_token"),
      let serverUrl = KeychainManager.shared.get(forKey: "immich_server_url"),
      let url = URL(string: serverUrl)
    {
      self.serverUrl = serverUrl
      self.client = createClient(url: url, token: token)
      self.token = token
      do {
        let response = try await self.client?.validateAccessToken()
        let authStatus = try response?.ok.body.json.authStatus ?? false
        if !authStatus {
          throw ApiError.notAuthenticated
        }
      } catch {
        // Handle token validation error
        print("Token validation failed: \(error)")
        self.logout()
        return
      }
      self.isAuthenticated = true
    }
  }

  func createClient(url: URL, token: String) -> Client {
    return Client(
      serverURL: url,
      configuration: .init(
        dateTranscoder: ComplainLessTranscoder(),
        //                dateTranscoder: .iso8601WithFractionalSeconds,
      ),

      transport: URLSessionTransport(),
      middlewares: [APIKeyMiddleware(apiKey: token)],
    )
  }

  func login(serverUrl: String, email: String, password: String) async throws -> String {
    self.isLoading = true
    defer {
      self.isLoading = false
    }

    guard let url = URL(string: serverUrl) else {
      throw URLError(.badURL)
    }

    // Create a temporary client for login without auth middleware
    let tempClient = Client(
      serverURL: url,
      transport: URLSessionTransport()
    )

    let response = try await tempClient.login(
      .init(body: .json(.init(email: email, password: password))))
    let body = try response.created.body.json
    let token = body.accessToken

    // Store credentials in keychain
    try KeychainManager.shared.save(token, forKey: "immich_token")
    try KeychainManager.shared.save(serverUrl, forKey: "immich_server_url")

    // Update client with authentication
    self.serverUrl = serverUrl
    self.client = createClient(url: url, token: token)
    self.isAuthenticated = true
    self.token = token

    return token
  }

  func logout() {
    // Clear keychain data
    KeychainManager.shared.delete(forKey: "immich_token")
    KeychainManager.shared.delete(forKey: "immich_server_url")

    // Reset state
    self.client = nil
    self.serverUrl = nil
    self.isAuthenticated = false
    self.token = nil
  }
}

/// @see: https://developer.apple.com/forums/thread/744220
struct ComplainLessTranscoder: DateTranscoder {
  /// Creates and returns an ISO 8601 formatted string representation of the specified date.
  public func encode(_ date: Date) throws -> String { ISO8601DateFormatter().string(from: date) }

  /// Creates and returns a date object from the specified ISO 8601 formatted string representation.
  public func decode(_ dateString: String) throws -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFractionalSeconds]
    guard let date = formatter.date(from: dateString) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: [], debugDescription: "Expected date string to be ISO8601-formatted.")
      )
    }
    return date
  }
}

enum ApiError: Error {
  case notAuthenticated
}
