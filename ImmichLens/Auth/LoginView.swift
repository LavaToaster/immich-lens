//
//  LoginView.swift
//  ImmichLens
//
//  Created by Adam Lavin on 04/05/2025.
//

import OpenAPIRuntime
import OpenAPIURLSession
import SwiftUI

struct LoginView: View {
  @EnvironmentObject var apiService: APIService
  @State var email: String = ""
  @State var password: String = ""
  @State var errorMessage: String? = nil

  var serverUrl: String

  var onBack: () -> Void

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

      HStack(spacing: 20) {
        Button(action: onBack) {
          Text("Back")
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .cornerRadius(8)
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
              .frame(maxWidth: .infinity)
              .cornerRadius(8)
              .padding()
          } else {
            Text("Log In")
              .fontWeight(.semibold)
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .cornerRadius(8)
          }
        }
        .focused($focusedField, equals: .loginButton)
        .disabled(email.isEmpty || password.isEmpty || apiService.isLoading)
      }

      if let errorMessage = errorMessage {
        Text(errorMessage)
          .foregroundColor(.red)
      }

      Spacer()
    }
    .padding()
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
  LoginView(
    serverUrl: "https://photos.example.com",
    onBack: {},
  )
  .environmentObject(APIService())
}
