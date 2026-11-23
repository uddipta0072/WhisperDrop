# Native build notes

The source project was inspected with Xcode 27.2 and has a macOS 14 deployment target. Its scheme is `MyApp`. On an Apple Silicon Mac with a compatible Xcode installation, the SwiftUI target can be built with:

```sh
xcodebuild -project 'Untitled Project.xcodeproj' -scheme MyApp \
  -configuration Release -derivedDataPath build/DerivedData \
  ARCHS=arm64 MACOSX_DEPLOYMENT_TARGET=14.0 CODE_SIGNING_ALLOWED=NO build
```

The resulting app is in `build/DerivedData/Build/Products/Release/WhisperDrop.app`. This command builds the application target only. For transcription, the app expects `whisper-cli`, `ffmpeg`, and their required libraries under `WhisperDrop.app/Contents/Resources/NativeRuntime/`. This repository deliberately excludes prebuilt executables and models. The frozen candidate used whisper.cpp 1.9.5 built for arm64 with Metal, static whisper.cpp libraries, `GGML_NATIVE=OFF`, and macOS 14 as its deployment target. Its FFmpeg 9.0.2 build configuration and source link are documented in [third-party/FFMPEG.md](third-party/FFMPEG.md).

A complete, tested procedure for building and staging the exact native runtime, relocating its dynamic libraries, signing the resulting app, and verifying third-party notices has not yet been recovered. Accordingly these notes do not claim a reproducible build of the frozen binary. Build and redistribution of the runtime require an independent dependency and license review. The normal target compiles the disabled updater fallback when Sparkle is unavailable; no update feed or key is configured.
