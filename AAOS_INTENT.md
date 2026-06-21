# Mossyfin AAOS — Intent Spec (authoritative resolution guide)

This file is the SOURCE OF TRUTH for what the `mossyfin-aaos` fork customizations
are meant to achieve. When the weekly upstream sync hits a merge conflict, resolve
it so that EVERY invariant below still holds. You may refactor freely (rename,
restructure, adopt upstream's new patterns) **as long as the functional intent and
the AAOS behavior are preserved**. Matching upstream's code shape is preferred over
preserving our exact original lines — the goal is the behavior, not the diff.

Baseline: these are the net changes of `mossyfin-aaos` vs `jellyfin/master`,
authored 2026-06. Captured by inspecting `git diff upstream/master..HEAD`.

## HARD INVARIANTS (must always hold; verify after any resolution)

1. **AAOS package identity.** The build must have a `target` flavor dimension with
   `mobile` and `aaos` flavors (plus the existing `variant` dim: libre/proprietary).
   - `aaos` flavor → applicationId `com.blazelink.mossyfin.aaos`, `versionNameSuffix = "-aaos"`.
   - `mobile` flavor → applicationId `com.blazelink.mossyfin`.
   - Driven by overridable gradle props with these defaults:
     `app.applicationId=com.blazelink.mossyfin`, `app.aaosApplicationId=<base>.aaos`,
     `app.appLabel=Mossyfin`, `app.aaosAppLabel=<base label>`.
   - The release build task is `bundleAaosLibreRelease`. It MUST exist and emit
     package `com.blazelink.mossyfin.aaos`. (Plain `bundleRelease` = wrong package.)

2. **Branding.** App name is **Mossyfin** (both `app_name` and `app_name_short` in
   strings_donottranslate.xml). The main manifest `android:label` uses the
   `${appLabel}` manifest placeholder (set per-flavor), NOT a hardcoded string.
   Output AAB archivesName is `mossyfin-v<version>`.

3. **PiP safety on head units (AAOS).** `PlayerFragment.onUserLeaveHint()` must only
   call `enterPictureInPicture()` when the device actually has
   `PackageManager.FEATURE_PICTURE_IN_PICTURE`. AAOS units lack PiP; calling it
   crashes. Keep this guard however the surrounding code is shaped upstream.

4. **Service-bind safety.** `MainActivity` must not call `unbindService` for a bind
   that never succeeded. Track bind success (the `isServiceBound` flag) and guard the
   unbind in `onDestroy`. Preserve this even if upstream refactors the service code.
   (The `ensureWebViewSupport()` extraction is cosmetic — fine to keep, drop, or
   re-merge into whatever shape upstream uses, as long as the WebView-unsupported
   dialog still shows and early-returns.)

5. **AAOS: usable WHILE DRIVING and parked (distraction-optimized) — NOT parked-only.**
   This is the single most important behavioral invariant. The whole point of the AAOS
   work is that the app runs both while the car is parked AND while it is being driven.
   `app/src/aaos/AndroidManifest.xml` declares the app distraction-optimized so AAOS
   does not restrict it to parked use:
     - application meta-data `com.android.automotive.application.DISTRACTION_OPTIMIZED` = `true`
     - the MainActivity `<meta-data android:name="distractionOptimized" android:value="true"/>`
   Both MUST remain `true`. Also keep: `uses-feature android.hardware.type.automotive
   required=true`; the launcher/CAR_MODE/APP_MUSIC intent-filters; and `appCategory="video"`.
   The manifest also opts implicit hardware `<uses-feature>` (touchscreen, screen
   orientation, wifi, bluetooth) to `required="false"` so the package manager does NOT
   filter the app out of the launcher / Settings-Open / Play-Open. Keep those opt-outs.

5b. **ANTI-INVARIANT — do NOT reintroduce parked-only / driving-restriction enforcement.**
   An earlier iteration added app-level UX-restriction gating and a parked-mode screen;
   it was DELIBERATELY REMOVED (commit b8e95de7). These files/behaviors must STAY GONE:
   `ParkedModeFragment.kt`, `app/src/main/res/layout/fragment_parked_mode.xml`,
   `AutomotiveUxRestrictionsState.kt`, and any CarUxRestrictions listener wiring in
   `RemotePlayerService` / `PlayerViewModel` / `ActivityEventHandler` / `MainActivity`
   that blocks or blanks the UI while the car is moving. If upstream introduces an
   equivalent "block while driving" feature, do NOT enable it for the `aaos` flavor —
   that would defeat the drive-while-moving intent. (Note: the `PlayerFragment` PiP
   guard in invariant #3 is unrelated to this — it's about head units lacking PiP, not
   about driving restrictions. Keep it.)

6. **Build tooling / ignores.** `.gitignore` ignores `/secrets`, `/keystore.properties`,
   `/app/bin/`, `/.gradle-local`. The `scripts/*.ps1` and the
   `.github/workflows/mossyfin-aaos.yaml` are ours; keep them unless upstream
   structurally replaces the workflow system.

## SIGNING — DO NOT RE-ADD OUR OWN SIGNING CODE
Upstream now inlines release signing in `app/build.gradle.kts` reading
`keystore.file` / `keystore.password` / `signing.key.alias` / `signing.key.password`
properties (the old `buildSrc/.../SigningHelper.kt` was DELETED upstream — keep it
deleted). Our release path (`_signing/release.sh`) injects signing via
`-Pandroid.injected.signing.*`, which overrides at build time regardless. So: when a
conflict touches signing, ALWAYS take upstream's signing shape. Never reintroduce
SigningHelper.kt.

## SDK / VERSION
Use upstream's version-catalog refs (`libs.versions.android.{compileSdk,minSdk,targetSdk}`).
Do not hardcode SDK levels. versionCode/Name come from `buildSrc/.../VersionUtils.kt`
via the `JELLYFIN_VERSION` env var (`0.0.0-dev.N` → versionCode N). Do not change this.

## RESOLUTION CHECKLIST (run mentally before committing a resolved merge)
- [ ] `git grep -n "com.blazelink.mossyfin"` shows base + `.aaos` still wired via flavors.
- [ ] `./gradlew tasks` would list `bundleAaosLibreRelease` (the `aaos`×`libre` combo exists).
- [ ] No `SigningHelper` references reintroduced (`git grep SigningHelper` = empty).
- [ ] PiP `FEATURE_PICTURE_IN_PICTURE` guard present in PlayerFragment.
- [ ] `isServiceBound` guard present around `unbindService` in MainActivity.
- [ ] App name = Mossyfin; manifest label uses `${appLabel}`.
- [ ] AAOS distraction-optimized: `DISTRACTION_OPTIMIZED` and `distractionOptimized`
      both `true` in `app/src/aaos/AndroidManifest.xml` (usable while driving, not parked-only).
- [ ] Parked-only enforcement stays GONE: `git grep -l "ParkedModeFragment\|AutomotiveUxRestrictionsState"`
      returns nothing; no CarUxRestrictions "block while moving" wiring re-added.
- [ ] No leftover conflict markers (`git grep -nE '^(<<<<<<<|=======|>>>>>>>)'` = empty).
- [ ] No hardcoded SDK ints reintroduced where upstream uses the catalog.
