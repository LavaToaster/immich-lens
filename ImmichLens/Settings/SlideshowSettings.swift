import Foundation

enum SlideshowTransition: String, CaseIterable {
    case slide, fade
}

enum SlideshowImageMode: String, CaseIterable {
    case fit, cover
}

struct SlideshowSettings {
    private static let transitionKey = "slideshow.transition"
    private static let intervalKey = "slideshow.interval"
    private static let showProgressBarKey = "slideshow.showProgressBar"
    private static let imageModeKey = "slideshow.imageMode"
    private static let kenBurnsKey = "slideshow.kenBurns"

    static let intervalOptions: [Double] = [3, 5, 10, 15, 30]

    var transition: SlideshowTransition {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Self.transitionKey),
                  let value = SlideshowTransition(rawValue: raw) else { return .slide }
            return value
        }
        nonmutating set { UserDefaults.standard.set(newValue.rawValue, forKey: Self.transitionKey) }
    }

    var interval: Double {
        get {
            let value = UserDefaults.standard.double(forKey: Self.intervalKey)
            return value > 0 ? value : 5
        }
        nonmutating set { UserDefaults.standard.set(newValue, forKey: Self.intervalKey) }
    }

    var showProgressBar: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.showProgressBarKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: Self.showProgressBarKey)
        }
        nonmutating set { UserDefaults.standard.set(newValue, forKey: Self.showProgressBarKey) }
    }

    var kenBurnsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.kenBurnsKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: Self.kenBurnsKey)
        }
        nonmutating set { UserDefaults.standard.set(newValue, forKey: Self.kenBurnsKey) }
    }

    var imageMode: SlideshowImageMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Self.imageModeKey),
                  let value = SlideshowImageMode(rawValue: raw) else { return .fit }
            return value
        }
        nonmutating set { UserDefaults.standard.set(newValue.rawValue, forKey: Self.imageModeKey) }
    }
}
