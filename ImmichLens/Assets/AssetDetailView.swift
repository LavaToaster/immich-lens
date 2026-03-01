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
    @State private var stallObserver: NSKeyValueObservation?
    @State private var stallCount = 0
    @State private var stallTimer: Timer?
    @State private var videoPlayerDelegate = VideoPlayerDelegate()
    @State private var playerVC: AVPlayerViewController?
    #endif
    @Environment(APIService.self) private var apiService

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
                .environment(apiService)
                .frame(width: geometry.size.width, height: geometry.size.height)
                #elseif os(tvOS)
                ForEach(nearbyIndices, id: \.self) { index in
                    AssetPageView(
                        asset: assets[index],
                        isActive: index == currentIndex,
                        isPlayingVideo: $isPlayingVideo
                    )
                    .environment(apiService)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .offset(x: CGFloat(index - currentIndex) * geometry.size.width)
                }
                RemoteInputView(
                    onSelect: { handleSelect() },
                    onPlayPause: { handleSelect() },
                    onLeft: { if currentIndex > 0 { currentIndex -= 1 } },
                    onRight: { if currentIndex < assets.count - 1 { currentIndex += 1 } }
                )
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
        #if os(macOS)
        .onTapGesture {
            handleSelect()
        }
        #endif
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
            logger.info("Video playback requested for asset \(asset.id)")
            isPlayingVideo = true
        }
    }

    #if os(tvOS)
    @State private var videoEndpoint: Asset.VideoEndpoint = .transcoded

    private func presentVideoPlayer() {
        let asset = assets[currentIndex]
        guard asset.type == .video else { return }

        logger.info("Presenting video player for asset \(asset.id), endpoint: \(String(describing: self.videoEndpoint))")

        guard loadVideo(endpoint: videoEndpoint) else { return }

        videoPlayerDelegate.onDismiss = {
            cleanupVideo()
        }

        let vc = AVPlayerViewController()
        vc.player = player
        vc.delegate = videoPlayerDelegate
        vc.transportBarCustomMenuItems = [makeEndpointMenu()]
        playerVC = vc

        guard let topVC = topPresentedViewController() else { return }

        topVC.present(vc, animated: true) {
            self.player.play()
        }
    }

    @discardableResult
    private func loadVideo(endpoint: Asset.VideoEndpoint) -> Bool {
        let asset = assets[currentIndex]
        guard asset.type == .video else { return false }

        if let observer = endOfVideoObserver {
            NotificationCenter.default.removeObserver(observer)
            endOfVideoObserver = nil
        }

        resetStallTracking()

        let videoAsset = asset.createVideoAsset(token: apiService.token, endpoint: endpoint)
        guard let videoAsset else { return false }
        let playerItem = AVPlayerItem(asset: videoAsset)

        endOfVideoObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main
        ) { _ in
            Task { @MainActor in
                self.dismissVideoPlayer()
            }
        }

        player.replaceCurrentItem(with: playerItem)
        return true
    }

    private func observeStalls() {
        stallObserver = player.observe(\.timeControlStatus) { observedPlayer, _ in
            Task { @MainActor in
                let status = observedPlayer.timeControlStatus

                if status == .waitingToPlayAtSpecifiedRate {
                    guard self.stallTimer == nil else { return }
                    self.stallCount += 1
                    logger.warning("Video stall #\(self.stallCount)")
                    self.stallTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                        Task { @MainActor in
                            self.stallCount += 1
                            logger.warning("Video stalling: \(self.stallCount) stall count")
                            self.checkStallAlert()
                        }
                    }
                } else {
                    self.stallTimer?.invalidate()
                    self.stallTimer = nil
                }

            }
        }
    }

    @State private var stallAlertShown = false

    private func showStallAlert(_ message: String) {
        guard !stallAlertShown else { return }
        stallAlertShown = true

        let alert = UIAlertController(
            title: "Playback Issue",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))

        playerVC?.present(alert, animated: true)
    }

    private func checkStallAlert() {
        guard stallCount >= 10 else { return }

        let item = player.currentItem
        let event = item?.accessLog()?.events.last
        let downloadBitrate = event?.observedBitrate ?? 0
        let videoBitrate = event?.indicatedBitrate ?? 0

        logger.error("Playback issue detected: \(stallCount) stall count, download: \(String(format: "%.1f", downloadBitrate / 1_000_000)) Mbps, video: \(String(format: "%.1f", videoBitrate / 1_000_000)) Mbps, endpoint: \(String(describing: videoEndpoint))")

        let message: String
        if videoBitrate > 0 && downloadBitrate > videoBitrate * 1.5 {
            if videoEndpoint == .transcoded {
                message = "This video's transcode may be too high for Apple TV. Try lowering the transcoding bitrate in your Immich server settings."
            } else {
                message = "This video's format may not stream well on Apple TV. Try switching to Transcoded in the transport bar."
            }
        } else if videoBitrate > 0 && downloadBitrate < videoBitrate {
            if videoEndpoint == .original {
                message = "Your connection may be too slow for this video. Try switching to Transcoded in the transport bar."
            } else {
                message = "Your connection may be too slow for this video."
            }
        } else {
            message = "This video is having trouble playing. Try switching source in the transport bar."
        }

        showStallAlert(message)
    }

    private func resetStallTracking(observe: Bool = true) {
        stallCount = 0
        stallTimer?.invalidate()
        stallTimer = nil
        stallAlertShown = false
        stallObserver = nil
        if observe { observeStalls() }
    }

    private func makeEndpointMenu() -> UIMenu {
        UIMenu(
            title: "Source",
            image: UIImage(systemName: videoEndpoint == .original ? "film" : "play.rectangle"),
            children: [
                UIAction(
                    title: "Original",
                    image: UIImage(systemName: "film"),
                    state: videoEndpoint == .original ? .on : .off
                ) { _ in
                    self.reloadVideo(endpoint: .original)
                },
                UIAction(
                    title: "Transcoded",
                    image: UIImage(systemName: "play.rectangle"),
                    state: videoEndpoint == .transcoded ? .on : .off
                ) { _ in
                    self.reloadVideo(endpoint: .transcoded)
                },
            ]
        )
    }

    private func reloadVideo(endpoint: Asset.VideoEndpoint) {
        guard endpoint != videoEndpoint else { return }
        videoEndpoint = endpoint

        let seekTime = player.currentTime()
        player.pause()

        guard loadVideo(endpoint: endpoint) else { return }
        playerVC?.transportBarCustomMenuItems = [makeEndpointMenu()]

        if seekTime.isValid && seekTime.seconds > 0 {
            player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                self.player.play()
            }
        } else {
            player.play()
        }
    }

    private func dismissVideoPlayer() {
        isPlayingVideo = false
        guard let topVC = topPresentedViewController(),
            topVC is AVPlayerViewController
        else { return }
        topVC.dismiss(animated: true)
    }

    private func cleanupVideo() {
        isPlayingVideo = false
        player.pause()
        player.replaceCurrentItem(with: nil)
        playerVC = nil
        if let observer = endOfVideoObserver {
            NotificationCenter.default.removeObserver(observer)
            endOfVideoObserver = nil
        }
        resetStallTracking(observe: false)
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
