import Nuke
import NukeUI
import SwiftUI

struct PeopleView: View {
    @Environment(APIService.self) private var apiService
    @State private var people: [Person] = []
    @State private var isLoading = true

    #if os(tvOS)
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 40), count: 5)
    private let spacing: CGFloat = 40
    #else
    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12)]
    private let spacing: CGFloat = 12
    #endif

    @State private var navigationPath = NavigationPath()
    @FocusState private var focusedPerson: String?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            gridContent
                .navigationDestination(for: Person.self) { person in
                    PersonAssetsView(person: person)
                        .environment(apiService)
                }
                #if os(macOS)
                .navigationTitle("People")
                #endif
        }
        .refreshNavigationOnTabSwitch(tab: .people) {
            navigationPath = NavigationPath()
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
                            #if os(tvOS)
                            .buttonBorderShape(.circle)
                            .buttonStyle(.borderless)
                            #else
                            .buttonStyle(.plain)
                            #endif
                            .focused($focusedPerson, equals: person.id)
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
        } catch {
            logger.error("Failed to fetch people: \(error.localizedDescription)")
        }
    }
}

struct PersonCell: View {
    let person: Person

    #if os(tvOS)
    private static let thumbnailSize = CGSize(width: 200, height: 200)
    #else
    private static let thumbnailSize = CGSize(width: 300, height: 400)
    #endif

    private static let thumbnailProcessors: [ImageProcessing] = [
        .resize(size: thumbnailSize, crop: true),
    ]

    private var thumbnailRequest: ImageRequest? {
        guard let url = person.thumbnailUrl else { return nil }
        return ImageRequest(url: url, processors: Self.thumbnailProcessors)
    }

    var body: some View {
        #if os(macOS)
        macOSCell
        #else
        tvOSCell
        #endif
    }

    #if os(macOS)
    private var macOSCell: some View {
        ZStack(alignment: .bottomLeading) {
            if let request = thumbnailRequest {
                LazyImage(request: request) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else if state.error != nil {
                        placeholderView
                    } else {
                        Color.gray.opacity(0.2)
                    }
                }
            } else {
                placeholderView
            }

            LinearGradient(
                colors: [.black.opacity(0.6), .clear],
                startPoint: .bottom,
                endPoint: .center
            )

            Text(person.name)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(10)
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fill)
        .clipShape(.rect(cornerRadius: 10))
    }
    #else
    private static let size: CGFloat = 200

    private var tvOSCell: some View {
        VStack(spacing: 12) {
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
    #endif

    private var placeholderView: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .padding(30)
                .foregroundStyle(.gray)
        }
    }
}
