//
//  VideoPlayerDelegate.swift
//  ImmichLens
//

#if os(tvOS)
import AVKit

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
