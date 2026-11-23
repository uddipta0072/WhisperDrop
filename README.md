# WhisperDrop

A lightweight, offline AI transcription app for macOS, powered by whisper.cpp.

## Features

- Transcribe supported local audio and video using a GGML whisper.cpp model.
- Download or import supported models in the app; downloads are checked against pinned SHA-256 digests.
- Transcribe offline after a model is installed.
- Export TXT, SRT, VTT, and JSON.

## Requirements and limitations

The preview targets Apple Silicon and macOS 14 or later; actual operation on macOS 14 has not been tested. A model download requires internet access and disk space. The bundled FFmpeg configuration supports a limited set of media formats; some files may not be accepted. Transcription accuracy and speed depend on the model and input. Sparkle updates are disabled.

The frozen preview candidate is ad-hoc signed and unnotarized. Its binary distribution is on hold pending third-party license and corresponding-source review. The app's internal version is 1.0 (build 1), and the planned preview release will use that version. A fresh macOS Guest-account transcription test was reported by the project owner; macOS 14 compatibility was not established by that report.

## Screenshots

Screenshots are not yet included. No reviewed, privacy-safe screenshots were available in the project snapshot.

## Building from source

See [BUILDING.md](BUILDING.md). The repository excludes prebuilt runtime binaries and model weights. Building the SwiftUI target alone does not produce a working transcription bundle: it also needs compatible whisper.cpp and FFmpeg executables and their runtime dependencies.

## Third-party software

See [third-party notices](third-party/NOTICES.md) and the [FFmpeg configuration and source information](third-party/FFMPEG.md). WhisperDrop uses FFmpeg, licensed under LGPL 2.1 or later, and whisper.cpp; optional updater integration uses Sparkle. Third-party licenses apply independently of the license for WhisperDrop's original code.

## License

WhisperDrop's original source code is available under the [MIT License](LICENSE), copyright 2026 Uddipta Mani. Third-party components retain their own licenses and attribution requirements.
