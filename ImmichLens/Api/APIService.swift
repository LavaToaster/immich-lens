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

  /// Test-mode initialisation only (env var bypass)
  public func initialise() async {
    defer { self.isReady = true }

    // API key bypass for tests that don't need the login flow
    if let testServerUrl = ProcessInfo.processInfo.environment["IMMICH_TEST_SERVER_URL"],
      let testApiKey = ProcessInfo.processInfo.environment["IMMICH_TEST_API_KEY"],
      let url = URL(string: testServerUrl)
    {
      self.serverUrl = testServerUrl
      self.client = createClient(url: url, token: testApiKey)
      self.token = testApiKey
      self.isAuthenticated = true
      return
    }
  }

  /// Activate a connection with the given credentials. Returns true if the token is valid.
  func activate(serverUrl: String, token: String) async -> Bool {
    guard let url = URL(string: serverUrl) else { return false }

    let tokenPrefix = String(token.prefix(8))
    logger.info("APIService.activate: serverUrl=\(serverUrl) token=\(tokenPrefix)...")

    self.serverUrl = serverUrl
    self.client = createClient(url: url, token: token)
    self.token = token

    do {
      guard let client = self.client else {
        throw ApiError.notAuthenticated
      }
      let response = try await client.validateAccessToken()
      let authStatus = try response.ok.body.json.authStatus
      if !authStatus {
        throw ApiError.notAuthenticated
      }
      self.isAuthenticated = true
      return true
    } catch {
      logger.error("Token validation failed: \(error.localizedDescription)")
      self.deactivate()
      return false
    }
  }

  func createClient(url: URL, token: String) -> Client {
    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
    sessionConfig.urlCache = nil
    // Disable cookies so a stale session cookie from another account
    // cannot override the Authorization header identity.
    sessionConfig.httpCookieStorage = nil
    return Client(
      serverURL: url,
      configuration: .init(
        dateTranscoder: ComplainLessTranscoder(),
      ),
      transport: URLSessionTransport(configuration: .init(session: URLSession(configuration: sessionConfig))),
      middlewares: [APIKeyMiddleware(apiKey: token)],
    )
  }

  /// Authenticate with email/password. Returns the access token. Does NOT persist credentials.
  func login(serverUrl: String, email: String, password: String) async throws -> String {
    self.isLoading = true
    defer {
      self.isLoading = false
    }

    guard let url = URL(string: serverUrl) else {
      throw URLError(.badURL)
    }

    // Create a temporary client for login without auth middleware.
    // Cookies are disabled — the access token in the response body is all we need.
    let loginConfig = URLSessionConfiguration.default
    loginConfig.httpCookieStorage = nil
    let tempClient = Client(
      serverURL: url,
      transport: URLSessionTransport(configuration: .init(session: URLSession(configuration: loginConfig)))
    )

    let response = try await tempClient.login(
      .init(body: .json(.init(email: email, password: password))))
    let body = try response.created.body.json
    let token = body.accessToken

    // Set up the authenticated client
    self.serverUrl = serverUrl
    self.client = createClient(url: url, token: token)
    self.isAuthenticated = true
    self.token = token

    return token
  }

  /// Clear all active connection state. Does NOT touch Keychain.
  func deactivate() {
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
