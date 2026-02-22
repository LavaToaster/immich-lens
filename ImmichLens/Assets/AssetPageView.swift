//
//  AssetPageView.swift
//  ImmichLens
//

import AVKit
import Nuke
import NukeUI
import SwiftUI

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
    @Environment(APIService.self) private var apiService

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
            videoPreviewView
        }
        #else
        if isPlayingVideo && isActive {
            videoLoadingView
        } else {
            videoPreviewView
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
                    } else if let placeholder = cachedThumbnail {
                        placeholder
                            .resizable()
                            .aspectRatio(contentMode: .fit)
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

    // MARK: - Video Preview

    private var videoPreviewView: some View {
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
                    } else if let placeholder = cachedThumbnail {
                        placeholder
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

    // MARK: - Video Playback (macOS only — tvOS presents AVPlayerViewController modally)

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

    private var cachedThumbnail: Image? {
        guard let url = asset.imageUrl(.thumbnail) else { return nil }
        let request = ImageRequest(url: url)
        guard let container = ImagePipeline.shared.cache.cachedImage(for: request) else {
            return nil
        }
        #if os(macOS)
        return Image(nsImage: container.image)
        #else
        return Image(uiImage: container.image)
        #endif
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text(message)
                .font(.title3)
        }
        .foregroundStyle(.white)
    }
}
