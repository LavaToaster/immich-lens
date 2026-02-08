//
//  ImmichLensApp.swift
//  ImmichLens
//
//  Created by Adam Lavin on 04/05/2025.
//

import OpenAPIRuntime
import OpenAPIURLSession
import SwiftUI
import os

@main
struct ImmichLensApp: App {
    @State var selection: RootTabs = .media
    @StateObject private var apiService = APIService()

    var body: some Scene {
        WindowGroup {
            Group {
                if apiService.isReady {
                    if !apiService.isAuthenticated {
                        ServerConnectionView()
                            .environmentObject(apiService)
                    } else {
                        mainTabView
                    }
                }
            }
            .environmentObject(apiService)
            .task {
                await apiService.initialise()
            }
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selection) {
            Tab("Media", systemImage: "photo", value: .media) {
                ImmichTimelineView()
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

                Tab("Favourites", systemImage: "star", value: RootTabs.library(.favourites)) {
                    Text("Favourites").focusable()
                }
            }

            Tab("Logout", systemImage: "rectangle.portrait.and.arrow.right", value: .logout) {
                Text("Please wait while we log you out...")
                    .onAppear {
                        self.apiService.logout()
                        // Reset the selection to the media tab after logging out
                        self.selection = .media
                    }
            }
        }
        #if os(tvOS)
        .tabViewStyle(.tabBarOnly)
        #else
        .tabViewStyle(.sidebarAdaptable)
        #endif
    }
}

let logger = Logger()

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
    case favourites

    var id: Self { self }
}
