# FFmpeg n6.0 -> n7.1.3 upgrade — handoff notes

Branch: `upgrade/ffmpeg-7.1.3`
Baseline tag: `pre-7.1.3-baseline`
Reference patches: `c:/temp/Git/_upgrade_work/patches/`

## What was done in this branch

1. **Library version pins** — `scripts/source.sh` bumped to FFmpeg n7.1.3 and every external library bumped to latest stable. Tags assumed to exist on the `arthenica/*` mirror forks; if missing at build time, either push the tag on the mirror or switch the per-library `SOURCE_REPO_URL` to canonical upstream.
2. **Vendored fftools sources replaced** with stock n7.1.3 `fftools/*.{c,h}` in all three platform trees (`apple/src/`, `android/ffmpeg-kit-android-lib/src/main/cpp/`, `linux/src/`). Files were renamed with the `fftools_` prefix and intra-fftools `#include` lines rewritten accordingly. **5 new sources** present in n7.1.3 were added: `fftools_ffmpeg_dec.c`, `fftools_ffmpeg_enc.c`, `fftools_ffmpeg_sched.c`, `fftools_ffmpeg_sched.h`, `fftools_ffmpeg_utils.h`.
3. **Build files updated** to include the 5 new sources/headers:
   - `apple/src/Makefile.am`
   - `linux/src/Makefile.am`
   - `android/jni/Android.mk` (`MY_SRC_FILES` line)
4. **CI workflows** — `periodic-builds-android.yml` matrix dropped r22b/r23b/r24 (n7.1.3 needs r25+); `periodic-builds-apple.yml` `macos-12 / Xcode 13.4.1` rows bumped to `macos-13 / Xcode 14.2` (macos-12 runner is retired); `actions/setup-java` upgraded to v4.
5. **Wrapper audit** — `StreamInformation.{m,h,java,dart}` / `react-native/src/index.js` only reference `"channel_layout"` as a JSON key string. No FFmpeg-7 API breakage in wrapper code.

## What was deliberately NOT done — manual work remaining

The replaced fftools sources are **stock n7.1.3**, with **none of the ffmpeg-kit functional customizations re-applied**. The build will not link until those customizations are ported on top of the new sources. Below is the precise punch list, derived from diffing the prior vendored sources against stock n6.0.

### Critical: symbols the wrappers expect that don't exist yet

`android/.../cpp/ffmpegkit.c` and `apple/src/FFmpegKitConfig.m` reference these symbols. Each must be added to the new vendored fftools:

| Symbol | Where it lived in n6.0 vendored fftools | Notes |
| --- | --- | --- |
| `int ffmpeg_execute(int argc, char **argv)` | `fftools_ffmpeg.c` — `main()` renamed | n7.1.3 also has a `main()` in `ffmpeg.c`. Rename it and remove the platform-specific Windows console wrappers. |
| `int ffprobe_execute(int argc, char **argv)` | `fftools_ffprobe.c` — `main()` renamed | Same approach. |
| `void cancel_operation(long id)` | Added to `fftools_ffmpeg.c` | Sets a session-id-keyed atomic flag the run loop polls. n7.1.3 added a scheduler (`ffmpeg_sched.c`) — the cancellation hook will need to interrupt the scheduler too. |
| `void set_report_callback(...)` | Added to `fftools_ffmpeg.c`; `forward_report()` called from `print_report()` | Receives stats (frame, fps, bitrate, time, etc.) per progress tick. The signature in the prior fork was bumped 2023-09 to accept `pts` and produce `time` as `double`. |
| Use of `longjmp_value` + `setjmp`/`longjmp` in place of `exit()` | `fftools_cmdutils.c` and call sites | `exit_program()` was rewritten to `longjmp` into `ffmpeg_execute`/`ffprobe_execute`. Required because ffmpeg-kit embeds ffmpeg as a callable library, so `exit()` would tear down the host process. |

### Other functional patches to replay (less critical but required for correctness)

These were present in the n6.0 vendored fftools but are absent from the fresh n7.1.3 snapshot:

- **Thread-local globals.** `vstats_file`, `received_sigterm`, `received_nb_signals`, and other module-globals were marked `__thread` to allow multiple concurrent `ffmpeg_execute` invocations. Re-apply across `fftools_ffmpeg.c` and any other globals introduced by n7.1.3 in the new files (`ffmpeg_sched.c`, `ffmpeg_dec.c`, `ffmpeg_enc.c`).
- **`setvbuf`, `flushing stderr`, and `setvbuf(stderr, NULL, _IONBF, 0)` calls were removed** to avoid stomping the host process's stderr handling.
- **Muxing-overhead message** condensed to single-line output for parseable logs.
- **OptionDef defines combined** — minor refactor in fftools_ffmpeg_opt.c.
- **`ignoring signals`** — `sigterm_handler` and related signal hooks removed/neutralized when running embedded.
- **fftools_ prefix on includes** is already done by the replay script, but verify no n7.1.3 cross-references in the new `_sched.c`/`_dec.c`/`_enc.c`/`_utils.h` files were missed.
- **`ffmpegkit_exception.h` include** is *not* re-injected by the replay script. The custom `setjmp` exit mechanism lives in this header; it must be `#include`-d at the top of `fftools_ffmpeg.c`, `fftools_ffprobe.c`, and `fftools_cmdutils.c` (where `exit_program` is defined).

### Reference patches

For each file in the n6.0 vendored set, `c:/temp/Git/_upgrade_work/patches/<file>.patch` contains the unified diff between stock n6.0 fftools and the vendored copy. These are the patches to study when porting customizations forward. Estimated total patch volume: ~5,800 lines, dominated by:

- `ffmpeg.c` (~1,400 lines) — the bulk of the functional changes
- `ffmpeg_opt.c` (~1,100 lines) — much of this is dead code from n6.0 that no longer exists in n7.1.3 (option parsing was moved into the scheduler split); a chunk of it is the OptionDef refactor that must be replayed.
- `ffprobe.c` (~900 lines) — mostly the `main` -> `ffprobe_execute` rename and exit-handling changes.
- `opt_common.c` (~800 lines) — header tweaks and the OptionDef refactor again.
- `cmdutils.c` (~250 lines) — `exit_program` setjmp/longjmp implementation.

The two `*_dec.c` / `*_enc.c` / `*_sched.{c,h}` files have **no prior vendored counterpart** — they are pure n7.1.3 additions. Any functional patches that conceptually belong in encode, decode, or scheduling paths (e.g., `forward_report` stats, cancellation polling) must be added to these new files for the first time.

### `cmdutils.c` per-platform delta

The vendored `fftools_cmdutils.c` differed only by **one comment line** between apple/android/linux trees (the apple variant references `FFmpegKitConfig.m`; android/linux reference `ffmpegkit.c`). The replay script removed this distinction by writing the same file to all three trees. If the comment matters for documentation, restore the per-tree comment manually; otherwise, leave as-is — the code is functionally identical.

## Suggested order of operations

1. Get a clean baseline build of `pre-7.1.3-baseline` to confirm the existing build environment works (CI is the easiest place to do this).
2. Re-apply the four critical symbols (`ffmpeg_execute`, `ffprobe_execute`, `cancel_operation`, `set_report_callback`) by studying `patches/ffmpeg.c.patch` and `patches/ffprobe.c.patch`. These produce a buildable but feature-limited library.
3. Re-apply `setjmp`/`longjmp` exit handling by porting `patches/cmdutils.c.patch` to the new `fftools_cmdutils.c`. Required for library safety.
4. Re-apply thread-local globals, signal handling, stderr/setvbuf hygiene. Required for embedded use.
5. Re-apply stats forwarding (`forward_report` / `print_report` callback hook). Required for the Statistics API to function.
6. Wire cancellation into the new `ffmpeg_sched.c` so cancelled sessions actually interrupt the scheduler. This is genuinely new work — n7.1.3 introduced the scheduler.
7. Build matrix on CI: Android arm64-v8a + x86_64, iOS arm64 device + sim, macOS arm64 + x86_64, tvOS arm64. Run the validation invocations described in the upgrade plan (H.264 encode, VP9 encode, libass burn-in, AAC roundtrip, HTTPS pull for https-gpl variants).
8. Pre-release as `7.1.0-pre.1` to npm/pub.dev/CocoaPods/Maven; soak with `homebase-id/odin-js` for 48 h; promote to `latest`.

## Working files outside the repo

- `c:/temp/Git/_upgrade_work/ffmpeg-n6.0/fftools/` — stock n6.0 sources for diffing
- `c:/temp/Git/_upgrade_work/ffmpeg-n7.1.3/fftools/` — stock n7.1.3 sources (the replay base)
- `c:/temp/Git/_upgrade_work/patches/*.patch` — n6.0 -> vendored diffs (the patch set to replay)
- `c:/temp/Git/_upgrade_work/replay.sh` — the script that re-snapshots n7.1.3 fftools (re-runnable if you want to start the port over from a fresh n7.1.3 base)

## Rollback

```
git checkout main
git branch -D upgrade/ffmpeg-7.1.3   # if you want to nuke the branch
# or
git reset --hard pre-7.1.3-baseline  # if you want main back at v6.0
```

The `pre-7.1.3-baseline` tag pins the v6.0 state.
