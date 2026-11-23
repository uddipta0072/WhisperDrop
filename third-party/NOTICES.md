# Third-party notices

- [whisper.cpp](https://github.com/ggml-org/whisper.cpp), version 1.9.5, MIT: [license](licenses/whisper.cpp-MIT.txt). The candidate's `whisper-cli` statically includes ggml. The notices for its other compiled components, including possible example dependencies, still need verification against the exact source and build.
- [FFmpeg](https://ffmpeg.org/), version 9.0.2, LGPL 2.1 or later: [license](licenses/FFmpeg-LGPL-2.1.txt) and [source and configuration](FFMPEG.md). The candidate used shared FFmpeg libraries and disabled GPL and nonfree components.
- [Sparkle](https://sparkle-project.org/), version 2.10.1, MIT and additional component licenses: [full license and component notices](licenses/Sparkle-LICENSE.txt). Sparkle is bundled in the frozen candidate; its updater is disabled.

This inventory is not a completed redistribution audit. Do not distribute the frozen binary until the exact dependency closure, notices, corresponding source and replacement/relinking conditions have been reviewed.
