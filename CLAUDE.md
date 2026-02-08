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

## Important

The API client is auto-generated from `ImmichLens/openapi.json` using `swift-openapi-generator`. Do not hand-edit generated code — modify the OpenAPI spec or `openapi-generator-config.yaml` instead.
