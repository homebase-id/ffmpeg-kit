#!/bin/bash
# Re-snapshot stock FFmpeg fftools sources into the three ffmpeg-kit
# platform trees (apple/src, android/.../cpp, linux/src) with the
# `fftools_` filename prefix and matching `#include` rewrites.
#
# This script does NOT re-apply the Homebase customizations (C1, C2,
# C4, C5, C6, C10). Those live INSIDE the fftools sources and are
# wiped here every time. See CUSTOMIZATION.md for the patches to
# replay on top of the fresh sources after running this.
#
# Usage:
#   FFMPEG_SRC=/path/to/extracted/ffmpeg-x.y.z scripts/upgrade/replay.sh
#
# If FFMPEG_SRC is unset, defaults to the n8.1.1 work tree this fork
# was last upgraded against.

set -euo pipefail

FFMPEG_SRC="${FFMPEG_SRC:-/c/temp/Git/_upgrade_work/ffmpeg-n8.1.1/ffmpeg-8.1.1}"
SRC="$FFMPEG_SRC/fftools"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [ ! -d "$SRC" ]; then
  echo "ERROR: fftools source dir not found: $SRC" >&2
  echo "Set FFMPEG_SRC to the extracted FFmpeg release tree." >&2
  exit 1
fi

DESTS=(
  "$REPO/apple/src"
  "$REPO/android/ffmpeg-kit-android-lib/src/main/cpp"
  "$REPO/linux/src"
)

# fftools .c files we vendor. Update when FFmpeg adds/removes files
# (cross-check via `ls $SRC/*.c`). ffplay/ffplay_renderer are
# intentionally excluded — ffmpeg-kit doesn't ship a player.
# n7→n8 delta: objpool.c removed (callers refactored to use new APIs).
C_FILES=(
  cmdutils ffmpeg ffmpeg_dec ffmpeg_demux ffmpeg_enc ffmpeg_filter
  ffmpeg_hw ffmpeg_mux ffmpeg_mux_init ffmpeg_opt ffmpeg_sched ffprobe
  opt_common sync_queue thread_queue
)

# fftools .h files we vendor. Update when FFmpeg adds/removes files.
# n7→n8 delta: objpool.h removed.
H_FILES=(
  cmdutils ffmpeg ffmpeg_mux ffmpeg_sched ffmpeg_utils fopen_utf8
  opt_common sync_queue thread_queue
)

# Build sed expression: rewrite #include "<header>.h" -> #include "fftools_<header>.h"
# for every fftools header.
SED_EXPR=""
for h in "${H_FILES[@]}"; do
  SED_EXPR+="s|#include \"${h}\.h\"|#include \"fftools_${h}.h\"|g;"
done

# Delete old vendored fftools files in each platform tree.
for D in "${DESTS[@]}"; do
  echo "Cleaning $D"
  rm -f "$D"/fftools_*.c "$D"/fftools_*.h
done

# Copy fresh sources into each tree with fftools_ prefix and include rewrites.
for D in "${DESTS[@]}"; do
  echo "Populating $D"
  for f in "${C_FILES[@]}"; do
    sed -e "$SED_EXPR" "$SRC/$f.c" > "$D/fftools_$f.c"
  done
  for h in "${H_FILES[@]}"; do
    sed -e "$SED_EXPR" "$SRC/$h.h" > "$D/fftools_$h.h"
  done
done

echo "Done. Re-snapshotted $(( ${#C_FILES[@]} + ${#H_FILES[@]} )) files into ${#DESTS[@]} platform trees."
echo "Next: re-apply C1, C2, C4, C5, C6, C10 per CUSTOMIZATION.md."
