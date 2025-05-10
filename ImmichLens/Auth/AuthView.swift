//
//  SwiftUIView.swift
//  ImmichLens
//
//  Created by Adam Lavin on 04/05/2025.
//

import SwiftUI

struct AuthView: View {
  @EnvironmentObject var apiService: APIService
  @State var screen: AuthScreen = .serverUrl

  enum AuthScreen {
    case serverUrl
    case login(serverUrl: String)
  }

  var body: some View {
    switch screen {
    case .serverUrl:
      ServerUrlView(onNext: { serverUrl in
        self.screen = .login(serverUrl: serverUrl)
      })
    case .login(let serverUrl):
      LoginView(
        serverUrl: serverUrl,
        onBack: {
          self.screen = .serverUrl
        }
      )
      .environmentObject(apiService)
    }
  }
}

#Preview {
  AuthView()
    .environmentObject(APIService())
}
