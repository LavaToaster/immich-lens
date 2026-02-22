# Hacks & Workarounds

## Per-SDK App Icon Override (macOS + tvOS)

The app uses an Icon Composer `.icon` file for the macOS Liquid Glass icon and a traditional `Icons.brandassets` (with layered imagestacks) for tvOS. Since Icon Composer doesn't support tvOS layered icons, we need per-SDK build setting overrides to point each platform at the right asset:

```
ASSETCATALOG_COMPILER_APPICON_NAME = "App Icon"          // default — macOS uses App Icon.icon
ASSETCATALOG_COMPILER_APPICON_NAME[sdk=appletv*] = Icons  // tvOS uses Icons.brandassets
```

The wildcard `appletv*` is important — it matches both `appletvos` (device) and `appletvsimulator` (simulator). Using only `appletvos*` would leave the simulator falling back to the `.icon` file, which has no tvOS icon data.

We also set `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = YES` to ensure the asset compiler generates all icon variants from the `.icon` file.
