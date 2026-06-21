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

5. **AAOS manifest + parked behavior.** `app/src/aaos/AndroidManifest.xml` provides
   car-app metadata so the app shows a launcher entry on AAOS and behaves correctly
   while parked. Opt out of implicit hardware `<uses-feature>` requirements that
   would hide the launcher entry. (Upstream rarely touches `src/aaos/` — conflicts
   here are unlikely, but if upstream adds new required features, keep the AAOS
   launcher entry working.)

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
- [ ] No leftover conflict markers (`git grep -nE '^(<<<<<<<|=======|>>>>>>>)'` = empty).
- [ ] No hardcoded SDK ints reintroduced where upstream uses the catalog.
