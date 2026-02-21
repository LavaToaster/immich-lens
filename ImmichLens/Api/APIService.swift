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
@Observable
class APIService {
  var isAuthenticated = false
  var isLoading = false
  var isReady = false

  private(set) var client: Client?
  private(set) var serverUrl: String?
  private(set) var token: String?

  public func initialise() async {
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
        logger.error("Token validation failed: \(error.localizedDescription)")
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
  private static let encoder = ISO8601DateFormatter()
  private static let decoder: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withFractionalSeconds]
    return f
  }()

  public func encode(_ date: Date) throws -> String { Self.encoder.string(from: date) }

  public func decode(_ dateString: String) throws -> Date {
    guard let date = Self.decoder.date(from: dateString) else {
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
