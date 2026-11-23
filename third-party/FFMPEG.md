# FFmpeg used by the frozen candidate

FFmpeg 9.0.2, LGPL 2.1 or later. The recorded source archive is [ffmpeg-9.0.2.tar.xz](https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz), SHA-256 `8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e`. The local candidate report says the source was unmodified and its hash matched the locally installed Homebrew formula; the upstream signature was not independently verified. The source archive has not yet been hosted with a binary release.

The candidate reported the following configure options. The original build used a temporary installation prefix; select a local prefix when reproducing it.

```text
--disable-everything --disable-autodetect --disable-doc --disable-ffplay --disable-ffprobe --disable-gpl --disable-nonfree --enable-shared --disable-static --enable-ffmpeg --enable-protocol='file,pipe' --enable-demuxer='mov,matroska,mp3,wav,flac,ogg,aac,mpegts,mpeg,avi' --enable-decoder='aac,aac_fixed,mp3,mp3float,pcm_s16le,pcm_s24le,pcm_s32le,pcm_f32le,flac,opus,vorbis,alac,ac3,eac3' --enable-encoder=pcm_s16le --enable-muxer=wav --enable-filter='aresample,anull' --extra-cflags='-mmacosx-version-min=14.0' --extra-ldflags='-mmacosx-version-min=14.0'
```

The binary distribution review is incomplete, including corresponding-source availability and library replacement/relinking. See [FFmpeg's license guidance](https://ffmpeg.org/legal.html) and the included [LGPL text](licenses/FFmpeg-LGPL-2.1.txt).
