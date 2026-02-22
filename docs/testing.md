# Testing Strategy

ImmichLens is a thin client over the Immich API. Most of its code is SwiftUI views and network calls — things that are hard (and low-value) to unit test in isolation. The testing strategy reflects this: focus unit tests on the small amount of pure logic that exists, and use end-to-end screenshot tests to catch regressions in the full user-facing flow.

## Two Test Layers

### Unit Tests

The model layer is the one place with pure, deterministic logic — URL construction, formatting, display helpers. Bugs here break silently (blank screens, wrong metadata), so fast offline unit tests are worth the minimal effort.

Test behaviour (outcomes), not implementation — assert that a URL has the right shape, not how it was built.

**What NOT to unit test:**
- SwiftUI views — test these visually with screenshot tests
- Network calls — the API client is auto-generated; test it end-to-end
- Anything that would require mocking `Components.Schemas.*` DTOs

### E2E / Screenshot Tests

These launch the full app against a real Immich server, log in, navigate every tab, and capture screenshots. They verify that the login flow works, data loads, and the UI renders correctly. They're slow (30s+) and require a running server, so they run in CI or manually — not on every save.

**What they catch:**
- Login/auth regressions
- Tab navigation breaking
- Layout or rendering issues after SwiftUI changes
- Missing or broken thumbnail loading

### Why not integration tests with mocked API responses?

E2E screenshot tests against a real server were simpler to set up than maintaining a mock layer, and if the app grows to include more complex client-side logic (caching, offline sync, conflict resolution), mocked integration tests would start pulling their weight. PRs welcome.

## Running Tests

```bash
# Unit tests (fast, no server needed)
xcodebuild test \
  -project ImmichLens.xcodeproj -scheme ImmichLens \
  -destination 'platform=tvOS Simulator,name=Apple TV' \
  -only-testing ImmichLensTests \
  -skipPackagePluginValidation

# Screenshot tests (needs live Immich server)
xcodebuild test \
  -project ImmichLens.xcodeproj -scheme ImmichLens \
  -destination 'platform=tvOS Simulator,name=Apple TV' \
  -only-testing ImmichLensUITests \
  -skipPackagePluginValidation
```

For macOS, replace the destination with `-destination 'platform=macOS'`.

## Adding Tests

### New unit tests

1. Create a `*Tests.swift` file in `ImmichLensTests/`. It's auto-discovered — no `project.pbxproj` edits needed.
2. Use `@testable import ImmichLens` and the DTO factory helpers in `TestHelpers.swift`.
3. If you're adding logic to a model, add a test. If you're adding a new view, a screenshot test is more appropriate.

### New screenshot tests

1. Add a `func testScreenshot*()` method to `ImmichLensUITests.swift`.
2. Use the existing `selectTab(_:)`, `waitForContentToLoad()`, and `takeScreenshot(named:)` helpers.

## Environment Variables (Screenshot Tests)

| Variable | Purpose |
|----------|---------|
| `IMMICH_TEST_SERVER_URL` | Base URL of the Immich server |
| `IMMICH_TEST_EMAIL` | Login email |
| `IMMICH_TEST_PASSWORD` | Login password |

Set these in the shell, an Xcode test plan, or CI environment before running screenshot tests.
