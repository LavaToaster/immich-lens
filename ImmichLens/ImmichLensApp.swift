//
//  ImmichLensApp.swift
//  ImmichLens
//
//  Created by Adam Lavin on 04/05/2025.
//

import Nuke
import OpenAPIRuntime
import OpenAPIURLSession
import SwiftUI
import os

@main
struct ImmichLensApp: App {
    @State var selection: RootTabs = .photos
    @State private var apiService = APIService()
    @State private var prefetchService: ThumbnailPrefetchService?

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
            .onChange(of: apiService.token) { _, token in
                if let token {
                    let config = URLSessionConfiguration.default
                    config.httpAdditionalHeaders = ["x-api-key": token]
                    let dataCache = Self.createDataCache()
                    ImagePipeline.shared = ImagePipeline {
                        $0.dataLoader = DataLoader(configuration: config)
                        $0.dataCache = dataCache
                    }
                } else {
                    (ImagePipeline.shared.configuration.dataCache as? DataCache)?.removeAll()
                    ImagePipeline.shared = ImagePipeline()
                }
            }
            .onChange(of: apiService.isAuthenticated) { _, authenticated in
                if authenticated {
                    let service = ThumbnailPrefetchService(apiService: apiService)
                    prefetchService = service
                    service.startPrefetching()
                } else {
                    prefetchService?.stopPrefetching()
                    prefetchService = nil
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
        .environment(\.activeTab, selection)
        #endif
    }
}

extension ImmichLensApp {
    static func createDataCache() -> DataCache? {
        let candidates: [URL] = [
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
            FileManager.default.temporaryDirectory,
        ].compactMap { $0 }

        for base in candidates {
            let path = base.appendingPathComponent("dev.lav.immichlens", isDirectory: true)
            do {
                let cache = try DataCache(path: path)
                logger.info("DataCache created at \(path.path)")
                return cache
            } catch {
                logger.warning("DataCache failed at \(path.path): \(error.localizedDescription)")
            }
        }
        logger.error("DataCache: all locations failed")
        return nil
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

// MARK: - Active Tab Navigation Fix

private struct ActiveTabKey: EnvironmentKey {
    static let defaultValue: RootTabs = .photos
}

extension EnvironmentValues {
    var activeTab: RootTabs {
        get { self[ActiveTabKey.self] }
        set { self[ActiveTabKey.self] = newValue }
    }
}

#if os(macOS)
/// Forces NavigationStack recreation when returning to a tab, working around
/// a SwiftUI bug where navigation destinations stop responding after switching
/// tabs with .sidebarAdaptable.
private struct RefreshNavigationOnTabSwitch: ViewModifier {
    let tab: RootTabs
    let onRefresh: (() -> Void)?
    @Environment(\.activeTab) private var activeTab
    @State private var stackID = UUID()

    func body(content: Content) -> some View {
        content
            .id(stackID)
            .onChange(of: activeTab) { old, new in
                if old != tab && new == tab {
                    onRefresh?()
                    stackID = UUID()
                }
            }
    }
}
#endif

extension View {
    func refreshNavigationOnTabSwitch(tab: RootTabs, onRefresh: (() -> Void)? = nil) -> some View {
        #if os(macOS)
        modifier(RefreshNavigationOnTabSwitch(tab: tab, onRefresh: onRefresh))
        #else
        self
        #endif
    }
}
