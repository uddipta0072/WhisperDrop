# WhisperDrop

WhisperDrop transcribes supported audio and video locally on macOS using whisper.cpp and FFmpeg. After a supported speech model is installed, transcription can run offline. The app does not include a model.

## Download

Download the [WhisperDrop v1.0.0 release](https://github.com/uddipta0072/WhisperDrop/releases/tag/v1.0.0). The release provides a standalone app ZIP and a separate FFmpeg source ZIP. The source ZIP provides FFmpeg source and replacement information; it does not by itself resolve all open third-party inventory and provenance questions described below.

See [v1.0.0 release notes](RELEASE-NOTES.md) for a concise summary of the published build.

## Features

- Transcribe supported local audio and video files on the Mac.
- Download or import supported GGML Whisper models in the app. Downloaded model files are checked against pinned SHA-256 digests.
- Choose transcription or translation where supported by the selected model.
- Export transcripts as plain text (TXT), SubRip subtitles (SRT), WebVTT subtitles (VTT), or JSON.
- Use the app offline after a model is installed.

Media input support depends on the bundled FFmpeg build. Its recorded configuration enables MOV, Matroska, MP3, WAV, FLAC, OGG, AAC, MPEG-TS, MPEG, and AVI demuxers with a limited decoder set; not every codec or file using those containers is guaranteed to work. Transcription speed and accuracy depend on the model and recording.

## Requirements and tested systems

- Apple Silicon Mac (arm64).
- macOS 14.0 or later is the app's declared minimum. macOS 14 has not been tested.
- The released app was tested on Apple Silicon running macOS 27.2.1. The administrator account successfully launched the standalone app after authorizing it through macOS security prompts with Touch ID. This is a report of that machine and account, not a test across macOS versions or a claim of notarization.
- A supported model is required for transcription. Downloading a model requires internet access and disk space; installed models can be used offline.

## Installation and first launch

1. Download the standalone app ZIP from the [v1.0.0 release](https://github.com/uddipta0072/WhisperDrop/releases/tag/v1.0.0) and extract it.
2. Move `WhisperDrop.app` to Applications (recommended) and open it.
3. If macOS blocks first launch, use the normal macOS approval flow: open **System Settings → Privacy & Security**, review the blocked-app notice, and choose **Open Anyway** if you trust the download. Authenticate when macOS asks. You may also Control-click the app and choose **Open** to review the prompt.
4. Do not disable Gatekeeper globally or remove quarantine attributes as the routine installation procedure. If macOS does not offer an approval option, verify the release and its source before proceeding.
5. In WhisperDrop, download or import a supported model, select an audio or video file, choose output formats, and start transcription.

The app is ad hoc signed, has no Developer ID signature, and is not notarized. Gatekeeper behavior can vary by macOS version and machine policy. The successful administrator-account launch described above required user authorization.

## Screenshots

No genuine application screenshots are available in this repository yet. See [Screenshots/README.md](Screenshots/README.md) for the requested captures. Screenshots will be added only after capture from the running app and review for private file names or other personal information.

## Third-party software

The app bundles FFmpeg 9.0.2 as shared libraries. Its recorded build configuration disables GPL and nonfree FFmpeg components and lists enabled demuxers, decoders, and related options. The release includes the FFmpeg source ZIP, LGPL text, configuration, and instructions that describe replacing a shared library on a copy of the app. The detached upstream source signature is included but has not been independently verified with an authenticated key.

The available release audit identifies unresolved questions: a complete license inventory for all compiled code, exact source-to-binary provenance (including the complete static dependency closure), and whether the bundled Sparkle framework's compiled component inventory matches the supplied notices. The documented FFmpeg replacement exercise is evidence for one tested replacement path, not a complete compliance determination. Review the app's `Contents/Resources/NativeRuntime/Licenses` and the companion source ZIP; do not infer complete compliance solely from the existence of that ZIP. See [third-party notices](third-party/NOTICES.md), [FFmpeg build and source information](third-party/FFMPEG.md), and [BUILDING.md](BUILDING.md).

## License

WhisperDrop's original source code is available under the [MIT License](LICENSE), copyright 2026 Uddipta Mani. Third-party components retain their own licenses and attribution requirements.
