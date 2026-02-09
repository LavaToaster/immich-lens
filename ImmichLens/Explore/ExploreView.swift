import Nuke
import NukeUI
import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var apiService: APIService
    @State private var people: [Person] = []
    @State private var places: [Place] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            content
                .navigationDestination(for: Person.self) { person in
                    PersonAssetsView(person: person)
                        .environmentObject(apiService)
                }
                .navigationDestination(for: Place.self) { place in
                    PlaceAssetsView(place: place)
                        .environmentObject(apiService)
                }
                #if os(macOS)
                .navigationTitle("Explore")
                #endif
        }
        .task {
            await loadData()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && people.isEmpty && places.isEmpty {
            ProgressView("Loading...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .focusable()
        } else if !isLoading && people.isEmpty && places.isEmpty {
            ContentUnavailableView(
                "Nothing to Explore",
                systemImage: "magnifyingglass",
                description: Text("People and places will appear here")
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    if !people.isEmpty {
                        peopleSection
                    }
                    if !places.isEmpty {
                        placesSection
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - People

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("People")
                    .font(.title2.bold())
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    ForEach(people) { person in
                        NavigationLink(value: person) {
                            PersonCell(person: person)
                        }
                        .buttonBorderShape(.circle)
                        #if os(tvOS)
                        .buttonStyle(.borderless)
                        #else
                        .buttonStyle(.plain)
                        #endif
                    }
                }
                .padding(20)
            }
        }
    }

    // MARK: - Places

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Places")
                    .font(.title2.bold())
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(places) { place in
                        NavigationLink(value: place) {
                            PlaceCell(place: place)
                        }
                        #if os(tvOS)
                        .buttonStyle(.borderless)
                        #else
                        .buttonStyle(.plain)
                        #endif
                    }
                }
                .padding(20)
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard let client = apiService.client, let serverUrl = apiService.serverUrl else {
            logger.error("API client or server URL not available")
            isLoading = false
            return
        }

        defer { isLoading = false }

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    let response = try await client.getAllPeople(query: .init(withHidden: false))
                    let dto = try response.ok.body.json
                    let loaded = dto.people
                        .map { Person(from: $0, serverUrl: serverUrl) }
                        .filter { !$0.name.isEmpty }
                    await MainActor.run { self.people = loaded }
                } catch {
                    logger.error("Failed to fetch people: \(error.localizedDescription)")
                }
            }

            group.addTask {
                do {
                    let response = try await client.getAssetsByCity()
                    let assets = try response.ok.body.json
                    let loaded = assets
                        .map { Place(from: $0, serverUrl: serverUrl) }
                        .filter { $0.city != "Unknown" }
                    await MainActor.run { self.places = loaded }
                } catch {
                    logger.error("Failed to fetch places: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Place Cell

private struct PlaceCell: View {
    let place: Place

    #if os(tvOS)
    private static let width: CGFloat = 240
    private static let height: CGFloat = 160
    #else
    private static let width: CGFloat = 180
    private static let height: CGFloat = 120
    #endif

    private static let thumbnailSize = CGSize(width: 240, height: 160)
    private static let thumbnailProcessors: [ImageProcessing] = [
        .resize(size: thumbnailSize, crop: true),
    ]

    private var thumbnailRequest: ImageRequest? {
        guard let url = place.thumbnailUrl else { return nil }
        return ImageRequest(url: url, processors: Self.thumbnailProcessors)
    }

    var body: some View {
        VStack(spacing: 8) {
            if let request = thumbnailRequest {
                LazyImage(request: request) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else if state.error != nil {
                        placeholderView
                    } else {
                        placeholderView
                    }
                }
                .frame(width: Self.width, height: Self.height)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                placeholderView
                    .frame(width: Self.width, height: Self.height)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text(place.city)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var placeholderView: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: "mappin.circle.fill")
                .resizable()
                .scaledToFit()
                .padding(30)
                .foregroundColor(.gray)
        }
    }
}
