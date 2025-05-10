//
//  ImmichLensApp.swift
//  ImmichLens
//
//  Created by Adam Lavin on 04/05/2025.
//

import OpenAPIRuntime
import OpenAPIURLSession
import SwiftUI

enum RootTabs: Equatable, Hashable, Identifiable {
  case media
  case explore
  case people
  case library(LibraryTabs)
  case logout

  var id: Self { self }
}

enum LibraryTabs: Equatable, Hashable, Identifiable {
  case albums
  case favorites

  var id: Self { self }
}

@main
struct ImmichLensApp: App {
  @State var selection: RootTabs = .media
  @StateObject private var apiService = APIService()

  var body: some Scene {
    WindowGroup {
      if apiService.isReady {
        if !apiService.isAuthenticated {
          AuthView()
            .environmentObject(apiService)
        } else {
          TabView(selection: $selection) {
            Tab("Media", systemImage: "photo", value: .media) {
              MediaView()
            }

            Tab("Explore", systemImage: "mountain.2.circle", value: .explore) {
              Text("Explore").focusable()
            }

            Tab("People", systemImage: "person.2", value: .people) {
              Text("People").focusable()
            }

            TabSection("Library") {
              Tab("Albums", systemImage: "photo.on.rectangle", value: RootTabs.library(.albums)) {
                Text("Albums").focusable()
              }

              Tab("Favorites", systemImage: "star", value: RootTabs.library(.favorites)) {
                Text("Favorites").focusable()
              }
            }

            Tab("Logout", systemImage: "rectangle.portrait.and.arrow.right", value: .logout) {
              Text("Please wait while we log you out...")
                .onAppear {
                  apiService.logout()
                }
            }
          }
          .tabViewStyle(.sidebarAdaptable)
          .environmentObject(apiService)
        }
      }
    }
  }
}
