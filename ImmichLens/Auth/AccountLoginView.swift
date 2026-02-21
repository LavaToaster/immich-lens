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
    case loginButton
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

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      Image("AppLogo")
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
          .focused($focusedField, equals: .email)
          .submitLabel(.next)
          .onSubmit {
            focusedField = .password
          }
          .onAppear {
            focusedField = .email
          }
          .textContentType(.emailAddress)
          .disabled(apiService.isLoading)

        SecureField("Password", text: $password)
          .focused($focusedField, equals: .password)
          .submitLabel(.go)
          .onSubmit {
            focusedField = .loginButton
          }
          .disabled(apiService.isLoading)

        Button(action: {
          Task {
            await handleLogin()
          }
        }) {
          if apiService.isLoading {
            ProgressView()
              .progressViewStyle(.circular)
              .frame(width: 200)
          } else {
            Text("Log In")
              .fontWeight(.semibold)
              .frame(width: 200)
          }
        }
        .buttonStyle(.borderedProminent)
        .focused($focusedField, equals: .loginButton)
        .disabled(email.isEmpty || password.isEmpty || apiService.isLoading)
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
  }

  private func handleLogin() async {
    errorMessage = nil

    do {
      _ = try await apiService.login(serverUrl: serverUrl, email: email, password: password)
    } catch {
      logger.error("Login failed: \(error.localizedDescription)")
      errorMessage = "Login failed: \(error.localizedDescription)"
    }
  }
}

#Preview {
  AccountLoginView(
    serverUrl: "https://photos.example.com"
  )
  .environment(APIService())
}
