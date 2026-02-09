# CLAUDE.md

## Project Overview

ImmichLens is a native SwiftUI app for viewing photos and videos stored on an [Immich](https://immich.app/) server. It targets **macOS 15.0+** and **tvOS 18.4+**.

## Build Commands

```bash
# Build for macOS
xcodebuild -project ImmichLens.xcodeproj -scheme ImmichLens -destination 'platform=macOS' build

# Build for tvOS simulator
xcodebuild -project ImmichLens.xcodeproj -scheme ImmichLens -destination 'platform=tvOS Simulator,name=Apple TV' build
```

No tests or linting are configured.

## Xcode Project Structure

The project uses Xcode's **file system synchronized groups** (`fileSystemSynchronizedGroups` in `project.pbxproj`). New `.swift` files added to existing directories are picked up automatically — no manual `project.pbxproj` edits needed.

## tvOS Image Guidelines

On tvOS, don't manually clip or constrain images with `.frame`, `.clipShape`, or `.cornerRadius` — these fight the system focus engine (scaling, shadows, highlights). Use Nuke processors (e.g. `.resize(size:crop:)`) to get the image to the right dimensions, then hand the result straight to SwiftUI. Only use `.frame` on placeholders where there's no image to size from.

## Important

The API client is auto-generated from `ImmichLens/openapi.json` using `swift-openapi-generator`. Do not hand-edit generated code — modify the OpenAPI spec or `openapi-generator-config.yaml` instead.
