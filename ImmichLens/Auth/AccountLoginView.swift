//
//  AccountLoginView.swift
//  ImmichLens
//
//  Created by Adam Lavin on 04/05/2025.
//

import OpenAPIRuntime
import OpenAPIURLSession
import SwiftUI

struct AccountLoginView: View {
  @Environment(APIService.self) private var apiService
  @State private var email: String = ""
  @State private var password: String = ""
  @State private var errorMessage: String? = nil

  var serverUrl: String

  @FocusState private var focusedField: FocusField?

  enum FocusField {
    case email
    case password
  }

  #if os(tvOS)
  private let logoSize: CGFloat = 120
  #else
  private let logoSize: CGFloat = 80
  #endif

  /// Strip the /api suffix for display
  private var displayUrl: String {
    if serverUrl.hasSuffix("/api") {
      return String(serverUrl.dropLast(4))
    }
    return serverUrl
  }

  private var canSubmit: Bool {
    !email.isEmpty && !password.isEmpty && !apiService.isLoading
  }

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      Image("Logo")
        .resizable()
        .scaledToFit()
        .frame(width: logoSize, height: logoSize)
        .clipShape(.rect(cornerRadius: logoSize * 0.2))

      VStack(spacing: 8) {
        Text("Sign In")
          .font(.largeTitle.bold())

        Text(displayUrl)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      VStack(spacing: 16) {
        TextField("Email", text: $email)
          .textContentType(.emailAddress)
          .autocorrectionDisabled()
          #if !os(macOS)
          .textInputAutocapitalization(.never)
          #endif
          .focused($focusedField, equals: .email)
          .submitLabel(.next)
          .onSubmit {
            focusedField = .password
          }

        SecureField("Password", text: $password)
          .textContentType(.password)
          .focused($focusedField, equals: .password)
          .submitLabel(.go)
          .onSubmit {
            if canSubmit {
              Task { await handleLogin() }
            }
          }

        Button(action: {
          Task {
            await handleLogin()
          }
        }) {
          Text("Log In")
            .fontWeight(.semibold)
            .frame(width: 200)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canSubmit)
        #if os(macOS)
        .keyboardShortcut(.defaultAction)
        #endif
      }
      .disabled(apiService.isLoading)
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
    .onAppear {
      focusedField = .email
      if let testEmail = ProcessInfo.processInfo.environment["IMMICH_TEST_EMAIL"],
         let testPassword = ProcessInfo.processInfo.environment["IMMICH_TEST_PASSWORD"]
      {
        email = testEmail
        password = testPassword
        Task { await handleLogin() }
      }
    }
  }

  private func handleLogin() async {
    errorMessage = nil

    do {
      _ = try await apiService.login(serverUrl: serverUrl, email: email, password: password)
    } catch {
      logger.error("Login failed: \(error.localizedDescription)")
      errorMessage = "Login failed: \(error.localizedDescription)"
      focusedField = .email
    }
  }
}

#Preview {
  AccountLoginView(
    serverUrl: "https://photos.example.com"
  )
  .environment(APIService())
}
