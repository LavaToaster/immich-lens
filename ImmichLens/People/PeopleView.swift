import Nuke
import NukeUI
import SwiftUI

struct PeopleView: View {
    @EnvironmentObject var apiService: APIService
    @State private var people: [Person] = []
    @State private var isLoading = true

    #if os(tvOS)
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 40), count: 5)
    private let spacing: CGFloat = 40
    #else
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 24), count: 6)
    private let spacing: CGFloat = 24
    #endif

    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            gridContent
                .navigationDestination(for: Person.self) { person in
                    PersonAssetsView(person: person)
                        .environmentObject(apiService)
                }
        }
        .task {
            await loadPeople()
        }
    }

    private var gridContent: some View {
        Group {
            if isLoading && people.isEmpty {
                ProgressView("Loading people...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .focusable()
            } else if !isLoading && people.isEmpty {
                ContentUnavailableView(
                    "No People",
                    systemImage: "person.2",
                    description: Text("Recognized people will appear here")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: spacing) {
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
                    .padding()
                }
            }
        }
    }

    private func loadPeople() async {
        guard let client = apiService.client, let serverUrl = apiService.serverUrl else {
            logger.error("API client or server URL not available")
            isLoading = false
            return
        }

        defer { isLoading = false }

        do {
            let response = try await client.getAllPeople(query: .init(withHidden: false))
            let dto = try response.ok.body.json

            self.people = dto.people
                .map { Person(from: $0, serverUrl: serverUrl) }
                .filter { !$0.name.isEmpty }
        } catch {
            logger.error("Failed to fetch people: \(error.localizedDescription)")
        }
    }
}

struct PersonCell: View {
    let person: Person

    #if os(tvOS)
    private static let size: CGFloat = 200
    #else
    private static let size: CGFloat = 120
    #endif

    private static let thumbnailSize = CGSize(width: 200, height: 200)
    private static let thumbnailProcessors: [ImageProcessing] = [
        .resize(size: thumbnailSize, crop: true),
    ]

    private var thumbnailRequest: ImageRequest? {
        guard let url = person.thumbnailUrl else { return nil }
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
                .frame(width: Self.size, height: Self.size)
            } else {
                placeholderView
                    .frame(width: Self.size, height: Self.size)
            }

            Text(person.name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var placeholderView: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .padding(30)
                .foregroundColor(.gray)
        }
    }
}
