# Homebase ffmpeg-kit customizations

This document is the canonical reference for the source-level customizations
this fork applies on top of stock FFmpeg fftools. It is intentionally
evergreen — when the FFmpeg version is bumped, re-apply each item below to
the new fftools snapshot. Update the checkboxes as work progresses.

## Current state snapshot (for next major bump)

**Branch:** `upgrade/ffmpeg-8.x` at commit `87e9e41`
(`fix: reset global state between ffmpeg_execute() calls — C11`).

**Tags relevant to this upgrade event:**
- `pre-8.x-baseline` → `3f09956` — revert anchor on
  `upgrade/ffmpeg-7.1.3`. If n8.x ever needs to be abandoned, branch
  off this tag.
- `stock-n8.1.1` → `fcd4c0a` — n8.1.1 fftools sources after
  `replay.sh` re-snapshot but BEFORE any Homebase customizations.
  Reference baseline for
  `git diff stock-n8.1.1..HEAD -- '*/fftools_*'`.
- `n8.1.1-customized` → `87e9e41` — first commit producing green
  CI on both platforms AND **all 5 chat-kmp Android instrumented
  tests passing** (5/5 completed, 0 failed). C11 fixed the
  pre-existing re-entry crash that affected n7.1.3 and n6.0 too —
  n8.1.1 now performs better than the prior baselines.
  **Use this as the revert anchor before any n9.x effort.**

**Working artifacts (Android validated 5/5, iOS pending colleague handoff):**
- Android AAR: `c:/temp/Git/_upgrade_work/run48_aar/ffmpeg-kit-aar/ffmpeg-kit.aar`
  (72 MB, all .so files in all 4 ABIs verified 16 KB-aligned, NDK r27d).
  Workflow run #48 (id `26081869670`). Contains the binder no-op stub +
  C11 re-entry cleanup.
- iOS xcframework: `c:/temp/Git/_upgrade_work/run45_xcframework/`
  (85 MB, thin unsigned arm64 device slice — B1+B2 verified).
  Workflow run #45 (id `26060208346`). ~10 MB lighter than n7.1.3 —
  libpostproc removal accounts for most of the drop. **NOTE:** the
  xcframework predates the binder no-op stub, but iOS doesn't compile
  ffmpegkit_binder.c (Android-only), so it's unaffected.

**Acceptance criteria for declaring n8.1.1 "done":**
1. ✅ chat-kmp `CompressVideoAndroidInstrumentedTest` — all 5 tests
   pass in a single suite run (no isolation needed) on the 16KB-page
   emulator. **MET as of `87e9e41`.**
2. ⏳ iOS xcframework drops into chat-kmp without needing the
   `codesign --remove-signature` or `lipo -thin` workflow steps —
   awaiting macOS colleague soak.
3. ⏳ chat-kmp HLS scenarios green on iOS — same colleague.

**Recovery commands if n8.1.1 needs to be abandoned:**
```
git checkout upgrade/ffmpeg-7.1.3
git reset --hard pre-8.x-baseline
# or to branch fresh:
git checkout -b upgrade/ffmpeg-7.1.3-hotfix pre-8.x-baseline
```

**Things deliberately deferred to a separate effort:**
- **B3 — size trim** via `--disable-everything` + per-feature enables.
  Documented; not started. Estimated 25–35 MB AAR (3× shrink). Even
  more attractive now that we have n8's larger fftools surface area
  (textformat + graph + resources subtrees added).
- **Linux/macOS/tvOS build-script validation.** `*-build-scripts.yml`
  workflows currently only auto-fire on push to `main`. Add
  `workflow_dispatch:` and validate before merge.
- **Real `print_filtergraphs` support.** Currently stubbed via empty
  `ff_graph_{html,css}_{data,len}` (U23). chat-kmp doesn't use
  `-print_graphs`. If a future consumer needs it, replace the stubs
  with real gzipped resource bytes via FFmpeg's
  `fftools/resources/Makefile` pipeline (or vendor the .o files).

## Notes for n8.x → n9.x upgrade

**What carries forward unchanged:**
- C1–C10 source customizations (the entry-point rename, setjmp/longjmp,
  thread-local globals, etc.). The *pattern* survives any FFmpeg
  refactor even if specific anchors shift line numbers.
- U1–U19 build-script fixes (NDK r27, clang 18, lib disables, header
  installs). None are FFmpeg-version-specific.
- U20–U25 (n8 fixes): libpostproc removal, binder install, vendoring
  textformat/graph/resources, resman stubs, zlib link. These are
  baseline now.
- B1, B2 (no signatures, thin device frameworks). Baseline build
  behaviour.
- `scripts/upgrade/replay.sh` is now the authoritative
  source-snapshot script. It handles flat fftools/ + subdir
  fftools/(graph|resources|textformat)/ files with `fftools_`
  flattening. Update the C_FILES / H_FILES / SUBDIR_C_FILES /
  SUBDIR_H_FILES arrays when n9's fftools adds or removes files.

**What will likely change in n9.x (educated guesses):**
- More fftools file moves — n8 already moved a lot. The replay.sh
  subdir handling is robust; just update the arrays.
- More API removals (e.g. AVCodecContext deprecated fields finally
  delete). `-Wno-deprecated-declarations` is already in U8's set.
- arthenica/* external library mirrors continue to age. U1 applies
  more strongly each cycle.
- One more wave of stuff like libpostproc moving out of mainline.
  Audit FFmpeg release notes for "removed from mainline" or "split
  into separate repo" annotations.

**Suggested approach for the next bump:**
1. **Validate n8.1.1 first.** Meet the acceptance criteria above
   (chat-kmp Android + iOS soak). Don't paper over a broken n8.1.1
   with an n9.x version bump.
2. Branch off `upgrade/ffmpeg-8.x` → `upgrade/ffmpeg-9.x` (after
   tagging `pre-9.x-baseline` at the post-validation commit).
3. Download n9.x source, list-diff `fftools/` files vs n8.1.1:
   ```
   diff <(ls _upgrade_work/ffmpeg-n8.1.1/ffmpeg-8.1.1/fftools/*.{c,h} \
            | xargs -n1 basename | sort) \
        <(ls _upgrade_work/ffmpeg-n9.x.y/ffmpeg-9.x.y/fftools/*.{c,h} \
            | xargs -n1 basename | sort)
   diff <(find _upgrade_work/ffmpeg-n8.1.1/ffmpeg-8.1.1/fftools \
              -mindepth 2 -name '*.[ch]' | xargs -n1 basename | sort) \
        <(find _upgrade_work/ffmpeg-n9.x.y/ffmpeg-9.x.y/fftools \
              -mindepth 2 -name '*.[ch]' | xargs -n1 basename | sort)
   ```
4. Update the file arrays in `scripts/upgrade/replay.sh`.
5. Update the `ffmpeg)` `SOURCE_ID` in `scripts/source.sh` (and
   pre-check the arthenica mirror has the tag).
6. Walk the pre-upgrade checklist proactively before running CI.
7. Run `FFMPEG_SRC=/path/to/n9.x scripts/upgrade/replay.sh`.
8. Re-apply C1/C2/C4/C5/C6/C10 to the freshly replayed files. Use
   `git diff stock-n8.1.1..n8.1.1-customized -- '*/fftools_*'` as
   the exact diff template.
9. Update build files (Android.mk MY_SRC_FILES, Makefile.am × 2)
   if files were added/removed.
10. Single full validation pass on n9.x.

## Lineage

| Tag / Branch | Meaning |
| --- | --- |
| `pre-7.1.3-baseline` | Last working build on FFmpeg n6.0. Original safety net. |
| `stock-n7.1.3` | Stock n7.1.3 fftools re-snapshotted with `fftools_` prefix. No customizations yet. |
| `n7.1.3-customized` → `68a62b8` | Last n7 commit producing a green AAR (run #35, pre-B1/B2). |
| `pre-8.x-baseline` → `3f09956` | All n7.1.3 work + B1/B2 + handoff docs. Revert anchor if n8.x ever needs to be abandoned. |
| `upgrade/ffmpeg-7.1.3` | The n7 branch; still around for future hotfixes. |
| `stock-n8.1.1` → `fcd4c0a` | Stock n8.1.1 fftools re-snapshotted (incl. graph/, resources/, textformat/ subdirs flattened with `fftools_` prefix). No customizations yet. |
| `n8.1.1-customized` → `cc8d56e` | First commit producing green CI on both platforms for n8.1.1. **Pre-9.x revert anchor.** |
| `upgrade/ffmpeg-8.x` | Active branch carrying all the above. Not yet merged to `main`. |

To see *exactly* what makes our build different from stock FFmpeg, run:

```
git diff stock-n8.1.1..HEAD -- '*/fftools_*.c' '*/fftools_*.h'
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

## C10 — Resolve duplicate symbols between linked-together ffmpeg + ffprobe

- [x] `program_name` / `program_birth_year` made mutable `__thread`
      globals defined in `fftools_cmdutils.c`, declared in
      `fftools_cmdutils.h`, set per-tool at the top of
      `ffmpeg_execute()` and `ffprobe_execute()`.
- [x] `show_help_default` renamed to `show_help_default_ffprobe` in
      `fftools_ffprobe.c`.

**Status: REQUIRED.** Without this, the wrapper link fails with:

```
ld: error: duplicate symbol: program_name
ld: error: duplicate symbol: program_birth_year
ld: error: duplicate symbol: show_help_default
```

**Root cause.** Stock FFmpeg builds `ffmpeg` and `ffprobe` as two
separate executables. Each `.c` file independently defines
`const char program_name[]` (one `"ffmpeg"`, one `"ffprobe"`),
`const int program_birth_year` (2000 vs 2007), and a tool-specific
`show_help_default()`. ffmpeg-kit links **both** into a single
`libffmpegkit.so` — the linker sees three pairs of conflicting
definitions and bails.

**The accepted pattern (inherited from the n6.0 fork).** Convert the
two `const` globals into mutable thread-locals defined once in
`fftools_cmdutils.c`:

```c
__thread char *program_name = NULL;
__thread int program_birth_year = 0;
```

Change the header declarations accordingly:

```c
extern __thread char *program_name;
extern __thread int program_birth_year;
```

Each `*_execute()` entry sets its own values:

```c
/* in ffmpeg_execute() */
static char _program_name[] = "ffmpeg";
program_name = _program_name;
program_birth_year = 2000;
```

(`static` storage so the array outlives the function call — safe for
serial use; thread-local pointer keeps multi-thread invocations
distinct.) Rename ffprobe's `show_help_default` → `show_help_default_ffprobe`
so it no longer collides with the ffmpeg version. The shared
`fftools_opt_common.c::show_help()` falls through to ffmpeg's version
(chat-kmp doesn't exercise `ffprobe -h`; if a future consumer needs
real ffprobe help, route `-h` through the ffprobe options table to
the renamed function).

**Why this lives in fftools (gets re-applied each upgrade).** The
definitions and the `extern` declarations have to be in
`fftools_cmdutils.{c,h}` because cmdutils is what every fftools file
includes; we can't move them to a fork-local header without also
patching every fftools source to use the new include path. The
runtime assignment in `*_execute()` also has to live in the renamed
fftools sources. Result: this customization is wiped by `replay.sh`
on every upgrade. The diff is small (~6 hunks) but mechanical.

**Reference n6.0 baseline** is the authoritative example. Run:

```
git diff pre-7.1.3-baseline HEAD -- '*/fftools_cmdutils.h' \
                                    '*/fftools_cmdutils.c' \
                                    '*/fftools_ffmpeg.c'   \
                                    '*/fftools_ffprobe.c'  | grep -E 'program_name|program_birth_year|show_help_default'
```

to see the exact diff to replay.

## C11 — Reset global state between `ffmpeg_execute()` invocations

- [x] `ffmpeg_var_cleanup()` function added in `fftools_ffmpeg.c`,
      called at the top of `ffmpeg_execute()` immediately after the C2
      setjmp.

**Status: REQUIRED for chat-kmp.** Without this, the SECOND `ffmpeg_execute()`
invocation in the same process SIGSEGVs inside `of_open()` at +1339,
because the n8 `ffmpeg_cleanup()` frees the global pointer arrays via
`av_freep()` (NULLing the pointer) but does NOT reset the counter ints
(`nb_input_files`, `nb_output_files`, `nb_filtergraphs`, `nb_decoders`).
The next invocation iterates `for (i = 0; i < nb_input_files; i++)
input_files[i]...` → NULL deref.

This was the **same crash that affected n7.1.3 and n6.0**; we missed
carrying the n6-era `ffmpeg_var_cleanup()` forward through the n6→n7
upgrade. The chat-kmp `CompressVideoAndroidInstrumentedTest` docstring
(lines 102-113) documented the symptom as "FFmpegKit's documented
re-entry limitation when libx264 is invoked multiple times in the same
process" — and added a workaround note suggesting one-test-at-a-time
runs. C11 makes that workaround unnecessary; all 5 baseline tests
now pass back-to-back.

**What to do.** Define a static helper at the bottom of
`fftools_ffmpeg.c` (just above `ffmpeg_execute`) that resets the
n8-era surviving globals:

```c
static void ffmpeg_var_cleanup(void)
{
    received_sigterm     = 0;
    received_nb_signals  = 0;
    atomic_store(&transcode_init_done, 0);

    ffmpeg_exited     = 0;
    copy_ts_first_pts = AV_NOPTS_VALUE;
    longjmp_value     = 0;

    atomic_store(&nb_output_dumped, 0);
    progress_avio = NULL;

    input_files      = NULL;
    nb_input_files   = 0;
    output_files     = NULL;
    nb_output_files  = 0;
    filtergraphs     = NULL;
    nb_filtergraphs  = 0;
    decoders         = NULL;
    nb_decoders      = 0;

    vstats_file = NULL;
}
```

Call `ffmpeg_var_cleanup()` right after the C2 setjmp block in
`ffmpeg_execute()`, BEFORE C10's `program_name` assignment.

The n6-era version reset ~10 more globals (`qp_histogram`,
`decode_error_stat`, `nb_frames_dup`, `first_report`, `last_time`,
`want_sdp`, `keyboard_last_time`, etc.) — n7/n8 moved all of those
into the scheduler / `OutputFile` / `Statistics` structs, where they
are owned by per-invocation allocations and freed on cleanup. Don't
re-add resets for names that no longer exist; verify each n6 var
still exists in n9.x before keeping it in C11.

**Reference.** `_upgrade_work/patches/ffmpeg.c.patch` around the
`ffmpeg_var_cleanup` definition (line ~774).

**Validation.** Run the full
`CompressVideoAndroidInstrumentedTest` class without method
filtering. All 5 tests must complete in one process without
native crash:

```
./gradlew :homebase-api:connectedAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=id.homebase.api.video.CompressVideoAndroidInstrumentedTest
# Expected: "Tests 5/5 completed. (0 skipped) (0 failed)"
```

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
8. **`--enable-postproc` AND link `libpostproc` (U9).** FFmpeg's
   configure must NOT have `--disable-postproc` (stock
   fftools/ffprobe.c unconditionally includes
   `libpostproc/postprocess.h` and calls `postproc_version()`).
   With `--enable-gpl` already set, postproc is the default — just
   ensure nothing re-disables it. **AND** the wrapper must link
   against libpostproc in five places: Android `jni/ffmpeg/Android.mk`
   + `jni/ffmpeg/neon/Android.mk` + `jni/Android.mk` (twice), plus
   `apple/configure.ac` (`FFMPEG_FRAMEWORKS`) and
   `linux/configure.ac` (`FFMPEG_LIBS`).
9. **`<stdbit.h>` shim install (U10).** The build script must
   install FFmpeg's `compat/stdbit/stdbit.h` shim to
   `prebuilt/.../include/stdbit.h` so the wrapper compile can resolve
   the C23 `<stdbit.h>` include that stock fftools_ffmpeg_dec.c uses.
   Required for pre-C23 toolchains (NDK r25b ships clang 14).
   Verify it's in the header-install block of all three
   `<platform>/ffmpeg.sh`.
10. **Duplicate-symbol resolution (C10 — yes, a customization not a
    U-fix).** Stock ffmpeg.c and ffprobe.c each define `program_name`,
    `program_birth_year`, and `show_help_default`. Linking both into
    one `.so` collides. Apply C10's diff to the four fftools files
    (`cmdutils.h`, `cmdutils.c`, `ffmpeg.c`, `ffprobe.c`) on every
    upgrade — it's the only customization that lives inside fftools
    and so is wiped by `replay.sh` each cycle. The C10 section below
    has the exact text to apply; the n6.0 baseline tag is the
    authoritative reference.
11. **NDK r27+ for 16 KB page alignment (U12).** `build-android.yml`
    and `periodic-builds-android.yml` matrices must pin `r27d-linux`
    or newer. Older NDKs produce `.so` files with 4 KB-aligned LOAD
    segments which Android 15+ on 16 KB-page devices refuses to load.
    Google Play requires this for app updates as of Nov 1, 2025.
12. **libpostproc gone (U20).** Don't try to link `libpostproc` /
    `-framework libpostproc` / `libpostproc_neon` anywhere. FFmpeg 8
    removed it from mainline (lives separately at
    `michaelni/libpostproc`). If a future FFmpeg version restores it,
    revisit U20.
13. **MediaCodec binder + new fftools subdirs (U21, U22, U24).**
    For Android: install `compat/android/binder.h` and compile
    `compat/android/binder.c` (as `ffmpegkit_binder.c`) into the
    wrapper. For all platforms: vendor the
    `fftools/{graph,resources,textformat}/` subdirs via
    `scripts/upgrade/replay.sh`'s SUBDIR_* arrays.
14. **resman resource stubs + zlib link (U23, U25).** Without
    FFmpeg's `fftools/resources/Makefile` bin2c pipeline, the
    `ff_graph_{html,css}_{data,len}` symbols are undefined. Stub
    them via `ffmpegkit_resources.c`. Also link `-lz` on Apple
    (resman.c calls `inflate*`).

## n7.1.3 → n8.1.1 fixes (2026-05)

These were the build-script patches needed to compile FFmpeg n8.1.1
on top of the n7.1.3-era ffmpeg-kit scripts. Each is checked-in and
lives in the build scripts going forward.

### U20 — libpostproc removed from FFmpeg 8

- [x] Fixed
- **Symptom (Android run #38):** ndk-build of wrapper failed with
      `Android NDK: ERROR:jni/ffmpeg/neon/Android.mk:postproc_neon:
      LOCAL_SRC_FILES points to a missing file`. All FFmpeg + ext libs
      built OK; only the wrapper link tripped on the missing
      `libpostproc_neon.so` artifact.
- **Root cause:** FFmpeg 8.0 removed libpostproc from mainline. It
      now lives separately at `michaelni/libpostproc` (or as a
      sourceplugin branch). FFmpeg's configure/make no longer emits
      `libpostproc.so` of any flavour. Our U9 follow-up (link
      libpostproc in 5 places) hard-references the artifact that no
      longer exists.
- **Fix:** undo the U9 link wiring in 6 places:
      * `android/jni/Android.mk` — drop `libpostproc` and
        `libpostproc_neon` from both LOCAL_SHARED_LIBRARIES lines.
      * `android/jni/ffmpeg/Android.mk` — drop the libpostproc
        module block.
      * `android/jni/ffmpeg/neon/Android.mk` — drop libpostproc_neon
        block.
      * `scripts/apple/ffmpeg.sh` — drop
        `create_temporary_framework "libpostproc"`.
      * `apple/configure.ac` — drop `-framework libpostproc` from
        FFMPEG_FRAMEWORKS.
      * `linux/configure.ac` — drop `-lpostproc` from FFMPEG_LIBS.
- **Wrapper source side:** n8's `fftools/ffprobe.c` no longer
      `#include`s `libpostproc/postprocess.h` or calls
      `postproc_version()` (the entire conditional-postproc dance
      from U9 is gone in stock n8). `replay.sh` pulls in the clean
      version automatically.
- **Commit:** `6516c4c`

### U21 — n8 added `compat/android/binder.h` include to fftools/ffmpeg.c

- [x] Fixed
- **Symptom (Android run #39):**
      `jni/.../fftools_ffmpeg.c:82:10: fatal error:
      'compat/android/binder.h' file not found`
- **Root cause:** n8's `fftools/ffmpeg.c` added a `CONFIG_MEDIACODEC`-
      guarded `#include "compat/android/binder.h"` for Android hardware
      decoder threadpool initialization. The header lives in FFmpeg's
      `compat/` tree which `make install` doesn't ship — only its own
      build sees it via `-I` includes.
- **Fix:** add an `overwrite_file` line to
      `scripts/android/ffmpeg.sh` that installs the header to
      `${FFMPEG_LIBRARY_PATH}/include/compat/android/binder.h`,
      alongside the existing `compat/va_copy.h` install pattern. Also
      `mkdir -p compat/android` in the install tree.
- **iOS/Linux:** unaffected. No `CONFIG_MEDIACODEC` outside Android;
      iOS uses VideoToolbox.
- **Commit:** `d59839c`

### U22 — n8 added fftools subdirs (graph, resources, textformat)

- [x] Fixed
- **Symptom (Android run #40):**
      `fatal error: 'graph/graphprint.h' file not found`. Behind
      that, also `textformat/avtextformat.h` and `resources/resman.h`
      missing from the wrapper compile.
- **Root cause:** n8 introduced three new `fftools/` subdirectories
      when ffprobe was refactored to use a generalized text-format
      library (`AVTextFormatter` replaces n7's `Writer`) and
      `-print_graphs` was added:
      * `fftools/graph/` — print_filtergraphs() implementation.
      * `fftools/resources/` — resman (resource manager).
      * `fftools/textformat/` — generalized formatter library
        (compact/default/flat/ini/json/mermaid/xml + writers).
      n7's `replay.sh` only vendored flat `fftools/*.c` files; the
      subdir files weren't being snapshotted into our platform trees,
      so includes and symbols were missing.
- **Fix:** extend `scripts/upgrade/replay.sh` with `SUBDIR_C_FILES`
      and `SUBDIR_H_FILES` arrays. Files get flattened into the
      vendor tree as `fftools_<basename>.{c,h}` (same `fftools_`
      prefix as flat files). The sed expression now also strips the
      `fftools/`, `graph/`, `resources/`, `textformat/`,
      `fftools/graph/`, etc. prefixes from `#include` lines. Switched
      to ERE mode (`sed -E`) with `@` as delimiter because the BRE
      `\|` alternation we tried first didn't actually match anything.
- **Build files:** add the 13 new `fftools_*.c` to
      `android/jni/Android.mk` `MY_SRC_FILES`, and to
      `apple/src/Makefile.am` + `linux/src/Makefile.am`
      `libffmpegkit_la_SOURCES`. Also add the 6 new `.h` to the
      `include_HEADERS` lists.
- **Why we couldn't just drop graphprint and friends:** n8's
      `ffprobe.c` uses `AVTextFormatter` types directly in its main
      function — it's not optional. textformat is load-bearing now.
- **Commit:** `446f5bf`

### U23 — resman references ff_graph_* externs that ndk-build can't produce

- [x] Fixed
- **Symptom (Android run #41, iOS run #44):** wrapper link fails
      with undefined `ff_graph_html_data`, `ff_graph_html_len`,
      `ff_graph_css_data`, `ff_graph_css_len`.
- **Root cause:** `fftools/resources/resman.c` references these as
      `extern const`s. FFmpeg's `fftools/resources/Makefile`
      gzip-embeds the raw `graph.html` / `graph.css` files into
      object files via bin2c-style tooling and emits them as
      `graph.html.o` / `graph.css.o`. Our ndk-build / autotools
      wrapper build doesn't run that Makefile, so the symbols are
      never defined.
- **Fix:** new wrapper source `ffmpegkit_resources.c` (in both
      `android/.../cpp/` and `apple/src/`) that defines all four
      symbols as empty stubs (`const unsigned char foo[] = { 0 };`).
      Register in Android.mk `MY_SRC_FILES` and apple's
      `libffmpegkit_la_SOURCES`. Linux similar if/when it gets the
      same treatment.
- **Runtime impact:** zero for chat-kmp. The resman code path is
      only exercised by `-print_graphs` (filter graph mermaid
      visualisation). chat-kmp never invokes it. If a future consumer
      needs real graph rendering, replace the stubs with real
      gzipped bytes or wire FFmpeg's resources/Makefile into the
      build.
- **Commits:** `8428c70` (Android) + `cc8d56e` (Apple)

### U24 — compat/android/binder.c not compiled into wrapper (then stubbed)

- [x] Fixed (with a runtime-behavior follow-up — see below)
- **Symptom (Android run #41):** link fails with undefined
      `android_binder_threadpool_init_if_required`.
- **Root cause:** the function is defined in
      `compat/android/binder.c` (sibling to the binder.h we
      installed in U21). The wrapper build needs the .c too, not
      just the header. n7 didn't have any code in this file.
- **Initial fix:** copy `compat/android/binder.c` into the wrapper
      cpp dir as `ffmpegkit_binder.c`, add to `MY_SRC_FILES`. The
      file is `__ANDROID__`-guarded internally. Sibling
      `#include "binder.h"` rewritten to `"compat/android/binder.h"`
      (the U21-installed copy).
- **Follow-up — replace with no-op stub.** The upstream
      implementation SIGABRTs deep inside
      `ABinderProcess_startThreadPool()` when called from chat-kmp's
      instrumented test process on a stock x86_64 Android 36
      emulator — likely because instrumented test hosts aren't
      proper binder clients. The crash happens **before** any actual
      ffmpeg work, killing even the baseline libx264
      software-encoding test that PASSED on n7.1.3 (n7 had no
      binder init at all). Tombstone:
      ```
      F libc    : Fatal signal 6 (SIGABRT) ... tid (pool-3-thread-1)
      F DEBUG   : #06 libffmpegkit.so (android_binder_threadpool_init_if_required+220)
      F DEBUG   : #07 libffmpegkit.so (ffmpeg_execute+351)
      ```
      Replaced `ffmpegkit_binder.c` with a no-op stub:
      `android_binder_threadpool_init_if_required` just logs and
      returns. chat-kmp uses libx264/aac (software) for baseline
      tests; HW MediaCodec (`-c:v h264_mediacodec`) may not work on
      Android 15+ devices without the real init. Revisit if/when HW
      decode is needed.
- **Maintenance note:** `ffmpegkit_binder.c` is now a Homebase
      customization (no-op replacement), NOT vendored from FFmpeg.
      `replay.sh` doesn't touch it. **Do not** blindly re-copy from
      upstream `compat/android/binder.c` on the next FFmpeg bump —
      that would re-introduce the crash. If a future cycle needs HW
      MediaCodec on Android 15+, gate the real init on actual
      MediaCodec usage rather than dropping the no-op.
- **Commits:** `8428c70` (initial copy) + `0dd16d7` (include path)
      + `b35acba` (no-op stub) + `630e790` (`<stddef.h>` for NULL).

### U25 — Apple wrapper missing zlib link

- [x] Fixed
- **Symptom (iOS run #44):** link fails with undefined `_inflate`,
      `_inflateEnd`, `_inflateInit2_`.
- **Root cause:** `fftools/resources/resman.c` calls zlib `inflate*`
      to decompress the gzipped embedded resources. The empty stubs
      from U23 satisfy the *data* references but resman still
      compiles the inflate calls — they're reachable at link time
      even though they'll never execute at runtime (empty stub data
      means resman early-exits before reaching the calls). iOS
      doesn't auto-link zlib from system frameworks the way Android
      does.
- **Fix:** add `-lz` to `FFMPEG_FRAMEWORKS` in `apple/configure.ac`.
      System zlib (`libz.tbd`) is always present on iOS/macOS.
- **Android:** zlib already gets pulled in transitively through one
      of the other libs (ext libs that depend on z). No extra wiring
      needed.
- **Linux:** same fix likely needed if/when Linux build is validated.
- **Commit:** `cc8d56e`

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
- **Fix:** set `TARGET_CPU="x86-64"` (hyphenated) for **every**
      x86-related ABI in all three platform scripts. `TARGET_ARCH`
      stays `x86_64` (underscored) — that's FFmpeg's internal arch
      name and what `--arch=` expects. **Don't miss the
      `x86-64-mac-catalyst` block in `apple/ffmpeg.sh`** — it's a
      separate `case` arm and bit me on iOS run #23 after I'd fixed
      the plain `x86-64)` arm.
- **Commit:** `253fe8b`

### U19 — NDK r27 dropped the implicit `c++_shared` ndk-build module

- [x] Fixed
- **Symptom:** Android run #33 — every library + FFmpeg compiled
      green; failed at the wrapper (`ffmpeg-kit: failed`) with:
      ```
      Android NDK: Module ffmpegkit_armv7a_neon depends on undefined
        modules: c++_shared
      *** Android NDK: Note that old versions of ndk-build silently
        ignored this error case. ... Stop.
      ```
- **Root cause:** `android/jni/Android.mk` had two blocks like:
      ```
      ifeq ($(APP_STL), c++_shared)
          LOCAL_SHARED_LIBRARIES += c++_shared  # ...for packaging
      endif
      ```
      Older NDKs exposed `c++_shared` as a referenceable ndk-build
      module. NDK r27 removed this convention because the C++ runtime
      now packages automatically when `Application.mk` sets `APP_STL
      := c++_shared` (which our generated Application.mk does).
- **Fix:** remove the two `c++_shared` lines from Android.mk. The
      runtime still gets bundled in the AAR via the APP_STL
      declaration.
- **Validation:** after the build completes, verify the AAR still
      contains `jni/<abi>/libc++_shared.so` for each ABI. If missing,
      the implicit-packaging hypothesis is wrong and we'd need to
      add the lib via a different mechanism (`APP_STL := c++_shared`
      is already there; if not enough, fall back to `LOCAL_LDLIBS`
      with explicit path).
- **Commit:** _set on commit_

### U18 — NDK r27 ships host libxml2.so; collides with cross-compiled — disable libxml2

- [x] Fixed
- **Symptom:** Android run #30 (NDK r27d, all libs OK including
      gnutls/libuuid/etc.) hit a FFmpeg link failure at
      configure-time:
      ```
      ld.lld: error: /home/runner/work/ffmpeg-kit/ffmpeg-kit/.ndk/
        android-ndk-r27d/toolchains/llvm/prebuilt/linux-x86_64/lib/
        libxml2.so is incompatible with armelf_linux_eabi
      clang: error: linker command failed with exit code 1
      ```
- **Root cause:** NDK r27d started shipping a `libxml2.so` in its
      own toolchain `lib/` directory (host x86_64, used by clang
      internals). That path is on the default library search list of
      the bundled clang. When FFmpeg's configure runs `test_ld -lxml2`
      to detect libxml2, the linker grabs the **host** copy before the
      cross-compiled one we built earlier, then fails because
      x86_64 is incompatible with arm32. Earlier NDK versions
      (r25b/r26) didn't ship libxml2 in their toolchain.
- **First attempt (rejected):** add `--disable-lib-libxml2`. This
      caused the build to **hang indefinitely** for reasons we
      couldn't diagnose without live logs — possibly an FFmpeg
      configure auto-detect loop, possibly some pkg-config retry
      stuck on the missing lib. Two consecutive runs (#31, #32)
      hung past 4 h on `run the build script` and had to be
      cancelled. Reverted.
- **Chosen fix:** remove the offending NDK host file in the
      workflow's *NDK setup* step, BEFORE the build script runs:
      ```yaml
      rm -f "$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/lib/libxml2.so" \
            "$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/lib/libxml2.so."*
      ```
      With the host copy gone, the linker only finds the
      cross-compiled libxml2 we built ourselves, and the link probe
      succeeds. libxml2 stays enabled in the build.
- **Why this approach:** clang doesn't need libxml2 in its toolchain
      lib dir for cross-compile — that file ships for some
      host-side functionality (maybe `-fembed-bitcode` or some
      compilation database integration). Removing it has no effect
      on cross-compilation, and only one effect on host-side
      tooling (which we don't use).
- **Apple:** not affected (uses Xcode toolchain, not NDK).
- **Commit:** _set on commit_

### U17 — libvpx 1.13.0 incompatible with NDK r27 (no gcc); disable it

- [x] Fixed
- **Symptom:** Android run #29 (NDK r27d, libaom/SDL disabled,
      libuuid/gnutls CFLAGS relaxed) failed compiling libvpx:
      ```
      Configuring for target 'armv7-android-gcc'
        enabling armv7 / neon / neon_asm
      Assuming standalone build with NDK toolchain.
      Toolchain is unable to link executables
      Configuration failed.
      ```
- **Root cause:** libvpx 1.13.0's configure has hardcoded
      assumptions about NDK toolchain paths that include gcc
      wrappers. NDK r27 removed gcc entirely (clang-only). libvpx's
      link-test then can't find `arm-linux-androideabi-gcc` etc.
      and reports "Toolchain is unable to link executables". libvpx
      1.14+ added NDK r27 awareness.
- **Fix:** add `--disable-lib-libvpx` to the workflow. chat-kmp
      doesn't encode VP9 (uses libx264 for H.264 only). FFmpeg's
      native VP9 decoder in libavcodec covers any VP9 source video
      without needing libvpx.
- **Could we bump libvpx?** Yes — but the arthenica/libvpx mirror
      probably doesn't have 1.14+ (U1 lesson), and dropping it is
      consistent with B3 (size trim) anyway.
- **Apple:** defensive `--disable-lib-libvpx` added to build-ios.yml
      for consistency, same as U13/U14.
- **Commit:** _set on commit_

### U16 — gnutls 3.7.9's bundled gnulib fails clang-18 strictness

- [x] Fixed
- **Symptom:** Android run #28 (NDK r27d, libaom+SDL disabled,
      libuuid relaxed) failed compiling gnutls:
      ```
      parse-datetime.y:2026: error: call to undeclared function 'mktime_z'
      parse-datetime.y:2047: error: call to undeclared function 'tzalloc';
        ... incompatible integer to pointer conversion initializing
        'timezone_t' with an expression of type 'int'
      parse-datetime.y:2064: error: call to undeclared function 'tzfree'
      ```
- **Root cause:** gnutls 3.7.9 bundles a copy of `gnulib` whose
      `parse-datetime.y` uses `tzfree`/`tzalloc`/`mktime_z`. These
      functions exist in Android bionic since API 26, but gnulib's
      autoconf feature-detection doesn't recognize bionic, so it
      forgets to include the right header. Result: clang 18 sees
      implicit declarations + an int-to-pointer conversion (because
      the implicit-declared `tzalloc` is assumed `int(...)` not
      `timezone_t(...)`).
- **Fix:** add `-Wno-implicit-function-declaration -Wno-int-conversion`
      to gnutls's build CFLAGS in `scripts/android/gnutls.sh`.
      Runtime-safe: gnulib falls back to the legacy `tzset`-based
      timezone path on platforms where the new functions are absent.
- **Same-family:** see U15 (libuuid). The "old library, sloppy
      includes, clang 18 strict" pattern is recurring. Expect more
      cycles.
- **Commit:** _set on commit_

### U15 — libuuid 1.0.3 missing `<sys/file.h>` include; relax warning

- [x] Fixed
- **Symptom:** Android run #27 (NDK r27d, libaom+SDL disabled) failed
      compiling libuuid:
      ```
      gen_uuid.c:297:10: error: call to undeclared function 'flock';
        ISO C99 and later do not support implicit function declarations
        [-Wimplicit-function-declaration]
      ```
- **Root cause:** libuuid 1.0.3's `gen_uuid.c` calls `flock()` but
      doesn't `#include <sys/file.h>`. Clang 14 warned silently;
      clang 18 promotes to error per ISO C99.
- **Fix:** add `-Wno-implicit-function-declaration` to libuuid's
      build CFLAGS in `scripts/android/libuuid.sh`. `flock()` is
      available in Android bionic libc, so the implicit-decl is
      semantically harmless — the library has just been getting away
      with sloppy includes for years.
- **Why not disable libuuid:** it's a transitive dep of fontconfig
      → libass → subtitle burn-in. chat-kmp doesn't *use* subtitle
      burn-in today, but disabling libuuid would cascade-break
      fontconfig + libass which other consumers might want. Surgical
      CFLAGS fix preserves the dependency chain.
- **Apple/Linux:** scripts/apple/libuuid.sh and scripts/linux/libuuid.sh
      may need the same fix if they ever hit the same clang version.
      Not patched preemptively because Apple/Linux builds use system
      clang (host toolchain), which may or may not be clang 18+.
- **Commit:** _set on commit_

### U14 — SDL 2.0.8 incompatible with clang 18; disable it

- [x] Fixed
- **Symptom:** Android run #26 (NDK r27d + libaom disabled) failed
      compiling SDL:
      ```
      src/sdl/src/render/opengles2/SDL_gles2funcs.h:58: error: incompatible
        function pointer types assigning to 'void (*)(GLuint, GLsizei,
        const GLchar **, const GLint *)' from 'void (GLuint, GLsizei,
        const GLchar *const *, const GLint *)'
        [-Wincompatible-function-pointer-types]
      ```
- **Root cause:** clang 18 tightened function-pointer-type matching
      and now rejects `const char *const *` vs `const char **`
      mismatches that clang 14 accepted. SDL 2.0.8 (release-2.0.8 in
      arthenica/SDL) has the mismatch in its OpenGLES2 wrapper. SDL
      2.0.10+ fixed it, but again the arthenica mirror likely doesn't
      carry newer tags.
- **Fix:** add `--disable-lib-sdl` to the `./android.sh` and
      `./ios.sh` invocations. chat-kmp doesn't use SDL — it's only
      needed for FFmpeg's `ffplay` tool (which we don't build) and
      SDL-based audio/video output filters (which chat-kmp doesn't
      use).
- **Could we instead bump SDL or add `-Wno-*`?**
      * Bump: arthenica mirror staleness risk (per U1); also SDL 2.x
        major bump would be more disruptive.
      * `-Wno-incompatible-function-pointer-types`: would work but
        needs to be added to SDL's build CFLAGS specifically
        (`scripts/android/sdl.sh`) since MY_CFLAGS doesn't reach
        third-party lib builds. More plumbing.
      * Disable: chat-kmp doesn't need SDL anyway. Smaller binary.
        Aligns with B3 (size trim). Trivially reversible if needed.
- **Apple/iOS:** same defensive add as U13 — iOS doesn't currently
      enable SDL but the constraint travels with the workflow.
- **Commit:** _set on commit_

### U13 — libaom 3.6.1 incompatible with clang 18 (NDK r27+); disable it

- [x] Fixed
- **Symptom:** Android run #25 with NDK r27d failed at libaom compile:
      ```
      libaom/aom_dsp/arm/subpel_variance_neon.c:220:1: error: call to
        undeclared function 'aom_variance16x16_neon'; ISO C99 and later
        do not support implicit function declarations
        [-Wimplicit-function-declaration]
      fatal error: too many errors emitted, stopping now
      ```
- **Root cause:** libaom 3.6.1's NEON intrinsics source has missing
      forward declarations. Clang 14 (NDK r25b) warned and kept
      going; clang 18 (NDK r27+, U12) treats implicit declarations
      as a hard ISO-C99 error. libaom 3.8+ fixed the declarations,
      but the `arthenica/libaom` mirror doesn't carry that tag (per
      U1 — mirror stale after the project archived).
- **Fix:** add `--disable-lib-libaom` to the `./android.sh`
      invocation in `.github/workflows/build-android.yml`. chat-kmp
      doesn't use AV1 *encoding* (only H.264; dav1d still provides
      AV1 *decoding* if any consumer needs that). Dropping libaom
      saves ~3-5 MB and avoids the clang-18 incompatibility.
- **Could we instead bump libaom?** Yes — switch the libaom
      SOURCE_REPO_URL in `scripts/source.sh` from `arthenica/libaom`
      to the canonical upstream (`code.videolan.org` mirror or
      similar) and pin v3.8.0+. Skipped because: (a) chat-kmp
      doesn't need AV1 encoding, (b) we'd be removing libaom in B3
      anyway, (c) Option U1 specifically warns against speculative
      lib bumps.
- **Apple/Linux note:** the same incompatibility exists in
      `build-ios.yml` and any linux build, *if* they enable libaom
      under clang 18. Current `build-ios.yml` doesn't enable libaom
      (its flags are `--enable-gpl --enable-ios-zlib --enable-openssl
      --enable-zimg --enable-x264`), so iOS is technically unaffected
      today. `--disable-lib-libaom` is **defensively added to
      build-ios.yml** anyway so the constraint travels with the
      workflow if iOS ever switches to `--full`.
- **Commit:** _set on commit_

### U12 — NDK r27+ required for 16 KB page size alignment (Android 15+)

- [x] Fixed
- **Symptom:** Android Studio refuses to install the APK on a
      Pixel-9 / Android-15+ emulator (or any 16 KB-page device):
      ```
      APK is not compatible with 16 KB devices. Some libraries have
      LOAD segments not aligned at 16 KB boundaries:
        lib/x86_64/libavcodec.so   ... libffmpegkit.so ...
      ```
- **Root cause:** Android 15+ on the latest hardware uses 16 KB
      memory pages. ELF `.so` files built with older NDKs have LOAD
      segments at 4 KB boundaries and can't be `mmap`-loaded on
      16 KB-page devices. NDK r25b ships clang 14 + the 4 KB default.
      Starting **Nov 1, 2025**, Google Play requires 16 KB
      compatibility for app updates targeting Android 15+.
- **Fix:** bump NDK to r27d in `build-android.yml` and
      `periodic-builds-android.yml`. NDK r27+ defaults to
      `-Wl,-z,max-page-size=16384` for ndk-build (which is what
      ffmpeg-kit's Android.mk uses), so all .so files (FFmpeg's
      libav*, libpostproc, our libffmpegkit, plus libc++_shared
      bundled from the NDK) automatically get 16 KB-aligned LOAD
      segments.
- **Side benefit:** r27 ships clang 18, which has native C23
      `<stdbit.h>`. Our U10 install-the-shim fix becomes redundant
      but harmless — the toolchain's own header is found first via
      `-isystem` and our shim is shadowed silently.
- **Side risk:** new clang version may surface fresh warnings or
      reject things older clang accepted. Be ready for one more
      whack-a-mole cycle of `-Wno-*` flag additions to `MY_CFLAGS`
      (see U8), AND for older library pins to break under stricter
      clang (see U13/U14).
- **Belt-and-suspenders #1 (wrapper):**
      `scripts/function-android.sh` generates `android/jni/Application.mk`
      at build time (the static file is gitignored). The generated
      `APP_LDFLAGS` now includes `-Wl,-z,max-page-size=16384`. This
      only covers libs built by **ndk-build** — i.e. `libffmpegkit.so`
      and `libffmpegkit_abidetect.so`.
- **Belt-and-suspenders #2 (FFmpeg's own libs):** verified with
      readelf that NDK r27d *did NOT* default to 16 KB alignment for
      libs built by **FFmpeg's own configure/make** (libavcodec,
      libavformat, libavutil, libpostproc, libswscale, libswresample,
      libavdevice). They came out at `Align = 0x1000` (4 KB) without
      explicit instruction. Added
      `--extra-ldflags="-Wl,-z,max-page-size=16384"` to FFmpeg's
      configure invocation in `scripts/android/ffmpeg.sh`. This flag
      propagates to every FFmpeg-built `.so`. Without it, the
      emulator install error fires on `lib/<abi>/libavcodec.so`
      regardless of NDK version.
- **Alternative path** (not taken): stay on r25b and add
      `-Wl,-z,max-page-size=16384` explicitly to every external
      library's LDFLAGS plus FFmpeg's `--extra-ldflags` plus
      Android.mk's `LOCAL_LDFLAGS`. ~25 places to touch. Bumping the
      NDK is one line.
- **Reference fork:** `JamaisMagic/ffmpeg-kit-16KB` does exactly
      this NDK bump (still on FFmpeg n6.0).
- **Commit:** _set on commit_

### U11 — Bump GitHub Actions to Node 24-native versions

- [x] Fixed
- **Symptom (annotation, not error):** every workflow run shows
      *"Node.js 20 actions are deprecated. ... Node.js 20 will be removed
      from the runner on September 16th, 2026."*
- **Root cause:** GitHub deprecated Node 20 on Actions runners. The v3
      and v4 majors of `actions/checkout`, `actions/setup-java`, and
      `actions/upload-artifact` all run on Node 20. After Sept 16,
      2026 they stop working entirely.
- **Fix:** bump to the Node 24-native majors across **every**
      workflow file (we had v3 / v4 in different places):
      * `actions/checkout@v4` → `actions/checkout@v6`
      * `actions/setup-java@v3`, `@v4` → `actions/setup-java@v5`
      * `actions/upload-artifact@v4` → `actions/upload-artifact@v7`
      Done in 11 files via `sed -i 'actions/X@vN/actions/X@vM'`.
- **Why do it now, not later:** this repo is touched maybe once every
      18 months for a major FFmpeg bump. If we leave it, the next
      person (probably future-you) shows up to a broken CI and can't
      even start the upgrade work until they untangle the Actions
      deprecation. Take the 5-minute hit now to keep CI green
      indefinitely.
- **Commit:** _set on commit_

### U10 — Stock fftools `#include <stdbit.h>` (C23) — install FFmpeg's compat shim

- [x] Fixed
- **Symptom:** wrapper compile fails with:
      ```
      fftools_ffmpeg_dec.c:19:10: fatal error: 'stdbit.h' file not found
      ```
- **Root cause:** FFmpeg n7's `fftools/ffmpeg_dec.c` (and possibly
      other sources in future versions) unconditionally `#include
      <stdbit.h>` — a **C23** header for bit-manipulation utilities.
      NDK r25b ships clang 14, which is pre-C23. FFmpeg's own
      `configure` detects this and adds `-I$(SRC_PATH)/compat/stdbit`
      to `CPPFLAGS`, falling back to FFmpeg's own shim at
      `compat/stdbit/stdbit.h`. The wrapper compile uses Android.mk's
      `LOCAL_C_INCLUDES = $(FFMPEG_INCLUDES)` which doesn't include
      compat dirs, so the include fails.
- **Fix:** install FFmpeg's stdbit.h shim directly at the include
      root: `prebuilt/.../ffmpeg/include/stdbit.h`. Plain
      `<stdbit.h>` then resolves to it. Done in all three platform
      `ffmpeg.sh`.
- **Why not patch the source:** wrapping the include in `#if
      defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L`
      would be a customization in vendored fftools, wiped each
      upgrade. Install-the-shim survives.
- **Future-proofing:** when the host toolchain supports C23 natively
      (Xcode 16+ / NDK r27+ / GCC 13+), the shim becomes redundant
      but doesn't conflict — it would just be unused since the system
      `<stdbit.h>` (if it ships there) is found first via `-isystem`
      search order. Safe to leave in indefinitely.
- **Commit:** _set on commit_

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
- **Follow-up — link against libpostproc too.** Enabling postproc
      solves the *compile*. The wrapper still needs to *link* against
      `libpostproc.so` because ffprobe calls `postproc_version()` /
      `postproc_configuration()` via the `SHOW_LIB_VERSION` macro
      (banner output). Symptom:
      `ld: error: undefined symbol: postproc_version`. Add it to the
      link list in **five places**:
      * `android/jni/ffmpeg/Android.mk` — add a `libpostproc` module
        block (mirror libswscale's)
      * `android/jni/ffmpeg/neon/Android.mk` — same, `libpostproc_neon`
      * `android/jni/Android.mk` — append `libpostproc` and
        `libpostproc_neon` to both `LOCAL_SHARED_LIBRARIES` lines
      * `apple/configure.ac` — append `-framework libpostproc` to
        `FFMPEG_FRAMEWORKS`
      * `apple/scripts/ffmpeg.sh` — call
        `create_temporary_framework "libpostproc"` alongside the other
        FFmpeg libs; without it, libavfilter's link step on iOS fails
        with `ld: framework 'libpostproc' not found`
      * `linux/configure.ac` — append `-lpostproc` to `FFMPEG_LIBS`
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

- [x] **Resolved.** Added `strip_xcframework_signatures()` in
      `scripts/function-apple.sh`, called after each
      `xcodebuild -create-xcframework` invocation (both
      `create_ffmpeg_xcframeworks` and `create_ffmpeg_kit_xcframework`).
      Walks the bundle removing `_CodeSignature` directories and
      running `codesign --remove-signature` on each
      `.framework`'s Mach-O executable.

**What was going on.** ffmpeg-kit's scripts contain **no explicit**
`codesign` calls — signing is **implicit** from `xcodebuild
-create-xcframework`, which uses the default Xcode signing identity.
There's no `--no-sign` flag for that command. The only way to produce
unsigned output is post-process.

**chat-kmp impact.** Once a build with this fix lands and the new
xcframework is dropped into chat-kmp, the custom
`codesign --remove-signature` step in chat-kmp's iOS workflow can be
removed entirely. The Xcode-26-on-macos-15 codesign hang at the Embed
Frameworks step (the symptom motivating B1 + B2) is addressed by the
combination of B1 (unsigned input) + B2 (thin slices, still pending).

## B2 — iOS xcframework ships fat (multi-arch) binaries; chat-kmp wants thin

- [x] **Resolved.** Added `--disable-arm64e` to `./ios.sh` invocation
      in `.github/workflows/build-ios.yml`. With arm64e disabled, the
      iOS device slice `ios-arm64_arm64e/` collapses to `ios-arm64/`
      holding a thin arm64 Mach-O — no `lipo -create` of multiple
      architectures into the device-slice framework binary, no
      Xcode-26 codesign hang.
- **Trade-off:** drops arm64e support. arm64e is a kernel pointer-auth
      variant; iPhone XS+ devices run plain arm64 user code just fine
      (kernel runs arm64e, app code is transparent). User-space apps
      effectively never need arm64e.
- **Simulator + Mac Catalyst slices stay fat** (arm64+x86_64) — that's
      correct for those slices; the codesign hang only triggered on
      device-slice fat. Those slices are also not in the iOS app's
      Embed Frameworks phase for device builds.
- **chat-kmp impact:** after a fresh iOS build with this flag, chat-kmp
      can drop the `Thin FFmpegKit device-slice dylibs` workflow step.

----

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

## B3 — AAR / xcframework size: trim to chat-kmp's actual codec set

- [ ] Switch from `--full --enable-gpl` (kitchen sink) to a
      `--disable-everything` + per-feature-enable build list scoped
      to what chat-kmp actually uses.

**Why:** the n7.1.3 AAR ships at ~86 MB (up from ~51 MB on n6.0,
driven by enabling postproc + n7 feature expansion). chat-kmp's
actual codec needs from the integration survey:

| Need | Used for |
|---|---|
| H.264 encode/decode (libx264, h264_mediacodec, h264_videotoolbox) | video |
| AAC encode/decode | audio |
| HLS muxer + AES-128 encryption | streaming |
| `aac_adtstoasc` bitstream filter | HLS→MP4 remux |
| `scale` filter | downscale to max 1280px |
| `movflags +faststart` | MP4 muxer flag |
| `side_data_list` JSON in ffprobe | rotation probe |
| VP9 decode | source compat |
| Opus, MP3, WebP | audio + thumbnail fallback paths |

Everything else (huge swaths of obscure muxers, decoders, protocols,
filters) is dead weight in the binary.

**Suggested starting flag set** (refine per CI cycle):

```sh
./android.sh --enable-gpl --enable-x264 --enable-libwebp \
    --disable-everything \
    --enable-decoder=h264,aac,vp9,opus,mp3,png,mjpeg \
    --enable-encoder=libx264,h264_mediacodec,aac \
    --enable-muxer=mp4,hls,mpegts,webm \
    --enable-demuxer=mov,mp4,hls,mpegts,matroska \
    --enable-parser=h264,aac,vp9 \
    --enable-filter=scale,aresample \
    --enable-protocol=file,http,https,crypto \
    --enable-bsf=aac_adtstoasc,h264_mp4toannexb
```

The `--disable-everything` flag is exposed by FFmpeg's configure and
turns off every codec/muxer/demuxer/protocol; the per-feature
enables then opt back in only what we need.

**Realistic target:** ~25-35 MB AAR (≈3× shrink). The unused codec
.so contents in libavcodec are by far the biggest line items.

**Risk:** undersizing — accidentally omitting a feature chat-kmp
uses at runtime. Mitigation: run the full chat-kmp test suite plus
manual smoke (upload videos in various source formats) before
shipping. If a feature is missing the runtime error message names
the codec/protocol; trivially add the enable flag and rebuild.

**Where the flag set lives** (when applied):
* `.github/workflows/build-android.yml` — `run the build script` step
* `.github/workflows/build-ios.yml` — same step (mirrored for
  `./ios.sh`)
* the equivalent macOS / tvOS workflows when those are added

**Why deferred:** the n7.1.3 upgrade was already proving complex.
Shipping the bigger-but-functional AAR first lets chat-kmp consumers
test the upgrade independently of a size-optimization change. Do
this in a focused follow-up PR.

## Verification (after fix)
- B1: produced `ffmpegkit.framework` Mach-O passes `codesign -dv` as
      unsigned.
- B2: `lipo -info <slice>/ffmpegkit.framework/ffmpegkit` reports a
      single architecture per slice.
- B3: produced AAR ≤ 35 MB; chat-kmp's full test suite still passes;
      manual smoke (video upload + HLS encryption) green.
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
