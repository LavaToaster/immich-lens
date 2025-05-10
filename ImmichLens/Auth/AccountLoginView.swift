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
  @EnvironmentObject var apiService: APIService
  @State var email: String = ""
  @State var password: String = ""
  @State var errorMessage: String? = nil

  var serverUrl: String

  @FocusState private var focusedField: FocusField?

  enum FocusField {
    case email
    case password
    case loginButton
  }

  var body: some View {
    VStack(spacing: 30) {
      Text("Sign in to your server")
        .font(.largeTitle)
        .fontWeight(.bold)

      Text(serverUrl)
        .font(.subheadline)
        .foregroundColor(.secondary)

      Spacer()

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

      if let errorMessage = errorMessage {
        Text(errorMessage)
          .foregroundColor(.red)
      }

      Spacer()
    }
    .padding()
    .navigationBarBackButtonHidden(false)
  }

  private func handleLogin() async {
    errorMessage = nil

    do {
      // Use the APIService for login instead of creating a client directly
      _ = try await apiService.login(serverUrl: serverUrl, email: email, password: password)
    } catch {
      print("Login failed: \(error)")
      errorMessage = "Login failed: \(error.localizedDescription)"
    }
  }
}

#Preview {
  AccountLoginView(
    serverUrl: "https://photos.example.com"
  )
  .environmentObject(APIService())
}
