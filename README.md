<p align="center">
  <img src="ImmichLens/Assets.xcassets/Icons.brandassets/tvOS Top Shelf Image Wide.imageset/tvOS Top Shelf Wide@2x.png" alt="ImmichLens banner" width="100%">
</p>

<h1 align="center">ImmichLens</h1>

<p align="center">
  A native SwiftUI app for viewing your photos and videos on an <a href="https://immich.app/">Immich</a> server.<br>
  Primarily built for <strong>Apple TV</strong>, with <strong>macOS</strong> support.
</p>

<p align="center">
  <a href="https://testflight.apple.com/join/azBvZQCs"><img src="https://img.shields.io/badge/TestFlight-Join%20Beta-0D96F6?logo=apple&logoColor=white" alt="Join TestFlight Beta"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2026.0%2B-blue" alt="macOS 26.0+">
  <img src="https://img.shields.io/badge/platform-tvOS%2026.0%2B-black" alt="tvOS 26.0+">
  <img src="https://img.shields.io/badge/Swift-SwiftUI-orange" alt="SwiftUI">
</p>

---

> [!IMPORTANT]
> ImmichLens is an independent project and is not affiliated with or endorsed by the Immich team.

## Goal

ImmichLens is not a full Immich client — it's a lens into your library. The focus is on providing a native, Apple-like viewing experience rather than 1-to-1 feature parity.

## Install

**Apple TV (tvOS)** — Install via [TestFlight](https://testflight.apple.com/join/azBvZQCs). Open the link on your iPhone or iPad signed into the same Apple Account as your Apple TV, then accept the invite — the app will appear on your Apple TV automatically.

**macOS** — Download the latest `.dmg` from [GitHub Releases](https://github.com/LavaToaster/immich-lens/releases).

## Screenshots

### tvOS

<p align="center">
  <img src="screenshots/tvOS/01_Photos.png" alt="Photos" width="49%">
  <img src="screenshots/tvOS/02_Explore.png" alt="Explore" width="49%">
</p>
<p align="center">
  <img src="screenshots/tvOS/03_People.png" alt="People" width="49%">
  <img src="screenshots/tvOS/04_Albums.png" alt="Albums" width="49%">
</p>
<p align="center">
  <img src="screenshots/tvOS/05_Favourites.png" alt="Favourites" width="49%">
</p>

### macOS

<p align="center">
  <img src="screenshots/macOS/01_Photos.png" alt="Photos" width="49%">
  <img src="screenshots/macOS/02_Explore.png" alt="Explore" width="49%">
</p>
<p align="center">
  <img src="screenshots/macOS/03_People.png" alt="People" width="49%">
  <img src="screenshots/macOS/04_Settings.png" alt="Settings" width="49%">
</p>
<p align="center">
  <img src="screenshots/macOS/05_Albums.png" alt="Albums" width="49%">
  <img src="screenshots/macOS/06_Favourites.png" alt="Favourites" width="49%">
</p>

## Features

- **Photo & Video Timeline** — Browse your entire library in a responsive grid with time-bucket pagination
- **Explore** — Discover your library through recognized people and places
- **Albums** — View and browse your Immich albums
- **Favourites** — Quick access to your starred photos and videos
- **Full-Screen Viewer** — Swipe through photos and play videos natively
- **Secure Authentication** — Connect to your Immich server with credentials stored in Keychain

## Development

### API Client

The API client is auto-generated from the Immich OpenAPI spec using [`swift-openapi-generator`](https://github.com/apple/swift-openapi-generator) as part of the Xcode build process.

### VS Code Setup

If you prefer VS Code over Xcode for development:

1. Install the Xcode build server:
    ```
    brew install xcode-build-server
    ```
2. Install VS Code extensions: [Swift][swift] and [SweetPad][sweetpad]
3. Run `SweetPad: Generate Build Server Config` from the command palette
4. Run `SweetPad: Start Build Server` from the command palette

More on SweetPad: [docs][sweetpad-docs] | [autocomplete setup][sweetpad-autocomplete]

[swift]: https://marketplace.visualstudio.com/items?itemName=swiftlang.swift-vscode
[sweetpad]: https://marketplace.visualstudio.com/items?itemName=SweetPad.sweetpad
[sweetpad-docs]: https://sweetpad.hyzyla.dev/docs/intro
[sweetpad-autocomplete]: https://sweetpad.hyzyla.dev/docs/autocomplete

## Attribution

The tab-switch navigation fix (recreating `NavigationStack` on reactivation to work around a SwiftUI `.sidebarAdaptable` bug) was inspired by [ShelfPlayer](https://github.com/rasmuslos/ShelfPlayer)'s `NavigationStackWrapper` pattern.
