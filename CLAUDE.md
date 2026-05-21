# Repo notes for Claude Code

This is the Homebase fork of `arthenica/ffmpeg-kit`. The original project is
retired; we self-maintain.

## Read this first when working in this repo

**`CUSTOMIZATION.md`** — the canonical reference for every source-level
customization this fork applies on top of stock FFmpeg fftools. When
upgrading FFmpeg, re-apply each item there to the new stock snapshot.
Checkboxes track which customizations are currently in place; update them
as work proceeds.

## Tag conventions

- `pre-<version>-baseline` — last working state on the previous FFmpeg
  version, before an upgrade starts.
- `stock-n<version>` — fresh FFmpeg fftools snapshot at version `<version>`,
  with `fftools_` prefix and `#include` rewrites applied, but **zero
  Homebase customizations**. The diff between this tag and the active
  branch is exactly what `CUSTOMIZATION.md` describes.

To see the current customization diff:

```
git diff stock-n<version>..HEAD -- '*/fftools_*.c' '*/fftools_*.h'
```

## Primary downstream consumer

`chat-kmp` (Kotlin Multiplatform). It uses ffmpeg-kit's baseline session
API only — no Statistics, LogCallback, Cancel, or async APIs.
`CUSTOMIZATION.md` includes a verification matrix mapping chat-kmp's
command patterns to the customizations they require.
