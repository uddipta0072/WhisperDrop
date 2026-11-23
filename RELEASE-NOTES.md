# WhisperDrop — First Public Preview

Version 1.0 (build 1). This preview targets Apple Silicon and macOS 14 or later; operation on macOS 14 has not been tested. A standalone candidate passed a transcription test in a macOS Guest account; the precise macOS version and model used in that test were not recorded here.

WhisperDrop transcribes locally with whisper.cpp once a model is installed. Models can be downloaded in the app, and exports are available in TXT, SRT, VTT and JSON. The standalone candidate bundles FFmpeg and does not require Python, Homebrew or Xcode for normal use. Supported formats are limited by the bundled FFmpeg configuration. Accuracy and speed depend on the model and input. Automatic updates are disabled.

The frozen candidate is ad-hoc signed and is not notarized. Its distribution is blocked pending completion of the third-party licensing review; no binary should be attached until that review passes. Its SHA-256 is `49013f17e7be6db33b69a3a895cbd596e5e25f4935b2aef4e4bb64da2b03f6e6`. Corresponding FFmpeg source availability, replacement/relinking requirements and complete notices for all bundled dependencies remain to be verified.
