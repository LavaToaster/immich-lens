//
//  AssetGridView.swift
//  ImmichLens
//
//  Created by ImmichLens on 04/05/2025.
//

import AVKit
import Combine
import NukeUI
import SwiftUI

struct AssetGridView: View {
    let assets: [Asset]
    let columns: Int
    let spacing: CGFloat
    let onAssetTap: (Asset) -> Void

    init(
        assets: [Asset],
        columns: Int = 4,
        spacing: CGFloat = 8,
        onAssetTap: @escaping (Asset) -> Void = { _ in }
    ) {
        self.assets = assets
        self.columns = columns
        self.spacing = spacing
        self.onAssetTap = onAssetTap
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: spacing) {
            ForEach(assets) { asset in
                Button {
                    onAssetTap(asset)
                } label: {
                    AssetGridCell(asset: asset)
                        .aspectRatio(1, contentMode: .fit)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(spacing)
    }
}

struct AssetGridCell: View {
    let asset: Asset
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                // Thumbnail image
                if let thumbnailUrl = asset.imageUrl(.thumbnail) {
                    LazyImage(url: thumbnailUrl) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(
                                    width: geometry.size.width,
                                    height: geometry.size.height
                                )
                                .clipped()
                        } else if state.error != nil {
                            placeholderView(
                                geometry: geometry, systemName: "exclamationmark.triangle")
                        } else {
                            placeholderView(geometry: geometry, systemName: "photo")
                        }
                    }
                } else {
                    placeholderView(geometry: geometry, systemName: "photo")
                }

                // Video indicator overlay
                if asset.type == .video {
                    VideoIndicatorOverlay(duration: asset.duration)
                        .padding(8)
                }

                // Focus effect for tvOS
                if isFocused {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white, lineWidth: 4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func placeholderView(geometry: GeometryProxy, systemName: String) -> some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: geometry.size.width * 0.3)
                .foregroundColor(.gray)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
    }
}

struct VideoIndicatorOverlay: View {
    let duration: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "play.fill")
                .font(.caption2)

            if let duration = duration, let formatted = formatDuration(duration) {
                Text(formatted)
                    .font(.caption2)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func formatDuration(_ duration: String) -> String? {
        // Immich returns duration in "H:MM:SS.ffffff" format (e.g., "0:00:05.230000")
        let parts = duration.split(separator: ":")
        guard parts.count == 3 else { return nil }

        let hours = Int(parts[0]) ?? 0
        let minutes = Int(parts[1]) ?? 0
        let secs = Int(Double(String(parts[2])) ?? 0)

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - Asset Detail (Paging Container)

struct AssetDetailView: View {
    let assets: [Asset]
    @Binding var currentIndex: Int
    @State private var isPlayingVideo = false
    #if os(tvOS)
    @State private var player = AVPlayer()
    @State private var endOfVideoObserver: Any?
    @State private var videoPlayerDelegate = VideoPlayerDelegate()
    @State private var playerVC: AVPlayerViewController = {
        let vc = AVPlayerViewController()
        vc.showsPlaybackControls = true
        return vc
    }()
    #endif
    @EnvironmentObject var apiService: APIService

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black

                ForEach(nearbyIndices, id: \.self) { index in
                    AssetPageView(
                        asset: assets[index],
                        isActive: index == currentIndex,
                        isPlayingVideo: $isPlayingVideo
                    )
                    .environmentObject(apiService)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .offset(x: CGFloat(index - currentIndex) * geometry.size.width)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: currentIndex)
        }
        .ignoresSafeArea()
        .focusable(!isPlayingVideo)
        .onPlayPauseCommand {
            handleSelect()
        }
        .onTapGesture {
            handleSelect()
        }
        .onMoveCommand { direction in
            guard !isPlayingVideo else { return }
            switch direction {
            case .left:
                if currentIndex > 0 { currentIndex -= 1 }
            case .right:
                if currentIndex < assets.count - 1 { currentIndex += 1 }
            default:
                break
            }
        }
        .onChange(of: currentIndex) {
            isPlayingVideo = false
        }
        #if os(tvOS)
        .onChange(of: isPlayingVideo) { _, playing in
            if playing {
                // Yield to the run loop so SwiftUI can render the spinner
                // before we do the heavy AVPlayer setup work
                DispatchQueue.main.async {
                    presentVideoPlayer()
                }
            }
        }
        #endif
    }

    private func handleSelect() {
        let asset = assets[currentIndex]
        if asset.type == .video && !isPlayingVideo {
            isPlayingVideo = true
        }
    }

    #if os(tvOS)
    private func presentVideoPlayer() {
        let asset = assets[currentIndex]
        guard asset.type == .video else { return }
        guard let videoUrl = asset.videoUrl else { return }

        let videoAsset = asset.createVideoAsset(token: apiService.token)
            ?? AVURLAsset(url: videoUrl)
        let playerItem = AVPlayerItem(asset: videoAsset)
        // Minimize initial buffering for fast start on local network
        playerItem.preferredForwardBufferDuration = 2.0

        endOfVideoObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main
        ) { _ in
            Task { @MainActor in
                dismissVideoPlayer()
            }
        }

        videoPlayerDelegate.onDismiss = {
            cleanupVideo()
        }

        // Correct pipeline order per WWDC 2016/503:
        // 1. Connect player to its output (AVPlayerViewController) BEFORE assigning the item
        // 2. Signal play intent before loading the item so the pipeline builds correctly
        playerVC.player = player
        playerVC.delegate = videoPlayerDelegate
        player.automaticallyWaitsToMinimizeStalling = false

        guard let topVC = topPresentedViewController() else { return }

        topVC.present(playerVC, animated: true) {
            // 3. Play before assigning item — tells AVPlayer to start immediately once data arrives
            self.player.play()
            // 4. Assign item LAST — triggers pipeline setup with all outputs already connected
            self.player.replaceCurrentItem(with: playerItem)
        }
    }

    private func dismissVideoPlayer() {
        guard let topVC = topPresentedViewController(),
            topVC is AVPlayerViewController
        else { return }
        topVC.dismiss(animated: true)
    }

    private func cleanupVideo() {
        isPlayingVideo = false
        player.pause()
        player.replaceCurrentItem(with: nil)
        if let observer = endOfVideoObserver {
            NotificationCenter.default.removeObserver(observer)
            endOfVideoObserver = nil
        }
    }

    private func topPresentedViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootVC = windowScene.windows.first?.rootViewController
        else { return nil }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return topVC
    }
    #endif

    private var nearbyIndices: [Int] {
        let lo = max(0, currentIndex - 1)
        let hi = min(assets.count - 1, currentIndex + 1)
        return Array(lo...hi)
    }
}

// MARK: - Single Asset Page

struct AssetPageView: View {
    let asset: Asset
    let isActive: Bool
    @Binding var isPlayingVideo: Bool
    #if os(macOS)
    @State private var player: AVPlayer?
    @State private var isLoadingVideo = false
    @State private var videoError: Error?
    @State private var endOfVideoObserver: Any?
    #endif
    @EnvironmentObject var apiService: APIService

    var body: some View {
        ZStack {
            if asset.type == .photo {
                photoView
            } else {
                videoContent
            }
        }
        #if os(macOS)
        .onChange(of: isPlayingVideo) { _, playing in
            if playing && isActive && asset.type == .video {
                startVideoPlayback()
            }
        }
        .onChange(of: isActive) { _, active in
            if !active { cleanupPlayer() }
        }
        .onDisappear {
            cleanupPlayer()
        }
        #endif
    }

    @ViewBuilder
    private var videoContent: some View {
        #if os(macOS)
        if isPlayingVideo && isActive {
            videoPlayerView
        } else {
            videoTransitionView
        }
        #else
        if isPlayingVideo && isActive {
            videoLoadingView
        } else {
            videoTransitionView
        }
        #endif
    }

    // MARK: - Photo

    private var photoView: some View {
        Group {
            if let imageUrl = asset.imageUrl(.preview) {
                LazyImage(url: imageUrl) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else if state.error != nil {
                        errorView("Failed to load photo")
                    } else {
                        ProgressView()
                            .scaleEffect(1.5)
                    }
                }
            } else {
                errorView("Photo not available")
            }
        }
    }

    // MARK: - Video Transition Screen

    private var videoTransitionView: some View {
        videoThumbnailView {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(radius: 10)
        }
    }

    #if os(tvOS)
    private var videoLoadingView: some View {
        videoThumbnailView {
            ProgressView()
                .scaleEffect(2)
        }
    }
    #endif

    private func videoThumbnailView<Overlay: View>(@ViewBuilder overlay: () -> Overlay) -> some View
    {
        ZStack {
            if let imageUrl = asset.imageUrl(.preview) {
                LazyImage(url: imageUrl) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Color.black
                    }
                }
            }

            overlay()
        }
    }

    // MARK: - Video Playback (macOS only — tvOS uses fullScreenCover on AssetDetailView)

    #if os(macOS)
    private var videoPlayerView: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
            }

            if isLoadingVideo {
                ProgressView()
                    .scaleEffect(1.5)
            }

            if let error = videoError {
                errorView(error.localizedDescription)
            }
        }
        .onExitCommand {
            isPlayingVideo = false
            player?.pause()
        }
    }

    private func startVideoPlayback() {
        isLoadingVideo = true
        videoError = nil

        guard let videoUrl = asset.videoUrl else {
            videoError = NSError(
                domain: "dev.lav.immichlens", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Video URL not available"])
            isLoadingVideo = false
            return
        }

        logger.info("Loading video for asset: \(asset.id)")

        let videoAsset = asset.createVideoAsset(token: apiService.token)
            ?? AVURLAsset(url: videoUrl)
        let playerItem = AVPlayerItem(asset: videoAsset)
        let newPlayer = AVPlayer(playerItem: playerItem)

        endOfVideoObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main
        ) { _ in
            Task { @MainActor in
                isPlayingVideo = false
                player?.pause()
            }
        }

        self.player = newPlayer
        isLoadingVideo = false
        newPlayer.play()
    }

    private func cleanupPlayer() {
        player?.pause()
        player = nil
        isLoadingVideo = false
        videoError = nil
        if let observer = endOfVideoObserver {
            NotificationCenter.default.removeObserver(observer)
            endOfVideoObserver = nil
        }
    }
    #endif

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text(message)
                .font(.title3)
        }
        .foregroundColor(.white)
    }
}

// MARK: - tvOS Video Player Delegate

#if os(tvOS)
    class VideoPlayerDelegate: NSObject, AVPlayerViewControllerDelegate {
        var onDismiss: (() -> Void)?

        func playerViewControllerShouldDismiss(
            _ playerViewController: AVPlayerViewController
        ) -> Bool {
            return true
        }

        func playerViewControllerDidEndDismissalTransition(
            _ playerViewController: AVPlayerViewController
        ) {
            playerViewController.player?.pause()
            onDismiss?()
        }
    }
#endif
