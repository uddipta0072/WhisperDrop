# WhisperDrop v1.0.0

WhisperDrop transcribes supported audio and video locally on Apple Silicon Macs using whisper.cpp and FFmpeg. Download or import a supported GGML model in the app; transcription can run offline after model installation.

## Features

- Local audio and video transcription.
- Model download or import, with downloaded models checked against pinned SHA-256 digests.
- TXT, SRT, VTT, and JSON exports.
- Translation when supported by the selected model.

## Requirements and test status

- Apple Silicon Mac (arm64).
- macOS 14.0 or later is the app's declared minimum. macOS 14 has not been tested.
- The standalone app was tested on Apple Silicon running macOS 27.2.1. It launched on the administrator account after Gatekeeper authorization with Touch ID.
- A supported model is required and is downloaded separately. Model download needs internet access; transcription can run offline after model installation.

## Security and third-party software

The app is ad hoc signed, has no Developer ID signature, and is not notarized. macOS may require explicit approval at first launch. Use the macOS approval flow if you trust the release; do not disable Gatekeeper globally or remove quarantine attributes as the default installation procedure.

The release includes a separate FFmpeg 9.0.2 source ZIP with its recorded configuration, LGPL text, and library replacement instructions. The build configuration disables FFmpeg GPL and nonfree components. The detached upstream source signature has not been independently verified with an authenticated key. The complete license inventory for compiled code, exact source-to-binary provenance, and Sparkle component inventory remain unresolved; the source ZIP alone does not establish complete compliance.

Download the [v1.0.0 release](https://github.com/uddipta0072/WhisperDrop/releases/tag/v1.0.0).
