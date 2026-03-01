//
//  RemoteInputView.swift
//  ImmichLens
//

#if os(tvOS)
import SwiftUI
import UIKit

struct RemoteInputView: UIViewRepresentable {
    var onSelect: () -> Void
    var onPlayPause: () -> Void
    var onLeft: () -> Void
    var onRight: () -> Void

    func makeUIView(context: Context) -> RemoteInputUIView {
        let view = RemoteInputUIView()
        view.onSelect = onSelect
        view.onPlayPause = onPlayPause
        view.onLeft = onLeft
        view.onRight = onRight
        return view
    }

    func updateUIView(_ uiView: RemoteInputUIView, context: Context) {
        uiView.onSelect = onSelect
        uiView.onPlayPause = onPlayPause
        uiView.onLeft = onLeft
        uiView.onRight = onRight
    }
}

class RemoteInputUIView: UIView {
    var onSelect: (() -> Void)?
    var onPlayPause: (() -> Void)?
    var onLeft: (() -> Void)?
    var onRight: (() -> Void)?

    override var canBecomeFocused: Bool { true }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        // No visual focus effect
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            switch press.type {
            case .select:
                onSelect?()
                return
            case .playPause:
                onPlayPause?()
                return
            case .leftArrow:
                onLeft?()
                return
            case .rightArrow:
                onRight?()
                return
            default:
                break
            }
        }
        super.pressesBegan(presses, with: event)
    }
}
#endif
