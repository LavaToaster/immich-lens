//
//  AssetDetailView.swift
//  ImmichLens
//

import AVKit
import SwiftUI

struct AssetDetailView: View {
    let assets: [Asset]
    @Binding var currentIndex: Int
    @Environment(\.dismiss) private var dismiss
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
        #if os(tvOS)
        .ignoresSafeArea()
        .navigationBarBackButtonHidden()
        #endif
        #if os(tvOS)
        .focusable(!isPlayingVideo)
        .onPlayPauseCommand {
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
        #endif
        #if os(macOS)
        .focusable()
        .onKeyPress(.leftArrow) {
            guard !isPlayingVideo, currentIndex > 0 else { return .ignored }
            currentIndex -= 1
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard !isPlayingVideo, currentIndex < assets.count - 1 else { return .ignored }
            currentIndex += 1
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        #endif
        .onTapGesture {
            handleSelect()
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
