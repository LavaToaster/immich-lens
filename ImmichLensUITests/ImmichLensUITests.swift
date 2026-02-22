import XCTest

final class ImmichLensUITests: XCTestCase {
    var app: XCUIApplication!

    // Tab positions (left-to-right) in the tvOS tab bar
    private enum Tab: Int {
        case photos = 0
        case explore = 1
        case people = 2
        case albums = 3
        case favourites = 4
    }

    @MainActor
    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()

        // Forward test plan env vars to the app process so the login views
        // can auto-fill and auto-submit, exercising the real login API flow.
        let env = ProcessInfo.processInfo.environment
        for key in ["IMMICH_TEST_SERVER_URL", "IMMICH_TEST_EMAIL", "IMMICH_TEST_PASSWORD"] {
            if let value = env[key] { app.launchEnvironment[key] = value }
        }
        app.launch()

        // Wait for login to complete and main UI to appear
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 30), "Tab bar did not appear — login may have failed")
    }

    /// Navigate to a tab using the tvOS remote (tap() is unavailable on tvOS).
    /// Each test starts fresh with Photos selected, so we navigate right from there.
    @MainActor
    private func selectTab(_ tab: Tab) {
        let remote = XCUIRemote.shared
        // Press up to ensure the tab bar has focus
        remote.press(.up)
        usleep(500_000)
        // Navigate right from the first tab (Photos) to the target
        for _ in 0..<tab.rawValue {
            remote.press(.right)
            usleep(500_000)
        }
        // Press down to move focus from the tab bar into the content area
        remote.press(.down)
    }

    /// Wait for content to finish loading.
    @MainActor
    private func waitForContentToLoad(timeout: TimeInterval = 15) {
        // Wait for the grid to appear (replaces the loading spinner)
        _ = app.images.firstMatch.waitForExistence(timeout: timeout)
        // Nuke thumbnail downloads happen after the grid renders
        sleep(3)
    }

    /// Take a screenshot and attach it to the test result with a human-readable name.
    @MainActor
    private func takeScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testScreenshotPhotos() {
        waitForContentToLoad()
        takeScreenshot(named: "01_Photos")
    }

    @MainActor
    func testScreenshotExplore() {
        selectTab(.explore)
        waitForContentToLoad()
        takeScreenshot(named: "02_Explore")
    }

    @MainActor
    func testScreenshotPeople() {
        selectTab(.people)
        waitForContentToLoad()
        takeScreenshot(named: "03_People")
    }

    @MainActor
    func testScreenshotAlbums() {
        selectTab(.albums)
        waitForContentToLoad()
        takeScreenshot(named: "04_Albums")
    }

    @MainActor
    func testScreenshotFavourites() {
        selectTab(.favourites)
        waitForContentToLoad()
        takeScreenshot(named: "05_Favourites")
    }
}
