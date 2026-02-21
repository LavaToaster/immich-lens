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
    @State var selection: RootTabs = .photos
    @State private var apiService = APIService()

    var body: some Scene {
        WindowGroup {
            Group {
                if apiService.isReady {
                    if !apiService.isAuthenticated {
                        ServerConnectionView()
                    } else {
                        mainTabView
                    }
                }
            }
            .environment(apiService)
            .task {
                await apiService.initialise()
            }
            .onChange(of: apiService.isAuthenticated) { _, authenticated in
                if !authenticated {
                    selection = .photos
                }
            }
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selection) {
            Tab(value: .photos) {
                PhotosView()
            } label: {
                Text("Photos")
            }

            Tab(value: .explore) {
                ExploreView()
            } label: {
                Text("Explore")
            }

            Tab(value: .people) {
                PeopleView()
            } label: {
                Text("People")
            }

            TabSection("Library") {
                Tab(value: RootTabs.library(.albums)) {
                    AlbumsView()
                } label: {
                    Text("Albums")
                }

                Tab(value: RootTabs.library(.favourites)) {
                    FavouritesView()
                } label: {
                    Text("Favourites")
                }
            }

            Tab(value: .settings) {
                SettingsView()
            } label: {
                Text("Settings")
            }
        }
        #if os(tvOS)
        .tabViewStyle(.tabBarOnly)
        #else
        .tabViewStyle(.sidebarAdaptable)
        #endif
    }
}

let logger = Logger(subsystem: "dev.lav.immichlens", category: "general")

enum RootTabs: Equatable, Hashable, Identifiable {
    case photos
    case explore
    case people
    case library(LibraryTabs)
    case settings

    var id: Self { self }
}

enum LibraryTabs: Equatable, Hashable, Identifiable {
    case albums
    case favourites

    var id: Self { self }
}
