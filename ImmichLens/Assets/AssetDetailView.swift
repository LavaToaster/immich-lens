//
//  AssetDetailView.swift
//  ImmichLens
//

import AVKit
import SwiftUI

struct AssetDetailView: View {
    let assets: [Asset]
    @State private var currentIndex: Int

    init(assets: [Asset], initialAsset: Asset) {
        self.assets = assets
        let index = assets.firstIndex(of: initialAsset) ?? 0
        self._currentIndex = State(initialValue: min(index, max(assets.count - 1, 0)))
    }
    @Environment(\.dismiss) private var dismiss
    @State private var isPlayingVideo = false
    #if os(macOS)
    @FocusState private var isDetailFocused: Bool
    #endif
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
        if assets.isEmpty {
            ContentUnavailableView("No Photos", systemImage: "photo")
        } else {
        GeometryReader { geometry in
            ZStack {
                #if !os(macOS)
                Color.black
                    .ignoresSafeArea()
                #endif

                #if os(macOS)
                AssetPageView(
                    asset: assets[currentIndex],
                    isActive: true,
                    isPlayingVideo: $isPlayingVideo
                )
                .id(currentIndex)
                .environmentObject(apiService)
                .frame(width: geometry.size.width, height: geometry.size.height)
                #else
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
                #endif
            }
            #if !os(macOS)
            .animation(.easeInOut(duration: 0.3), value: currentIndex)
            #endif
        }
        #if os(tvOS)
        .ignoresSafeArea()
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .tabBar)
        #else
        .navigationTitle(currentAsset.locationTitle)
        .navigationSubtitle(currentAsset.detailSubtitle(index: currentIndex, total: assets.count))
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
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
        .focusEffectDisabled()
        .focused($isDetailFocused)
        .onAppear { isDetailFocused = true }
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
        } // else
    }

    private var safeIndex: Int {
        min(currentIndex, max(assets.count - 1, 0))
    }

    private var currentAsset: Asset {
        assets[safeIndex]
    }

    private func handleSelect() {
        let asset = currentAsset
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
        guard !assets.isEmpty else { return [] }
        let lo = max(0, currentIndex - 1)
        let hi = min(assets.count - 1, currentIndex + 1)
        return Array(lo...hi)
    }
}
