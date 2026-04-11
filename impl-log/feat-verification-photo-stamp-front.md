# feat(app): stamp verification photos with date/time/character watermark

- **Date**: 2026-04-11
- **Commit**: 3498a56
- **Area**: frontend (app/)

## What Changed

Camera-captured verification photos are now composited with a bottom-bar
watermark containing the current date (YYYY.MM.DD), time (HH:mm), the
user's pixel character, and nickname. The goal is social proof — other
challenge members can see that the photo was taken today by the poster.
Gallery-picked photos are intentionally left untouched to avoid stamping
today's date on an older image (which would be misleading evidence).

## Changed Files

| File | Change |
|------|--------|
| `app/lib/core/widgets/character_avatar.dart` | Added top-level `paintCharacterIntoCanvas(Canvas, {CharacterData?, Rect})` helper that reuses the private `_PixelCharacterPainter` with a static (non-animated) frame so the stamped character matches the live widget. |
| `app/lib/features/challenge_space/utils/verification_photo_stamper.dart` | **New.** `stampVerificationPhoto({photoBytes, character, nickname, timestamp})` decodes the image with `ui.instantiateImageCodec`, draws it onto a `PictureRecorder` canvas, overlays a black translucent bottom bar (~12% of image height, clamped 96–200px), paints the character on the left, nickname next to it, and right-aligned date/time on the right, then re-encodes to PNG. |
| `app/lib/features/challenge_space/screens/create_verification_screen.dart` | `_takePhoto()` now reads the camera bytes, pulls character from `myCharacterProvider` and nickname from `authStateProvider`, calls `stampVerificationPhoto`, and stores the stamped result. On any exception it falls back to raw bytes — stamping must never block upload. `_pickFromGallery()` unchanged. |

## Implementation Details

- **No new dependencies.** All rendering via `dart:ui` (`PictureRecorder`,
  `Canvas`, `TextPainter`, `ImageByteFormat.png`). Date/time formatted
  manually with zero-padding; `intl` not used.
- **Character rendering reuse.** Rather than exporting the painter or
  rasterizing a widget tree, added a tiny public wrapper that invokes the
  existing private `_PixelCharacterPainter` against an external canvas.
  This keeps the stamped avatar pixel-for-pixel identical to the widget.
- **Layout**: `barHeight = (imgH * 0.12).clamp(96, 200)`. Character box
  uses `barHeight * 0.12` padding. Nickname font ≈ `barHeight * 0.26`,
  date ≈ `barHeight * 0.24`, time ≈ `barHeight * 0.28`. White text on
  black 55% opacity bar.
- **Failure mode**: any exception from `stampVerificationPhoto` is caught
  and the raw photo bytes are used instead. Upload always proceeds.
- **Scope discipline**: gallery path deliberately not watermarked. Server
  API contract unchanged — still receives multipart bytes (now PNG for
  stamped shots instead of JPEG; no schema impact).

## Unrelated cleanup

During this session, `app/lib/core/widgets/main_shell.dart` was in a
phantom `UU` index state left over from a previous aborted operation.
HEAD's version already matched the intended content and `origin/main`
had no competing changes to that file, so the stale index entries were
cleared via `git checkout HEAD -- main_shell.dart`. No functionality
lost.

## Tests & Build

- `flutter analyze` (3 changed files): 0 new issues (1 pre-existing
  `unused_local_variable` warning on an untouched line).
- `flutter build ios --simulator`: pass (via deployer agent).
- iOS Simulator (iPhone 17, iOS 26.4): app launched cleanly; Dart VM
  service reachable at `127.0.0.1:54040`.
- **Visual watermark verification**: not performed — iOS simulator has
  no camera, so the `_takePhoto()` path cannot be exercised on the
  simulator. To be verified on a physical device.

## Known Limitations

- Client-side watermark only. A determined user could bypass by editing
  the stamped image or reusing an old stamped photo. This is social
  proof, not cryptographic provenance — acceptable for the MVP trust
  model.
- Re-encoding as PNG may increase upload size vs. the original
  JPEG-85. Acceptable for 1920×1920 capped photos.
