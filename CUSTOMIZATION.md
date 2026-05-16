# Homebase ffmpeg-kit customizations

This document is the canonical reference for the source-level customizations
this fork applies on top of stock FFmpeg fftools. It is intentionally
evergreen — when the FFmpeg version is bumped, re-apply each item below to
the new fftools snapshot. Update the checkboxes as work progresses.

## Lineage

| Tag | Meaning |
| --- | --- |
| `pre-7.1.3-baseline` | Last working build on FFmpeg n6.0. Safety net. |
| `stock-n7.1.3` | Stock FFmpeg n7.1.3 `fftools/` re-snapshotted into all three platform trees, with the `fftools_` prefix rename and `#include` rewrites applied. **No Homebase customizations yet.** |
| `upgrade/ffmpeg-7.1.3` | Active branch where customizations are being layered on top of `stock-n7.1.3`. |

To see *exactly* what makes our build different from stock FFmpeg, run:

```
git diff stock-n7.1.3..HEAD -- '*/fftools_*.c' '*/fftools_*.h'
```

That diff is the customization set. Everything in it should be documented here.

## Reference patches from the prior n6.0 vendored set

When upgrading FFmpeg, the previous customization set is the best reference:

```
c:/temp/Git/_upgrade_work/patches/<file>.patch
```

These are unified diffs between stock FFmpeg n6.0 fftools and the n6.0-era
vendored copies in this repo. They were extracted from the
`pre-7.1.3-baseline` tag during the n6.0 → n7.1.3 upgrade and are the
authoritative record of what customizations existed historically. ~5,800
lines total, but the load-bearing parts are far smaller (see below).

## Why this fork customizes fftools at all

Stock `ffmpeg` and `ffprobe` are standalone executables — they have a
`main()`, they call `exit()` on failure, they live in their own process.
ffmpeg-kit needs them as **library entry points** callable from JNI / Obj-C
inside a host process (an Android app, an iOS app, the chat-kmp KMP binary).
The customizations exist to make that work safely:

- `main()` becomes a regular function so it can be called from a wrapper.
- `exit()` becomes a `longjmp` so a failure doesn't kill the host process.
- Module globals become thread-local so multiple invocations don't race.
- Optional hooks (stats forwarding, cancellation, log redirection) expose
  FFmpeg's internal state to the wrapper layer.

# Customization set

Each item below is independently portable. Required items must be re-applied
on every FFmpeg version bump or the build will not link. Optional items are
called out per-consumer (chat-kmp's needs are documented inline).

## C1 — Entry-point rename: `main` → `ffmpeg_execute` / `ffprobe_execute`

- [x] Applied to `fftools_ffmpeg.c` (all three platform trees)
- [x] Applied to `fftools_ffprobe.c` (all three platform trees)

**Status: REQUIRED for chat-kmp.** The wrapper layer
(`android/.../cpp/ffmpegkit.c:823`, `android/.../cpp/ffprobekit.c:88`) calls
these symbols directly:

```c
int ffmpeg_execute(int argc, char **argv);
int ffprobe_execute(int argc, char **argv);
```

**What to do.** In `fftools_ffmpeg.c`, locate `int main(int argc, char **argv)`
and rename to `int ffmpeg_execute(int argc, char **argv)`. Same for
`fftools_ffprobe.c` → `ffprobe_execute`. Strip the Windows-only console
wrappers and `prepare_app_arguments` calls if present — they assume an
actual process entry.

**Reference.** `_upgrade_work/patches/ffmpeg.c.patch` line ~95 onward shows
the n6.0 rename. The shape is the same in n7.1.3, but in n7.1.3 `main()` may
delegate more into the scheduler; the rename still applies to the outer
function.

**How to verify.** After re-applying, the symbol `ffmpeg_execute` and
`ffprobe_execute` must resolve at link time when building
`libffmpegkit.{so,dylib}`. Run `nm libffmpegkit.so | grep -E
'ffmpeg_execute|ffprobe_execute'` — both must appear with a `T` (defined).

## C2 — `exit()` → `setjmp`/`longjmp` exit handling

- [x] `exit_program()` defined in `ffmpegkit_exception.{m,c,cpp}` (not in
      `fftools_cmdutils.c` — stock n7.1.3 has no such function to override,
      so we add it alongside `ex_buf__` and `longjmp_value` instead)
- [x] `ffmpegkit_exception.h` extended with `extern __thread int longjmp_value`
      and `void exit_program(int)` prototype, wrapped in `extern "C"` guards
- [x] Matching `setjmp` site in `fftools_ffmpeg.c::ffmpeg_execute`
- [x] Matching `setjmp` site in `fftools_ffprobe.c::ffprobe_execute`
- [x] `ffmpegkit_exception.h` `#include`d at the top of `fftools_ffmpeg.c`
      and `fftools_ffprobe.c` (not needed in `fftools_cmdutils.c` since
      `exit_program` now lives in the exception module)
- [x] All 5 `exit(1)` calls in `fftools_ffprobe.c` replaced with
      `exit_program(1)` so they unwind via longjmp

**Status: REQUIRED for chat-kmp.** Without this, any failed FFmpeg
invocation calls `exit()` and tears down the host KMP / Android / iOS
process. chat-kmp depends on `Session.getReturnCode().isSuccess` reporting
the failure cleanly back to Kotlin.

**What to do.** Replace `void exit_program(int ret)` in `fftools_cmdutils.c`
to set a thread-local `longjmp_value` and `longjmp` to the buffer declared
in `ffmpegkit_exception.h`. In `ffmpeg_execute` / `ffprobe_execute`, wrap
the body in `if (setjmp(...) == 0) { /* normal path */ } else { return
longjmp_value; }`.

**Reference.** `_upgrade_work/patches/cmdutils.c.patch` (~250 lines) — most
of the meaningful patch lives here, plus the setjmp site in
`_upgrade_work/patches/ffmpeg.c.patch`.

**How to verify.** Issue a deliberately broken command (e.g. `ffmpeg -i
/nonexistent /tmp/out.mp4`). The wrapper must return a non-zero
`ReturnCode`, and the host process must keep running.

## C3 — Thread-local module globals

- [ ] `vstats_file`, `received_sigterm`, `received_nb_signals` in
      `fftools_ffmpeg.c` marked `__thread` (or `_Thread_local`)
- [ ] Audit n7.1.3-new files (`fftools_ffmpeg_sched.c`, `fftools_ffmpeg_dec.c`,
      `fftools_ffmpeg_enc.c`) for additional module globals introduced
      by the scheduler refactor and mark them `__thread` if shared

**Status: REQUIRED for safety; OPTIONAL for chat-kmp's current usage.**
chat-kmp serializes FFmpeg calls behind a coroutine and does not invoke
concurrently from multiple threads today, so a non-thread-safe build would
likely work in practice. But the customization is cheap and protects against
future regressions if any caller decides to parallelize transcodes.

**Reference.** `_upgrade_work/patches/ffmpeg.c.patch` around the
`static FILE *vstats_file` declaration.

## C4 — `cancel_operation(long id)`

- [x] **Stubbed.** No-op `void cancel_operation(long id)` added in
      `fftools_ffmpeg.c` (all three trees). Symbol resolves; cancellation
      does not interrupt an in-progress run. chat-kmp handles cancellation
      at the coroutine layer instead.

**Status: SYMBOL REQUIRED; FUNCTIONALITY OPTIONAL for chat-kmp.**

**Minimum viable.** Add the following to `fftools_ffmpeg.c` near the top:

```c
void cancel_operation(long id) {
    (void)id;
    // Homebase chat-kmp does not use ffmpeg-kit's cancel API; cancellation
    // is handled at the coroutine layer instead. Symbol exists to satisfy
    // the wrapper link, but does not interrupt an in-progress invocation.
}
```

**If we ever need real cancellation.** Set a thread-local atomic flag keyed
by session id; in the scheduler main loop in `fftools_ffmpeg_sched.c`, poll
this flag and short-circuit. The n7.1.3 scheduler is new ground — the n6.0
implementation that lived in `ffmpeg.c::transcode_step` does not map
directly. Treat this as new work, not a port.

**Reference.** `_upgrade_work/patches/ffmpeg.c.patch` for the n6.0 logic;
`fftools_ffmpeg_sched.c` for the new n7.1.3 surface.

## C5 — `set_report_callback(...)` + `forward_report()`

- [x] **Stubbed.** `set_report_callback(ffmpeg_report_callback fn)` defined
      in `fftools_ffmpeg.c` with a `__thread`-scoped `report_callback`
      pointer. Set is honoured (pointer is stored) but `forward_report()`
      is **not** wired into `print_report()` — no progress events fire.
      chat-kmp doesn't consume them; if a future consumer does, add the
      dispatch in `print_report()`.

**Status: SYMBOL REQUIRED; FUNCTIONALITY OPTIONAL for chat-kmp.**

**Minimum viable.** Add to `fftools_ffmpeg.c`:

```c
typedef void (*ffmpeg_report_callback)(int, float, float, int64_t, double, double, double);
static __thread ffmpeg_report_callback report_callback = NULL;

void set_report_callback(ffmpeg_report_callback fn) {
    report_callback = fn;
}
```

The wrapper signature is what the prior fork settled on as of 2023-09; if a
future consumer needs progress reporting, also re-introduce the
`forward_report()` call inside `print_report()` to dispatch to the
callback. chat-kmp tracks progress externally (out_time_ms parsing on
desktop) so this is not urgent.

**Reference.** `_upgrade_work/patches/ffmpeg.c.patch` — search for
`forward_report` and `report_callback`.

## C6 — stderr / setvbuf / signal handler hygiene

- [x] Removed `setvbuf(stderr, NULL, _IONBF, 0)` from `ffmpeg_execute()`
- [x] Removed `fflush(stderr)` from `print_report()` in `fftools_ffmpeg.c`
- [ ] Signal handler neutering — deferred. `sigterm_handler()`,
      `sigaction()` setup, and the SIGNAL macro calls in `term_init()`
      still register with the host process. Acceptable for chat-kmp
      because (a) it runs FFmpeg behind a coroutine and doesn't share
      signal state with running transcodes and (b) the n6.0 build had the
      same behaviour. Revisit if Crashlytics / Sentry reports show signal
      collisions in production.

**Status: REQUIRED for safety in any embedded use; chat-kmp currently
tolerates the absence on Android/iOS but the iOS bridge has had log
ordering issues before — strongly recommended.**

**Why.** When ffmpeg is a child of the chat-kmp host process, hijacking
`stderr` and registering signal handlers stomps on the host's own log
plumbing and crash reporter (Crashlytics / Sentry). Removing these calls
keeps the host in control.

**Reference.** Look for `setvbuf` and `signal(SIGTERM, ...)` in the n6.0
patches.

## C7 — `fftools_` `#include` prefix

- [x] **Already applied by the replay script.** `replay.sh` rewrites every
      `#include "header.h"` → `#include "fftools_header.h"` for the set
      of fftools headers.

**Status: ALREADY DONE.** Verify by grepping `git diff stock-n7.1.3..HEAD --
'*/fftools_*.c' | grep '#include "ffmpeg.h"'` — must return empty.

## ~~C9 — `AV_LOG_STDERR` custom log-level sentinel~~

~~Define a private log-level constant for fork-tagged messages.~~

**Removed (see U5).** We deliberately deleted the dead wrapper code
that referenced this constant instead of carrying the define forever.
Kept the struck-through entry as institutional memory: the constant
existed in n6.0 era. If a future consumer needs always-surface log
tagging, re-introduce the define plus the wrapper switch case plus
emit sites in vendored fftools.

## C8 — License + changelog header comment

- [ ] Each customized `fftools_*.c` carries a `Copyright (c) <year>
      Homebase` + a changelog of applied customizations at the top.

**Status: STYLE / ATTRIBUTION.** Not load-bearing for the build, but the
historical convention (and a useful self-documenting record). When applying
any of C1–C6 above to a file, also add a brief changelog entry to its top
comment block. Format follows the n6.0 vendored set:

```
/*
 * Homebase ffmpeg-kit customizations on top of stock FFmpeg n7.1.3
 *
 * <date> — <summary>
 * --------------------------------------------------------
 * - <bullet of what changed and why>
 */
```

# Verification matrix against chat-kmp's actual usage

chat-kmp exercises a narrow slice of ffmpeg-kit. Each row below is a
command pattern it issues; the customizations listed are the ones that must
work for that pattern to succeed end-to-end.

| chat-kmp scenario | Commands issued | Customizations exercised |
| --- | --- | --- |
| Thumbnail extraction | `-i in -frames:v 1 out.png` | C1, C2 |
| Video compression (libx264 fallback) | `-i in -c:v libx264 -b:v 3000k -vf scale='min(1280,iw)':-2 -preset fast out` | C1, C2, C5 (stub), C6 |
| HW-accelerated compression (Android) | `-c:v h264_mediacodec` variant | C1, C2 — relies on Android NDK MediaCodec being linked at FFmpeg build (configure flag, not a customization) |
| HLS segmentation (copy codec) | `-codec:v copy -codec:a copy -hls_time 6 -hls_flags single_file -f hls -hls_segment_filename ...` | C1, C2 |
| HLS encryption (AES-128) | `-hls_key_info_file keyinfo.txt -f hls ...` | C1, C2 — relies on stock HLS muxer support, no customization needed |
| HLS → MP4 remux | `-i index.m3u8 -c copy -bsf:a aac_adtstoasc -movflags +faststart out.mp4` | C1, C2 |
| Rotation probe | `ffprobe -v quiet -select_streams v:0 -show_entries side_data_list=... -of json=compact=1 in.mp4` | C1 (ffprobe path), C2 |
| FFprobe getMediaInformation | `FFprobeKit.getMediaInformation(path)` | C1 (ffprobe path), C2 |

# Suggested work order for the n7.1.3 customization pass

1. **C1 + C2** together — entry-point renames + setjmp/longjmp. This is the
   minimum to get a linkable library. After this, `nm` shows the symbols
   and the wrapper links.
2. **C4 + C5 stubs** — no-op stubs for `cancel_operation` and
   `set_report_callback`. ~10 lines total. Library is now wrappable.
3. **C6** — strip the stderr/signal hygiene issues. Safer for embedded use,
   no risk of regression for chat-kmp since it currently works around
   these issues at the bridge level.
4. **C3** — thread-local globals. Only matters if multiple threads ever
   call FFmpeg concurrently; defer if time is tight.
5. **CI green** on Android arm64-v8a + iOS arm64 sim, run the chat-kmp
   command patterns from the table above against a built artifact, then
   tag `n7.1.3-customized` and pre-release `7.1.0-pre.1`.
6. **chat-kmp integration soak** — swap the local AAR
   `gradle/local-repo/id/homebase/libs/ffmpeg-kit/1.0/` with the new
   build, run the existing chat-kmp test cases (thumbnail, HLS, AES-128
   playlist). If green, promote.

# FFmpeg version-bump fixes (by upgrade event)

When bumping FFmpeg's major version, expect the **build scripts** to need
small patches — FFmpeg removes headers, changes configure-script
behaviour, and tightens clang argument validation between majors. These
are not Homebase customizations (they don't get re-applied to a fresh
ffmpeg-kit checkout); they're one-time fixes that go into the build
scripts and stay there. Future bumps will hit different ones in the
same categories.

**Pre-upgrade checklist** (run before dispatching CI on a fresh bump
— each item maps to a U-entry below; apply proactively to save the
~1-hour-per-fix CI iteration tax):

1. **External library pins (U1).** Bump only `ffmpeg)` in
   `scripts/source.sh`; leave every other library at the n6.0-era
   pin. The `arthenica/*` mirrors stopped getting tag pushes in 2025
   so most speculative bumps will 404. Bump individual libs later,
   one at a time, after verifying the tag exists on the mirror.
2. **Dropped fftools headers (U2 + U4).** Cross-check the header copy
   list in `scripts/<platform>/ffmpeg.sh` (the `overwrite_file`
   block under "MANUALLY ADD REQUIRED HEADERS") against the new
   FFmpeg's source tree. Drop any header that no longer exists; add
   any new fftools `.c` files to the per-platform build files
   (`Android.mk`, `Makefile.am`).
3. **clang `-march` for x86-64 (U3).** Confirm `TARGET_CPU="x86-64"`
   (hyphenated) for the x86-64 block in all three platform
   `ffmpeg.sh`. `TARGET_ARCH` stays underscored.
4. **`AV_LOG_STDERR` (U5).** Should NOT appear in `fftools_ffmpeg.h`
   or any wrapper file. If a fresh wrapper file references it,
   delete the dead code rather than re-introducing the define.
5. **`<string.h>` / `<cstring>` in wrappers (U6).** Verify all
   wrapper sources that call `strlen`/`strcpy`/`memcpy` explicitly
   include the header. Don't rely on transitive includes through
   libav* headers.
6. **`compat/va_copy.h` install (U7).** The build script must `mkdir
   -p .../include/compat` and `overwrite_file ... compat/va_copy.h`
   alongside the `mathops.h` block. Verify it's still there.
7. **Wrapper CFLAGS (U8).** `MY_CFLAGS` in `android/jni/Android.mk`
   must include the full `-Wno-*` set documented in U8 (covers
   `parentheses`, `pointer-sign`, `deprecated-declarations`, the
   `unused-*` family). Stock fftools is warning-heavy; expect to add
   more if a new `-Werror,-W<x>` surfaces.
8. **`--enable-postproc` (U9).** FFmpeg's configure must NOT have
   `--disable-postproc` because stock fftools/ffprobe.c
   unconditionally includes `libpostproc/postprocess.h`. With
   `--enable-gpl` already set, postproc is the default — just ensure
   nothing re-disables it.

## n6.0 → n7.1.3 fixes (2026-05)

These were the build-script patches needed to compile FFmpeg n7.1.3 on
top of the n6.0-era ffmpeg-kit scripts. Each is checked-in and lives in
the build scripts going forward.

### U1 — Don't speculatively bump external library pins

- [x] Lesson learned, applied
- **Symptom:** `INFO: Downloading library <name> failed. Can not get
      library from https://github.com/arthenica/<lib>` during the
      `Downloading sources` phase.
- **Root cause:** arthenica/* mirrors stopped getting tag pushes after
      the upstream project was archived in mid-2025. A speculative
      "bump every lib to latest stable" produces SOURCE_IDs that don't
      exist on any mirror.
- **Fix:** bump only `ffmpeg)` in `scripts/source.sh`; leave every
      other library at the n6.0-era pin. Bump individual libs later,
      one at a time, after verifying the tag exists on the mirror (or
      switching `SOURCE_REPO_URL` to canonical upstream).
- **Commit:** `64a7610`

### U2 — `libavutil/x86/emms.h` was removed in FFmpeg 7

- [x] Fixed
- **Symptom:** `cp: cannot stat 'src/ffmpeg/libavutil/x86/emms.h': No
      such file or directory` at the very end of FFmpeg's build phase,
      after `make install` ran cleanly. Triggers `ffmpeg: failed` and
      no AAR/framework gets emitted.
- **Root cause:** ffmpeg-kit's `scripts/<platform>/ffmpeg.sh` has a
      hardcoded list of internal headers it copies from `src/ffmpeg/`
      into the output `include/` dir. `libavutil/x86/emms.h` (legacy
      MMX EMMS state management) was removed as a public header in
      FFmpeg 7. The `cp` returns non-zero and the `[ $? -eq 0 ]` check
      a few lines later trips.
- **Fix:** drop the `overwrite_file ... emms.h` line from all three
      platform scripts.
- **Commit:** `31d31c4`

### U3 — `TARGET_CPU` for x86-64 must be hyphenated

- [x] Fixed
- **Symptom:** `error: unknown target CPU 'x86_64'` from clang during
      FFmpeg's `./configure` "C compiler works?" check, specifically
      on the x86-64 architecture. The valid-CPU list clang prints
      includes `x86-64` (with hyphen).
- **Root cause:** FFmpeg n7's configure passes `--cpu=$TARGET_CPU`
      straight through to clang as `-march=$TARGET_CPU` without the
      n6.0-era internal remap from `x86_64` → `x86-64`. Modern clang
      (NDK r25+, recent Xcode toolchains) is strict about the hyphen.
- **Fix:** set `TARGET_CPU="x86-64"` (hyphenated) for the x86-64 ABI
      in all three platform scripts. `TARGET_ARCH` stays `x86_64`
      (underscored) — that's FFmpeg's internal arch name and what
      `--arch=` expects.
- **Commit:** `253fe8b`

### U9 — Stock fftools unconditionally `#include`s libpostproc; `--disable-postproc` breaks wrapper compile

- [x] Fixed
- **Symptom:** wrapper compile fails with:
      ```
      fftools_ffprobe.c:66:10: fatal error: 'libpostproc/postprocess.h' file not found
      ```
- **Root cause:** stock FFmpeg `fftools/ffprobe.c` unconditionally
      includes `libpostproc/postprocess.h` and `libpostproc/version.h`
      (used only to print the lib version in the banner). When
      ffmpeg-kit's build passes `--disable-postproc` to FFmpeg's
      configure, the libpostproc public headers are not installed —
      then the wrapper compile that vendors `fftools_ffprobe.c` can't
      resolve the include.
- **Chosen fix:** drop `--disable-postproc` from the FFmpeg configure
      invocation in all three platform `ffmpeg.sh` scripts. libpostproc
      is small (~50 KB), GPL (already opted-in via `--enable-gpl`), and
      stock-FFmpeg's default. chat-kmp doesn't *use* postproc but the
      header needs to exist for the wrapper to build.
- **Why not patch the source:** wrapping the include in `#if
      CONFIG_POSTPROC` would be a customization in vendored fftools,
      wiped each upgrade. Build-script change survives.
- **Commit:** _set on commit_

### U8 — Wrapper CFLAGS need extra `-Wno-*` flags for stock fftools code

- [x] Fixed
- **Symptom:** wrapper compile fails with:
      ```
      fftools_cmdutils.c:149:18: error: using the result of an assignment as a
        condition without parentheses [-Werror,-Wparentheses]
      ```
      Triggered by stock FFmpeg's `while (x = func())` style of
      assignment-in-condition.
- **Root cause:** stock FFmpeg fftools code uses C idioms (assignment
      in `while`/`if` conditions, `char*`/`unsigned char*` mixing,
      calls to libc functions newer NDKs deprecate) that FFmpeg's
      own configure suppresses via its CFLAGS. When we vendor those
      files into ffmpeg-kit's platform trees, they're compiled under
      Android.mk's `MY_CFLAGS` which has `-Wall -Werror` without the
      matching `-Wno-*` overrides. Pretty much guaranteed to surface
      multiple times across upgrades as upstream code drifts.
- **Fix:** extend `MY_CFLAGS` in `android/jni/Android.mk` with the
      `-Wno-*` flags FFmpeg's own build uses to silence its own style.
      Current full set (each added in response to an actual CI
      failure or as obvious neighbours):
      ```
      -Wno-parentheses        # assignment in if/while condition
      -Wno-pointer-sign       # char* / unsigned char* mixing
      -Wno-deprecated-declarations
      -Wno-unused-variable
      -Wno-unused-const-variable
      -Wno-unused-but-set-variable
      -Wno-unused-function
      ```
      `-Wno-unused-parameter` was already there. If a new
      `-Werror,-W<something>` fires in a future build, add the matching
      `-Wno-<something>` here and update this list.
- **Why not patch the source:** parenthesising every assignment-in-
      condition in vendored fftools_cmdutils.c would be a customization
      lost on every upgrade. Adjusting the build's CFLAGS once
      survives forever.
- **Apple/Linux equivalents:** the Apple `Makefile.am` and Linux
      `Makefile.am` derive CFLAGS from autotools — they typically
      inherit `-Wno-*` from FFmpeg's pkg-config output, so the issue
      may not surface there. If it does in a future Apple/Linux CI
      run, add the same flags to those build files.
- **Commit:** _set on commit_

### U7 — `compat/va_copy.h` must be installed into the prebuilt include dir

- [x] Fixed
- **Symptom:** wrapper build past FFmpeg compile, then:
      ```
      fftools_cmdutils.c:33:10: fatal error: 'compat/va_copy.h' file not found
      ```
- **Root cause:** stock FFmpeg `fftools/cmdutils.c` includes
      `"compat/va_copy.h"` — a Windows-MSVC compatibility shim
      (no-op on Android/Apple/Linux). When the file lives inside the
      FFmpeg source tree the relative include resolves fine; when we
      vendor it into ffmpeg-kit's platform trees and compile against
      the *installed* `prebuilt/.../ffmpeg/include/` dir, `compat/`
      isn't there because FFmpeg's `make install` doesn't ship
      internal compat headers.
- **n6.0-era handling:** the fork manually *patched* the
      `#include "compat/va_copy.h"` line out of `fftools_cmdutils.c`.
      That patch was lost when we re-snapshotted fftools from stock.
- **Chosen fix:** install the header instead of re-patching the
      source. Same pattern the build script already uses for
      `libavcodec/mathops.h` and the `libavutil/x86/asm.h` set —
      `mkdir -p .../include/compat` + `overwrite_file ...
      compat/va_copy.h`. Done in all three platform `ffmpeg.sh`.
- **Why install vs patch:** patching `fftools_cmdutils.c` would live
      in the vendored fftools (wiped by `replay.sh` every upgrade).
      Installing the header is a build-script change (survives
      replays). Same "smooth future upgrades" principle as U5.
- **Commit:** _set on commit_

### U6 — Wrapper files missing `<string.h>` / `<cstring>` includes

- [x] Fixed
- **Symptom:** Android build past FFmpeg compile and through to wrapper
      build, then fails with `implicit-function-declaration` errors on
      `strlen` / `strcpy` (under `-Werror`):
      ```
      ffprobekit.c: error: implicitly declaring library function 'strlen'
        with type 'unsigned int (const char *)' [-Werror,-Wimplicit-function-declaration]
      ```
- **Root cause:** wrapper sources call `strlen` / `strcpy` (e.g.
      `argv[0] = av_malloc(strlen(LIB_NAME) + 1); strcpy(argv[0], ...)`)
      but don't `#include <string.h>`. In older toolchains the symbol
      arrived transitively via libavformat or similar; NDK r25+ clang
      tightens implicit-decl enforcement and the build script passes
      `-Werror`. One file (`ffprobekit.c`) failed; `ffmpegkit.c` only
      happened to compile because it transitively pulled in string.h
      through `libavutil/file.h` or `<stdatomic.h>`.
- **Fix:** add the missing include at the top of every wrapper source
      that uses `<string.h>` functions. Done defensively for all
      platforms even though only one platform's CI surfaced it:
  - `android/.../cpp/ffprobekit.c` and `ffmpegkit.c`: `#include <string.h>`
  - `apple/src/FFmpegKitConfig.m`: `#import <string.h>`
  - `linux/src/FFmpegKitConfig.cpp`: `#include <cstring>` (C++)
- **Future-proofing:** if a new wrapper file is added that uses
      `strlen`/`strcpy`/`memcpy`/etc., always include the header
      explicitly. Don't rely on transitive includes through libav*
      headers — those vary across FFmpeg versions.
- **Commit:** _set on commit_

### U5 — `AV_LOG_STDERR` removed; deleted dead wrapper code (not the define)

- [x] Fixed
- **Symptom:** wrapper compile fails with `use of undeclared identifier
      'AV_LOG_STDERR'` in `ffmpegkit.c`, `FFmpegKitConfig.m`,
      `FFmpegKitConfig.cpp` after fftools is replaced with stock n7.
- **Root cause:** `AV_LOG_STDERR` was never a standard FFmpeg
      constant. The n6.0 ffmpeg-kit fork defined it as `-16` in
      `fftools_cmdutils.h` and emitted at that level from
      fork-modified fftools code to tag "always show" messages. When
      we re-snapshot fftools from stock n7, both the define *and* the
      emit sites disappear. The wrapper's `switch` case and
      quiet-filter clause then reference an undefined identifier.
- **Considered fix:** add `#define AV_LOG_STDERR -16` back as a
      customization (former C9). Works, but leaves dead code in the
      wrapper (no caller in our build ever emits at that level) and
      adds a per-upgrade replay burden because the define lives in
      `fftools_ffmpeg.h` (which is wiped each upgrade).
- **Chosen fix:** delete the dead wrapper references instead.
  - `ffmpegkit.c`: drop the `case AV_LOG_STDERR:` arm of
    `avutil_log_get_level_str()`; simplify the quiet-filter to
    `if (level > activeLogLevel) return;` (the AV_LOG_QUIET special
    case was only there to honour the STDERR exception).
  - `FFmpegKitConfig.m` / `FFmpegKitConfig.cpp`: drop the same
    `case AV_LOG_STDERR:` arm.
  - Touched files live OUTSIDE `fftools_*` and so survive future
    replay-script runs.
- **Caveat:** Java-side dead code still references
      `Level.AV_LOG_STDERR(-16)` in `Level.java` /
      `FFmpegKitConfig.java`. Left alone for now — it's not blocking
      and removing `Level.AV_LOG_STDERR` would change the public
      Java enum (binary-incompatible for any downstream Java consumer
      that imports the constant). Revisit when planning a major
      version bump.
- **Why this is the "smooth future upgrades" pick:** the deletion is
      in wrapper files that aren't touched by `replay.sh`; future
      upgrades carry the deletion forward automatically. Zero
      recurring cost.
- **Commit:** _set on commit_

### U4 — fftools/ added 5 new sources

- [x] Fixed during scaffolding (C7)
- **Symptom:** would manifest as `undefined reference to
      sch_run/...`  link errors if the new sources weren't added.
- **Root cause:** n7 split fftools into more files: added
      `ffmpeg_dec.c`, `ffmpeg_enc.c`, `ffmpeg_sched.c/.h`,
      `ffmpeg_utils.h`. The platform build files (`Android.mk`,
      `Makefile.am`) didn't know about them.
- **Fix:** add the 5 new sources/headers to `MY_SRC_FILES`
      (Android.mk) and `libffmpegkit_la_SOURCES` / `include_HEADERS`
      (apple/linux `Makefile.am`).
- **Commit:** `46a0908` (scaffolding)

# Build pipeline TODOs (deferred — address after n7.1.3 is green end-to-end)

These are concerns about the artifacts ffmpeg-kit's build scripts emit,
not about the source-level customizations above. They cause friction for
chat-kmp's iOS build pipeline. Deliberately deferred until we've proved
the n7.1.3 upgrade works (AAR built, chat-kmp Android/JVM tests green).

## B1 — iOS xcframework is code-signed; chat-kmp has to strip signatures

- [ ] Investigate whether `./ios.sh` is invoking a `codesign` step we can
      suppress, or whether the signature is inherited from the Xcode
      toolchain doing implicit signing on framework embedding.
- [ ] If suppressing isn't possible, add a post-build step in `./ios.sh`
      that runs `codesign --remove-signature` across each architecture
      slice in the produced xcframework so chat-kmp can drop its
      signature-strip workaround.

**Why:** chat-kmp currently runs a custom script to strip signatures from
the embedded `ffmpegkit.framework` before its own app signing pass.
That's a workaround for ffmpeg-kit shipping signed binaries — the right
fix lives here.

## B2 — iOS xcframework ships fat (multi-arch) binaries; chat-kmp wants thin

- [ ] Audit how `./ios.sh` packages slices. The xcframework wrapper is
      correct, but each embedded `.framework`'s Mach-O may still be a fat
      binary (e.g., arm64 + x86_64 simulator combined). Apple deprecated
      that model; modern xcframeworks expect one thin slice per
      platform/architecture.
- [ ] Switch the build to emit per-arch thin binaries (separate sim and
      device slices), letting the xcframework wrapper do the
      arch-routing instead of fat Mach-O.

**Why:** chat-kmp's iOS link step trips over the fat binary structure,
forcing another workaround. Thin slices are what Xcode 14+ expects.

**How to apply:** both B1 and B2 are pure build-script changes — no
source customization, no FFmpeg API work. Likely a few flag tweaks in
`./ios.sh` and the apple Makefile.am invocations.

## Verification (after fix)
- B1: produced `ffmpegkit.framework` Mach-O passes `codesign -dv` as
      unsigned.
- B2: `lipo -info <slice>/ffmpegkit.framework/ffmpegkit` reports a
      single architecture per slice.
- chat-kmp can drop its signature-strip script and its fat-binary
  workaround.

# How to update this document

When applying any C-item above, check its checkbox. If a new customization
is added (something not in C1–C8), add a new section in numbered order and
explain why. If a customization is *removed* because its consumer no
longer needs it, mark it `~~struck~~` rather than deleting — future
upgrades will want to know it was once there.

Build pipeline TODOs (B-items) use the same conventions — checkbox per
sub-task, struck-through if dropped, and they go in their own section to
keep them separate from the source-level customizations.
