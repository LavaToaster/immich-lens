//
//  AuthMiddleware.swift
//  ImmichLens
//
//  Created for ImmichLens
//

import Foundation
import HTTPTypes
import OpenAPIRuntime

/// A client middleware that injects an API key into the request headers.
struct APIKeyMiddleware {
  /// The API key value.
  private let apiKey: String

  /// Creates a new middleware.
  /// - Parameter apiKey: The API key to include in requests.
  init(apiKey: String) {
    self.apiKey = apiKey
  }
}

extension APIKeyMiddleware: ClientMiddleware {
  func intercept(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
  ) async throws -> (HTTPResponse, HTTPBody?) {
    var request = request
    // Add the x-api-key header field with the provided key
    request.headerFields[.init("x-api-key")!] = apiKey
    return try await next(request, body, baseURL)
  }
}
