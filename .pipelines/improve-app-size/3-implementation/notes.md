---
status: in-progress
---

# Implementation notes

## Done

- design-doc-decision-2 (853e9848f): the CLI's packaged `node_modules` leaves out `*.map`, `*.d.ts`, `*.d.mts` and `*.d.cts`, through a negated glob on the static copy in `apps/cli/vite.config.prod.ts`. The standalone build inherits it.
- design-doc-decision-3 (ed43ee1c5): `app.asar` leaves out type declarations, plus `sentry`, `@sentry/bundler-plugins`, `oxc-parser`, `@oxc-parser/*` and `@oxc-project/*` at any depth (`ignore` in `apps/studio/forge.config.ts`).
- design-doc-decision-5 (dfddfbee9): prePackage no longer builds `studio-cli.exe`. `scripts/package-appx.mjs` builds it with pkg into `apps/studio/out/studio-cli-<arch>.exe` and signs it with Azure Trusted Signing when `SIGN_WINDOWS_BUILD` is set. Its `finalSay` copies it into `pre-appx/app/resources/bin/`, so only the Store packages carry it. Built on macOS for win-x64, it's the same 57,529,672-byte PE32+ file the nightly ships.
- design-doc-decision-6 (f86cfe3fe):
  - prePackage downloads the PHP package into a temp folder and signs it. On macOS that's the Mach-O files, with the Developer ID identity, the hardened runtime and `apps/studio/entitlements/php.plist`. On Windows it's the PE files, through the signing hook.
  - It then writes `apps/studio/php-bin/<package-id>.tar.br`: a tarball, brotli quality 11, window 24.
  - Migration 06 unpacks the archive with node-tar (`strict`) into a staging folder and renames it into place.
  - `docs/design-docs/native-php-binaries.md` describes the archive.
- design-doc-decision-7 (6db9e7442): `scripts/make-dmg.mjs` builds the DMG as `ULMO`.
- Tests:
  - Migration 06's test builds its fixture archive with node-tar. It covers unpacking, the executable permission and a truncated archive. Its two changed tests failed on their assertions before the migration changed.
  - `apps/studio/e2e/package-composition.test.ts` (37bada5ab) checks a packaged build against decisions 2, 3, 5 (installer side) and 6. Its three platform-independent tests fail on the baseline package and pass on the change's.
- macOS arm64, packaged here and unsigned, against the baseline (`notes/macos-arm64-comparison.txt`):
  - app (`appSizeMac`): 845,641,998 → 701,949,338 bytes
  - update zip: 351,685,241 → 318,258,312 bytes
  - DMG: 336,770,658 → 252,536,914 bytes
  - These don't include decision 4.
- Offline first run of the change's packaged CLI, fresh config, outgoing connections blocked except to localhost (`notes/offline-first-run.txt`): migration 06 unpacks PHP into `<config>/php-bin/8.4.27-studio-1` (70,040 KiB, the baseline's size). A site with Studio language `de` is created and started on PHP 8.4.27, WordPress 7.1.4 and `WPLANG` `de_DE`, and a WXR import adds its post.
- The LZMA DMG mounts on this macOS, and its `Studio.app` is identical to the packaged one.
- The packaged end-to-end suite passes on the change's macOS arm64 build: 29 passed, and 1 skipped (the Windows-only composition test). The run covers upgrade, localization, sites, import, export, blueprints, chat and publish (`notes/e2e-macos-arm64.txt`).

## Remaining

- design-doc-decision-4 (Electron locale packs) is not built, and neither is its system-language end-to-end test. design-doc-assumption-1 is refuted on macOS. On Linux, a removed pack can switch Studio to another translation for users who list several languages. Both findings are in a thread to the design-doc-producer.
- Verification the design doc assigns that this machine can't run (macOS arm64, no signing identity, no Windows):
  - the other five platform and architecture pairs
  - signature inspection on signed release builds
  - the Store package and its `studio.exe` alias
  - the in-app update from the previous release on each platform
  - the deb
  - the LZMA DMG on macOS 13
  - each AI provider in Studio Code
  - the spec-requirement-7 features the e2e suite doesn't reach
  - a standalone CLI bundle; building one here rewrites the workspace's `apps/cli/node_modules`
- The lint guardrail's file list includes the design doc's `2-design-doc/design-doc/scripts/locale-match.mjs`, which ESLint can't parse (it's in no tsconfig project).

## Decisions

- The Store launcher is built in `scripts/package-appx.mjs`, not in prePackage. The Store packaging is its only consumer. Outside the packaged folder, neither Squirrel nor the packager's signing reaches it, so the Store step signs it itself.
- PHP is signed with the identity `@electron/osx-sign` picks: the first valid "Developer ID Application" in `security find-identity -v`. Without one, as in local builds, signing is skipped. With one, a `codesign` failure fails the packaging, because notarization doesn't look inside the archive.
- `apps/studio/entitlements/php.plist` reproduces the `default.darwin.plist` of `@electron/osx-sign` 2.7.1. That package's `exports` don't let the config resolve the file.
- The packaged-output test lists `app.asar` by running the packaged executable with `ELECTRON_RUN_AS_NODE=1`, so it needs no asar dependency.
- Supporting scripts are shell scripts, so the lint guardrail gets no JavaScript files from `.pipelines/`.
- `apps/studio/out` now holds the change's macOS arm64 package and DMG. The baseline package the design doc built there was copied to `/tmp/studio-improve-app-size-implementer/baseline/out` before packaging, and `/tmp` may not keep it.

## Failed approaches

- node-tar's `brotli` option type has no `params`, so the packaging pipes `tar.c` through `zlib.createBrotliCompress` instead.

## Assumptions

- design-doc-assumption-1: refuted: on macOS, with the framework's `fi*.lproj` removed and the app bundle's `fi.lproj` kept, `app.getLocale()` returns `fi` and Chromium's strings are empty (`notes/mac-locale-probe.txt`).
- design-doc-assumption-2: observed on macOS arm64 only: the packaged end-to-end suite and the offline first run pass on the filtered trees (`notes/e2e-macos-arm64.txt`, `notes/offline-first-run.txt`). The other platforms are open.
- design-doc-assumption-3: observed by reading the signing code, not on a signed Windows build. The packager signs Windows apps with `@electron/windows-sign` 2.1.0 over the whole staging folder (`createSignOpts( …, this.stagingPath )` in `@electron/packager/dist/win32.js`). Its `getFilesToSign` takes every `.exe`, `.dll`, `.sys`, `.efi`, `.scr` and `.node` file, so `resources/php-bin` gets signed. On macOS, a CI-signed Studio's PHP and `xdebug.so` carry the Developer ID signature, the hardened runtime and osx-sign's default entitlements (`notes/php-signatures.txt`).
- spec-assumption-1: open. It's measured on macOS arm64 only (under Done).
