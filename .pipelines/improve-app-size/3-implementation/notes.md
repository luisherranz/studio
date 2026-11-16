---
status: done
---

# Implementation notes

## Done

- design-doc-decision-2 (853e9848f): the CLI's packaged `node_modules` leaves out `*.map`, `*.d.ts`, `*.d.mts` and `*.d.cts`, through a negated glob on the static copy in `apps/cli/vite.config.prod.ts`. The standalone build inherits it.
- design-doc-decision-3 (ed43ee1c5): `app.asar` leaves out type declarations, plus `sentry`, `@sentry/bundler-plugins`, `oxc-parser`, `@oxc-parser/*` and `@oxc-project/*` at any depth (`ignore` in `apps/studio/forge.config.ts`).
- design-doc-decision-4, as revised in bd346affb (010d67672):
  - An `afterExtract` hook in `apps/studio/forge.config.ts` keeps the pack of English and of every locale `matchSupportedLocale` maps to a translation. Every other pack becomes the English one.
  - macOS: a link to `../en<gender>.lproj/locale.pak`, gendered variants included. Linux: a link to `en-US.pak`. Windows: a copy of `en-US.pak`.
  - `matchSupportedLocale` (`apps/studio/src/lib/match-supported-locale.ts`) is `getSupportedLocale`'s matcher, extracted so the app and the packaging share it.
- design-doc-decision-5 (dfddfbee9): prePackage no longer builds `studio-cli.exe`. `scripts/package-appx.mjs` builds it with pkg into `apps/studio/out/studio-cli-<arch>.exe` and signs it with Azure Trusted Signing when `SIGN_WINDOWS_BUILD` is set. Its `finalSay` copies it into `pre-appx/app/resources/bin/`, so only the Store packages carry it. Built on macOS for win-x64, it's the same 57,529,672-byte PE32+ file the nightly ships.
- design-doc-decision-6 (f86cfe3fe):
  - prePackage downloads the PHP package into a temp folder and signs it. On macOS that's the Mach-O files, with the Developer ID identity, the hardened runtime and `apps/studio/entitlements/php.plist`. On Windows it's the PE files, through the signing hook.
  - It then writes `apps/studio/php-bin/<package-id>.tar.br`: a tarball, brotli quality 11, window 24.
  - Migration 06 unpacks the archive with node-tar (`strict`) into a staging folder and renames it into place.
  - `docs/design-docs/native-php-binaries.md` describes the archive.
- design-doc-decision-7 (6db9e7442): `scripts/make-dmg.mjs` builds the DMG as `ULMO`.
- Tests:
  - Migration 06's test builds its fixture archive with node-tar. It covers unpacking, the executable permission and a truncated archive. Its two changed tests failed on their assertions before the migration changed.
  - `apps/studio/src/tests/forge-config.test.ts` runs the `afterExtract` hook on fake Linux, Windows and macOS layouts, gendered variants included. Its three new cases failed on their assertions without the hook.
  - `apps/studio/e2e/package-composition.test.ts` checks a packaged build against decisions 2, 3, 4, 5 (installer side) and 6. Its four platform-independent tests failed on a package without each decision and pass on the change's.
  - `apps/studio/e2e/localization.test.ts` › "Localization from the system language" (d9d0e7cad) launches with no saved language and the system's languages set. It checks `app.getLocale()`, Studio's language and Chromium's own validation message, for `fi, de` (`fi`, English, English) and for `de` (German throughout). The first failed on Chromium's Finnish string before decision 4. `E2ESession.launch` takes `args` for it.
- macOS arm64, packaged here and unsigned, against the baseline (`notes/macos-arm64-comparison.txt`):
  - app (`appSizeMac`): 845,641,998 → 671,819,387 bytes (−20.6%)
  - update zip: 351,685,241 → 311,273,791 bytes
  - DMG: 336,770,658 → 247,688,811 bytes
  - The update zip carries the 112 locale-pack links. The ad-hoc-signed framework verifies with `codesign --verify --deep --strict`. The LZMA DMG mounts, and its `Studio.app` is identical to the packaged one.
- Locale packs on real Electron 44.9.1 builds:
  - macOS, the change's package (`notes/mac-locale-hook-probe.txt`): `app.getLocale()` matches the baseline for `(fi)`, `(fi,de)`, `(de)`, `(ca)`, `(da,es)`, `(sw)`, `(en)` and `(en-GB)`. Chromium's strings are English for the linked locales and translated for the kept ones.
  - Linux arm64, hook applied to the release zip, run in a container (`notes/linux-locale-hook-probe.txt`): 55 packs, of which 28 link to `en-US.pak`. The same holds for the `LANGUAGE` lists `fi`, `fi:de`, `de`, `ca`, `da:es`, `sw` and `en_GB`.
  - Windows x64, hook applied to the release zip on this Mac and not run (`notes/win-locale-hook-check.txt`): 55 packs, of which 28 are copies of `en-US.pak`, 13,855,794 bytes smaller.
- Offline first run of the change's packaged CLI, fresh config, outgoing connections blocked except to localhost (`notes/offline-first-run.txt`, from the build before decision 4, whose CLI is unchanged since): migration 06 unpacks PHP into `<config>/php-bin/8.4.27-studio-1` (70,040 KiB, the baseline's size). A site with Studio language `de` is created and started on PHP 8.4.27, WordPress 7.1.4 and `WPLANG` `de_DE`, and a WXR import adds its post.
- The packaged end-to-end suite passes on the change's macOS arm64 build: 32 passed, 1 skipped (the Windows-only composition test). The run covers upgrade, localization, the system language, package composition, sites, import, export, blueprints, chat and publish (`notes/e2e-macos-arm64.txt`).

## Remaining

- Verification the design doc assigns that this machine can't run (macOS arm64, no signing identity, no Windows), left to CI and release builds:
  - the other five platform and architecture pairs, including the system-language and composition e2e tests on Windows (design-doc-assumption-4) and Linux
  - signature inspection on signed release builds, and notarization with the linked packs (design-doc-assumption-5)
  - the Store package and its `studio.exe` alias
  - the in-app update from the previous release on each platform
  - the deb install
  - the LZMA DMG on macOS 13
  - each AI provider in Studio Code
  - the spec-requirement-7 features the e2e suite doesn't reach
  - a standalone CLI bundle; building one here rewrites the workspace's `apps/cli/node_modules`
- The lint guardrail's file list includes the design doc's `2-design-doc/design-doc/scripts/locale-match.mjs`, which ESLint can't parse (it's in no tsconfig project). Every file the change touches lints clean.

## Decisions

- The Store launcher is built in `scripts/package-appx.mjs`, not in prePackage. The Store packaging is its only consumer. Outside the packaged folder, neither Squirrel nor the packager's signing reaches it, so the Store step signs it itself.
- PHP is signed with the identity `@electron/osx-sign` picks: the first valid "Developer ID Application" in `security find-identity -v`. Without one, as in local builds, signing is skipped. With one, a `codesign` failure fails the packaging, because notarization doesn't look inside the archive.
- `apps/studio/entitlements/php.plist` reproduces the `default.darwin.plist` of `@electron/osx-sign` 2.7.1. That package's `exports` don't let the config resolve the file.
- Each macOS gendered locale pack links to the matching English variant (`en_FEMININE.lproj/locale.pak` and so on). All 165 gendered packs are the same 18-byte empty pack, so their content doesn't change.
- "English itself" is every locale whose language is `en` (`en`/`en-US` and `en-GB`), so `en-GB` keeps its own pack.
- The packaged-output test lists `app.asar` by running the packaged executable with `ELECTRON_RUN_AS_NODE=1`, so it needs no asar dependency.
- The system-language e2e test sets the languages with `-AppleLanguages` on macOS, `LANGUAGE` on Linux and `--lang` on Windows, which takes a single language.
- Supporting scripts are shell scripts, so the lint guardrail gets no JavaScript files from `.pipelines/`.
- `apps/studio/out` holds the change's macOS arm64 package and DMG. The baseline package the design doc built there was copied to `/tmp/studio-improve-app-size-implementer/baseline/out` before packaging, and `/tmp` may not keep it.

## Failed approaches

- node-tar's `brotli` option type has no `params`, so the packaging pipes `tar.c` through `zlib.createBrotliCompress` instead.
- Removing the packs of locales Studio maps to English, as first designed. On macOS it empties Chromium's strings, and on Linux it can change Studio's language (`notes/mac-locale-probe.txt`, `notes/linux-locale-probe.txt`).

## Assumptions

- design-doc-assumption-2: observed on macOS arm64 only: the packaged end-to-end suite and the offline first run pass on the filtered trees (`notes/e2e-macos-arm64.txt`, `notes/offline-first-run.txt`). The other platforms are open.
- design-doc-assumption-3: observed by reading the signing code, not on a signed Windows build. The packager signs Windows apps with `@electron/windows-sign` 2.1.0 over the whole staging folder (`createSignOpts( …, this.stagingPath )` in `@electron/packager/dist/win32.js`). Its `getFilesToSign` takes every `.exe`, `.dll`, `.sys`, `.efi`, `.scr` and `.node` file, so `resources/php-bin` gets signed. On macOS, a CI-signed Studio's PHP and `xdebug.so` carry the Developer ID signature, the hardened runtime and osx-sign's default entitlements (`notes/php-signatures.txt`).
- design-doc-assumption-4: open: Windows isn't available here. The system-language e2e test runs on Windows CI.
- design-doc-assumption-5: partly observed: the macOS update zip carries the links, the DMG keeps them, and the ad-hoc-signed framework verifies with `--strict` (`notes/macos-arm64-comparison.txt`). Developer ID signing, notarization and the deb install are open.
- spec-assumption-1: open. It's measured on macOS arm64 only (under Done), plus the Windows locale-pack bytes.
