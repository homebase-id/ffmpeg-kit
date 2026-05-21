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

# Flat fftools .c files (live at $SRC/*.c). Update when FFmpeg adds/removes
# files (cross-check via `ls $SRC/*.c`). ffplay/ffplay_renderer are
# intentionally excluded — ffmpeg-kit doesn't ship a player.
# n7→n8 delta: objpool.c removed (callers refactored to use new APIs).
C_FILES=(
  cmdutils ffmpeg ffmpeg_dec ffmpeg_demux ffmpeg_enc ffmpeg_filter
  ffmpeg_hw ffmpeg_mux ffmpeg_mux_init ffmpeg_opt ffmpeg_sched ffprobe
  opt_common sync_queue thread_queue
)

# Flat fftools .h files. n7→n8 delta: objpool.h removed.
H_FILES=(
  cmdutils ffmpeg ffmpeg_mux ffmpeg_sched ffmpeg_utils fopen_utf8
  opt_common sync_queue thread_queue
)

# n8-era subdirectory fftools .c files. These live at $SRC/<subdir>/*.c
# and get flattened into the vendor tree as fftools_<basename>.c.
# n8 introduced fftools/graph/, fftools/resources/, fftools/textformat/
# when ffprobe was refactored to use a generalized text-format library
# and -print_graphs was added.
SUBDIR_C_FILES=(
  graph/graphprint
  resources/resman
  textformat/avtextformat
  textformat/tf_compact
  textformat/tf_default
  textformat/tf_flat
  textformat/tf_ini
  textformat/tf_json
  textformat/tf_mermaid
  textformat/tf_xml
  textformat/tw_avio
  textformat/tw_buffer
  textformat/tw_stdout
)

# n8-era subdirectory fftools .h files. Same flattening pattern.
SUBDIR_H_FILES=(
  graph/graphprint
  resources/resman
  textformat/avtextformat
  textformat/avtextwriters
  textformat/tf_internal
  textformat/tf_mermaid
)

# Build the union of header basenames whose `#include "<base>.h"` lines
# should be rewritten to `#include "fftools_<base>.h"`.
ALL_H_BASES=( "${H_FILES[@]}" )
for sub in "${SUBDIR_H_FILES[@]}"; do
  ALL_H_BASES+=( "${sub##*/}" )
done

# Build the sed expression (ERE). Order matters: strip path prefixes
# BEFORE applying the `<base>.h` → `fftools_<base>.h` rewrite, otherwise
# the flat-name rule would incorrectly match inside `fftools/<name>.h`
# and produce `fftools/fftools_<name>.h`.
#
# Using `@` as the delimiter so the `|` inside the alternation doesn't
# collide with sed's regex delimiter.
SED_EXPR=""
# 1. Strip fftools/<subdir>/ prefix → keep only basename
SED_EXPR+='s@#include "fftools/(graph|resources|textformat)/([a-zA-Z0-9_]+)\.h"@#include "\2.h"@g;'
# 2. Strip <subdir>/ prefix (no fftools/) → keep only basename
SED_EXPR+='s@#include "(graph|resources|textformat)/([a-zA-Z0-9_]+)\.h"@#include "\2.h"@g;'
# 3. Strip fftools/ prefix for flat headers
SED_EXPR+='s@#include "fftools/([a-zA-Z0-9_]+)\.h"@#include "\1.h"@g;'
# 4. For every header basename we vendor, prefix `#include "<base>.h"`
#    with `fftools_`.
for h in "${ALL_H_BASES[@]}"; do
  SED_EXPR+="s@#include \"${h}\.h\"@#include \"fftools_${h}.h\"@g;"
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
    sed -E -e "$SED_EXPR" "$SRC/$f.c" > "$D/fftools_$f.c"
  done
  for h in "${H_FILES[@]}"; do
    sed -E -e "$SED_EXPR" "$SRC/$h.h" > "$D/fftools_$h.h"
  done
  for sub_f in "${SUBDIR_C_FILES[@]}"; do
    base="${sub_f##*/}"
    sed -E -e "$SED_EXPR" "$SRC/$sub_f.c" > "$D/fftools_$base.c"
  done
  for sub_h in "${SUBDIR_H_FILES[@]}"; do
    base="${sub_h##*/}"
    sed -E -e "$SED_EXPR" "$SRC/$sub_h.h" > "$D/fftools_$base.h"
  done
done

TOTAL=$(( ${#C_FILES[@]} + ${#H_FILES[@]} + ${#SUBDIR_C_FILES[@]} + ${#SUBDIR_H_FILES[@]} ))
echo "Done. Re-snapshotted $TOTAL files into ${#DESTS[@]} platform trees."
echo "Next: re-apply C1, C2, C4, C5, C6, C10 per CUSTOMIZATION.md."
