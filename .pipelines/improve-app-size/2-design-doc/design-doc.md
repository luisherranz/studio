# Design Doc: A smaller Studio application

## Overview

A large share of Studio's installation is bytes that no code path reads, or reads only once. Measured on the baseline macOS Apple silicon package (845,641,728 bytes):

- source maps and TypeScript declarations in the CLI's dependencies: 64.7 MB
- build tools that `@sentry/node` 11 pulls into the app archive: 22.4 MB, plus 6.5 MB of TypeScript declarations there
- Chromium locale packs for languages Studio maps to English: 30.1 MB
- the default PHP package, shipped unpacked and copied unchanged into the config folder on first run: 71.5 MB

The Windows installer builds also carry a 57.5 MB launcher that only the Microsoft Store build uses. The DMG is compressed with zlib.

The change is packaging plus one CLI migration. Studio:

- ships only the files its runtime reads
- gives the locales it maps to English the English locale pack
- keeps the PHP package compressed until first run unpacks it where it lands today
- keeps the Store-only launcher in the Store package
- compresses the DMG with LZMA No program, runtime, launcher, config-folder layout or update payload format changes, so every feature runs the same code on the same inputs as the baseline. On macOS Apple silicon the removals come to about 177 MB of the installation (−21%) and about 41 MB of the 352 MB update zip. LZMA alone cuts the DMG from 336.8 MB to 267.1 MB before any content is removed.

## Architecture

Modified components:

- **Desktop packaging** (`apps/studio/forge.config.ts`, its prePackage hook and packager options) decides what the installation contains. It takes on four new responsibilities:
  - giving the Electron locales Studio maps to English the English pack (design-doc-decision-4)
  - leaving build tools and type declarations out of `app.asar` (design-doc-decision-3)
  - producing the signed, compressed PHP archive from the PHP package it downloads today (design-doc-decision-6)
  - keeping the Store-only launcher out of the installer artifacts (design-doc-decision-5)
- **CLI packaged build**: the `apps/cli` `package` and `package:standalone` scripts, through `vite.config.prod.ts`, which copies the installed `node_modules`. It ships only the runtime files of the CLI's dependencies (design-doc-decision-2). The Desktop packaging (`cli:package`) and the standalone bundle (`scripts/create-standalone-bundle.ts`) both use it.
- **Store packaging** (`scripts/package-appx.mjs`): its package carries the launcher that its `studio.exe` alias targets (design-doc-decision-5).
- **DMG builder** (`scripts/make-dmg.mjs`): builds the published DMG with LZMA compression (design-doc-decision-7).
- **CLI migration 06** (`apps/cli/migrations/06-install-bundled-default-php.ts`) installs the default PHP package into `<config>/php-bin/<package-id>/` from the bundled archive instead of copying a folder. Its contract is otherwise unchanged (design-doc-decision-6).

Untouched but relevant:

- **Studio's language selection** (`apps/studio/src/lib/locale-node.ts` `getSupportedLocale`, `packages/common/lib/locale.ts` `supportedLocales`, `packages/common/translations/`) is the source of truth design-doc-decision-4 uses to decide which locales keep their own packs.
- **The PHP runtime after install**: `apps/cli/lib/native-php/config.ts` writes `php.ini` and the CA bundle beside the installed binary, and `apps/cli/lib/dependency-management/php-binary.ts` handles on-demand versions and the download fallback. Both read `<config>/php-bin/<package-id>/` as today.
- **Launchers and runtime references** keep naming the bundled Node:
  - the launchers in `apps/studio/bin/`
  - the Desktop CLI runner (`getBundledNodeBinaryPath` in `apps/studio/src/storage/paths.ts`)
  - the agent-app MCP configs (`packages/common/lib/connect-agent-app.ts`)
  - the Linux postinst capability grant
- **Updater** (`apps/studio/src/updates.ts`) and its payload formats.
- **App-size metric** (`tools/metrics/tests/app-size.test.ts`).

Build data flow:

1. Install dependencies.
2. CLI packaged build, keeping runtime files only.
3. Desktop prePackage: fetch the PHP package, sign its executables with the release identity, compress it into one archive, and build the Store launcher.
4. Packager: build the asar with its exclusions, and give the locales Studio maps to English the English pack.
5. Platform signing.
6. Makers: zip; Squirrel, without the Store launcher; deb.
7. DMG, with LZMA.
8. Store package, with the launcher.

Runtime data flow: on the first CLI run with no `<config>/php-bin/<default package-id>/`, migration 06 unpacks the archive there. Site start, Xdebug and version switching then use it as today.

Post-change coherence:

- **Narrowed contracts and their consumers:**
  - The CLI's packaged `node_modules` loses `*.map` and `*.d.ts`/`*.d.mts`/`*.d.cts`. No runtime code reads declarations. Only Playwright's stack-trace rewriting reads maps.
  - `app.asar` no longer resolves `@sentry/node`'s `./vite`, `./rollup`, `./webpack` and `./esbuild` entry points. The main process requires only `@sentry/electron/main`.
  - The packs of locales Studio maps to English now carry English strings. Chromium's choice of app locale, and with it `app.getLocale()`, `getSupportedLocale` and the renderer's default locale, is unchanged.
  - The installer builds lose `studio-cli.exe`. Its only consumer is the Store alias.
  - The installation no longer holds an unpacked PHP. Its only consumer is migration 06.
- **Generality left without a purpose:** the prePackage step that unpacks the PHP package into `apps/studio/php-bin` exists only to feed the installation. It now feeds the archive.
- No contract widens.

## Decisions

design-doc-decision-1: Approach: package only what runs and keep every program as it is

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-3, spec-requirement-4, spec-requirement-10, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-3, spec-acceptance-criterion-4, spec-acceptance-criterion-11

**Decision:** The savings come from packaging:

- files no runtime path reads are left out (design-doc-decision-2 to design-doc-decision-5)
- the one package read only once is shipped compressed (design-doc-decision-6)
- the DMG is compressed more tightly (design-doc-decision-7)

These stay as the baseline has them: every executable and runtime the installation runs, the launchers, the CLI's commands and IPC, the config-folder layout, and the update payload formats. The features in spec-requirement-4 to spec-requirement-10 therefore run the same code on the same inputs. The only runtime code that changes is where migration 06 reads the default PHP package from. Nothing new is installed, and an update from the previous release lands on a config folder the new release reads as is.

**Alternatives:**

- **Only leave out the CLI's source maps and declarations (design-doc-decision-2 alone).** This is the simplest option that meets spec-requirement-1 to spec-requirement-3, because every artifact carries those files. Rejected: the Goal is size. Design-doc-decision-3 to design-doc-decision-7 take out about 112 MB more of the macOS Apple silicon installation, plus 70 MB of the DMG, and still change nothing that runs other than migration 06's source.
- **Run the CLI on Electron's own Node and drop the bundled Node.** This is the largest single item: 122.5 MB on macOS Apple silicon, and a 94 MB `node.exe` on Windows x64. The performance regression that motivated the bundled Node no longer reproduces: Electron 44.9.1 runs as Node 24.22.0, and a site create and start took 4.17 s on it against 4.57 s on the bundled Node. Rejected because it changes the program behind every CLI command, daemon, site server, MCP server and agent run on every platform:
  - Agent apps start Studio's MCP server with the Node path Studio writes into their plugin config. Each of those launches would need an environment variable so the GUI binary doesn't open a window.
  - On Linux the proxy binds ports 80 and 443 through `CAP_NET_BIND_SERVICE`, which the deb's postinst sets on `resources/bin/node`. That capability would have to move onto the `studio` executable, which also runs the whole GUI app, or Linux alone would keep a separate Node.
  
  The chosen decisions meet spec-requirement-1 to spec-requirement-3 without changing what runs.
- **Bundle every dependency into the CLI and main-process bundles.** Rejected for this change: it changes how each bundled package resolves its modules and files. The largest dependency tree, pi's, reads its own files at runtime (design-doc-decision-2) and would stay external anyway. It complements rather than replaces design-doc-decision-2 and design-doc-decision-3, which apply to whatever stays external.
- **Strip symbols from the PHP binary.** The PHP binary workflow builds it, the CLI pins it by hash, and on-demand downloads share it. That is outside the app's packaging.

**Trade-offs:** The second Node runtime, the largest removable item, stays. On macOS Apple silicon the installation shrinks by about 21% rather than about 35%.

**Claims:**

- observed: the baseline package composition, from packaging it with `npm run make:macos-arm64`; the bundled `bin/node` is 122,545,856 bytes (`design-doc/baseline-macos-arm64-composition.txt`). The Windows x64 `node.exe` is 93,915,464 bytes (`1-spec/spec/nightly-2.3.0-dev166-installed-composition.txt`).
- observed: the Linux `executableName` is `studio`, the Electron binary (read `apps/studio/forge.config.ts`). The CLI ran on it with `ELECTRON_RUN_AS_NODE=1` before the bundled Node (`git show 9e19d25f1`).
- observed: runtime versions and site create and start timings for both runtimes, from running the packaged CLI in an isolated config (`design-doc/runtime-probe.txt`).
- observed: the MCP server command is `cli.nodeBinary` (read `packages/common/lib/connect-agent-app.ts`, `writeMarketplace`). The capability is set on `resources/bin/node` (read `apps/studio/installers/linux/postinst.sh`, `apps/cli/lib/proxy-server.ts`).
- assumed: the same parts shrink on the other five pairs, to be confirmed by packaging them (spec-assumption-1).

design-doc-decision-2: The CLI ships only its dependencies' runtime files

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-3, spec-requirement-8, spec-requirement-9, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-3, spec-acceptance-criterion-9, spec-acceptance-criterion-10

**Decision:** The CLI packaged build copies the CLI's installed production dependencies without:

- source maps (`*.map`)
- TypeScript declarations (`*.d.ts`, `*.d.mts`, `*.d.cts`)

Every other file of every package stays, including markdown, `package.json` files and TypeScript sources. The Desktop packaging and the standalone bundle both get the same tree. The Desktop-only prunes in prePackage (other platforms' koffi builds, unused provider SDKs) stay as they are. This extends to the CLI the rule the app archive already applies to source maps.

**Alternatives:**

- **Prune in the Desktop prePackage, next to the existing prunes.** The standalone bundle states that it applies "the same node_modules prunes the desktop packaging applies", through its own tar excludes. A second list would drift from the Desktop's. Filtering in the build both of them use keeps one rule.
- **Also drop markdown, docs, examples and changelogs (6.3 MB of markdown).** pi-coding-agent resolves its own `README.md`, `docs/` and `CHANGELOG.md` at runtime.

**Trade-offs:** Playwright's own error stack traces show bundle positions instead of source positions, because its source-map support finds no maps. Standalone CLI bundles shrink too, which spec-exclusion-1 doesn't require, and run the same tree as the Desktop's CLI.

**Claims:**

- observed: the removed files are 12,453 files and 64,738,161 bytes; 17.3 MB with zip -6 and 5.2 MB with xz -6 (`design-doc/candidate-removals.txt`).
- observed: no runtime code reads declarations. The matches are embedded `package.json` metadata and jiti's resolver extension table, and Studio's agent configures no pi extensions. Maps are read only by Playwright's source-map-support. The CLI's own chunks are built with `sourcemap: false` (`design-doc/candidate-removals.txt`; read `apps/cli/vite.config.base.ts`).
- observed: `app.asar` already leaves out `\.map$` (read the `ignore` list in `apps/studio/forge.config.ts`; the extracted asar holds no `.map` file).
- observed: both packagings go through the prod build (read `apps/cli/package.json` scripts and `apps/cli/vite.config.standalone.ts`).
- assumed: no feature in spec-requirement-5 to spec-requirement-10 reads a removed file (design-doc-assumption-2).

design-doc-decision-3: The app archive carries no build tools and no type declarations

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-3, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-3

**Decision:** The Desktop packaging already leaves source maps out of `app.asar`. It now also leaves out:

- TypeScript declarations
- the packages that `@sentry/node` 11 declares only for its bundler-plugin entry points: the Sentry CLI package `sentry`, `@sentry/bundler-plugins`, `oxc-parser`, and oxc's platform binding and type packages

The main process requires `@sentry/electron/main`, which reaches none of them.

**Alternatives:**

- **Bundle the main process's dependencies instead of externalizing them,** as the preload already does for `@sentry/electron`. Tree-shaking would drop them, but it changes how every main-process dependency loads, for a saving of about the same size.
- **Keep them** until Sentry stops declaring them: nothing is saved.

**Trade-offs:** The exclusion is a list of names. A dependency upgrade that adds another build tool to the runtime tree ships it until the list follows, and the size metric shows the growth. A future main-process import of an excluded package fails at startup, which the packaged end-to-end suite catches.

**Claims:**

- observed: the build tools are 22,438,694 bytes (6.5 MB with zip -6), and the declarations 6,530,177 bytes (1.9 MB with zip -6) (`design-doc/candidate-removals.txt`).
- observed: the dependency chain runs `@sentry/electron` 8.4.0 → `@sentry/node` 11.10.0 → `@sentry/bundler-plugins` → `sentry` 0.45.0 and `oxc-parser`. `@sentry/bundler-plugins` is referenced only from `@sentry/node`'s `bundler-plugin/{vite,rollup,webpack,esbuild}.js` (`design-doc/baseline-macos-arm64-composition.txt`).
- observed: `dist/main/index.js` requires `@sentry/electron/main` and no other `@sentry` module (grep of its `require` calls).

design-doc-decision-4: Electron locales that Studio maps to English carry the English pack

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-3, spec-requirement-6, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-3, spec-acceptance-criterion-7

**Decision:** Every one of the 55 Electron locales keeps a pack at its usual path:

- macOS: `Electron Framework.framework/Resources/<locale>[_<gender>].lproj/locale.pak`
- Windows and Linux: `locales/<locale>.pak`

The packaging sorts each locale with Studio's language matcher, `getSupportedLocale`, which calls `match( [ locale ], supportedLocales, 'en' )`:

- **Locales the matcher maps to a Studio translation, and English itself:** they keep their own packs.
- **Every other locale:** it carries the English pack's content in place of its own. On macOS this includes the gendered variants. On macOS and Linux, whose package formats carry symbolic links, the pack is a link to the English pack. On Windows, whose setup program, update package and Store package can't, it is a copy of the English pack.

The packaging derives this split from the same matcher and translation list the app uses, so adding a translation keeps that language's packs. The app bundle's own `Contents/Resources/*.lproj` folders on macOS are unchanged.

Every locale keeps a pack, so Chromium chooses the same app locale it chooses today on every platform:

- `app.getLocale()` and the renderer's default locale stay as they are today.
- Studio's language, from the system language or from Settings → Language, is unchanged.
- For a locale that carries the English pack, Chromium's own strings are in English.

**Alternatives:**

- **Remove the packs of locales the matcher maps to English.** This is what was measured as saving the most. Rejected because Chromium then behaves differently per platform, and none of the behaviors match the baseline:
  - On macOS it keeps the locale and shows empty strings.
  - On Linux it moves to the next language the user lists, and that can change Studio's language. With `LANGUAGE=fi:de` and the Finnish pack removed, Chromium picks German where the baseline shows English.
  - Windows wasn't observed, and its update package can't carry links.
- **On macOS, also remove the app bundle's own `.lproj` folder.** Chromium then falls back to the next language the user lists, so `(fi, de)` gives German where the baseline gives English.
- **Keep every pack on Windows, where links aren't possible.** Windows would keep localized Chromium strings and save nothing. Rejected: copies of the English pack still take 13.9 MB off the installation and give every platform the same behavior.
- **Keep packs by the language subtag of Studio's translations.** This treats Afrikaans, Catalan and Malay as English, but the matcher maps them to Dutch, Spanish and Indonesian, so those users' Chromium strings would leave their language.
- **Keep every pack:** nothing is saved.

**Trade-offs:** For users whose system language is one of the 28 locales Studio maps to English, Chromium's own strings, such as form validation messages, are in English instead of their language. Studio's own interface was already English for them. Windows saves less than macOS and Linux, because each copy of the English pack takes 586,582 bytes.

**Claims:**

- observed: 25 of the 55 Electron 44.9.1 locales map to a translation: af, ar, ca, de, es, es-419, fr, he, hu, id, it, ja, ko, ms, nl, pl, pt-BR, pt-PT, ru, sv, tr, uk, vi, zh-CN and zh-TW (`design-doc/electron-locale-match.txt`).
- observed: on macOS Apple silicon the packs that become links are 30,113,308 bytes; 7.0 MB with zip -6 and 4.5 MB with xz -6 (`design-doc/baseline-macos-arm64-composition.txt`, `design-doc/candidate-removals.txt`).
- observed: on Windows x64 these 28 locales' packs are 30,280,090 bytes. Replaced by copies of `en-US.pak`, they take 16,424,296, which saves 13,855,794 bytes installed and 1,435,149 with zip -6 (`design-doc/locale-pack-aliases.txt`).
- observed: Linux ships 8,900 KiB of locale packs (`1-spec/spec/nightly-2.3.0-dev166-installed-composition.txt`).
- observed: on macOS and Linux, a link to the English pack keeps `app.getLocale()` as in the baseline and gives English Chromium strings. Removing the pack empties them on macOS, and on Linux moves the choice to the next listed language. Removing the app bundle's `.lproj` on macOS does the same (`design-doc/locale-pack-probes.txt`, reproducing `3-implementation/notes/mac-locale-probe.txt` and `linux-locale-probe.txt`).
- observed: the macOS update zip carries the bundle's 14 symbolic links. The deb's staging copy recreates links with their original targets (`design-doc/locale-pack-aliases.txt`).
- observed: `app.getLocale()` is read only by `getSupportedLocale` and a startup log line (grep of `apps/studio/src`).
- assumed: on Windows, Chromium's choice of app locale depends only on which locale packs exist, so the copies keep the baseline's choice (design-doc-assumption-4).
- assumed: the macOS links pass signing and notarization and survive the DMG and Squirrel.Mac installs, and the deb's links survive its install (design-doc-assumption-5).

design-doc-decision-5: The Store-only CLI launcher ships only in the Store package

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-3, spec-requirement-9, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-3, spec-acceptance-criterion-10

**Decision:** The Windows setup program and update package no longer carry `resources/bin/studio-cli.exe`. The Microsoft Store package carries it, built and signed as today, at the path its `studio.exe` alias targets. The installer builds keep `studio-cli.bat`, which Settings' terminal CLI points at.

**Alternatives:**

- **Replace the pkg-built launcher with a small compiled launcher for every build.** pkg wraps the 1.9 KB launcher script in a whole Node runtime. A compiled launcher would shrink the Store package too, but it adds a compiled launcher and its build to the Windows packaging, for a package the other decisions already shrink.
- **Keep it in both:** the installer builds save nothing.

**Trade-offs:** Squirrel and the Store packaging share the packaged folder (`out/Studio-win32-<arch>`). The launcher has to reach the Store step and stay out of the Squirrel artifacts.

**Claims:**

- observed: the alias targets `app\resources\bin\studio-cli.exe` (read `scripts/package-appx.mjs`, `addAppExecutionAliasToManifest`).
- observed: the installer's terminal CLI points at `resources/bin/studio-cli.bat` (read `apps/studio/src/modules/cli/lib/windows-installation-manager.ts`, `installProxyBatFile`).
- observed: the launcher is built in prePackage for every win32 build (read `apps/studio/forge.config.ts`).
- observed: CI builds the Squirrel artifacts and then the Store package from the same output (read `.buildkite/commands/build-for-windows.ps1`).
- observed: the launcher is 57,529,672 bytes on Windows x64 (`1-spec/spec/nightly-2.3.0-dev166-installed-composition.txt`).

design-doc-decision-6: The default PHP package ships compressed and unpacks on first run where it lands today

**Serves:** spec-requirement-1, spec-requirement-2, spec-requirement-3, spec-requirement-5, spec-requirement-7, spec-requirement-10, spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-3, spec-acceptance-criterion-5, spec-acceptance-criterion-6, spec-acceptance-criterion-8, spec-acceptance-criterion-11

**Decision:** The installation carries the default PHP package as one archive instead of the unpacked `php-bin/<package-id>/` folder. The archive has two properties:

- **It yields the files the baseline installation's folder holds, with the signatures the release signing gives them today:** Developer ID with the hardened runtime and the same entitlements on macOS, and the release signature on Windows. The app's signing step can't reach into an archive, so the packaging signs these files before compressing them.
- **It is compressed with a codec that the CLI's runtime extracts with what the CLI already ships,** and more tightly than the deflate the macOS update zip and the Windows packages apply.

Migration 06 keeps its contract, now with the archive as its source:

- It runs when the bundled package exists and `<config>/php-bin/<package-id>/` doesn't.
- The destination appears complete or not at all.
- A process that loses the race to install leaves the winner's folder in place.
- On failure it warns and leaves no folder.

What happens after the migration is unchanged: `php.ini` and the CA bundle, on-demand versions, the download fallback, and version switching.

**Alternatives:**

- **Run the bundled PHP from the installation and stop copying it.** This would save the 71 MB config copy instead. Rejected:
  - `php.ini` and the CA bundle are written beside the binary.
  - The installation is read-only on the Store, deb and signed macOS builds.
  - On Windows the installation path changes with every update, while sites keep running across updates.
- **Ship the CDN's PHP package as it is and install it with the on-demand installer.** It reuses the download path, but:
  - its deflate saves nothing in the zip-based downloads
  - it grows the xz-compressed deb by about 8 MB for this part
  - its binary is only ad-hoc signed
- **Keep the folder:** nothing is saved.

**Trade-offs:**

- First run unpacks instead of copying; decompressing the macOS Apple silicon package took 0.16 s.
- Packaging has to sign PHP's executables before archiving them, and the tightest settings measured take minutes to compress.
- The deb's xz already compresses the unpacked files to the same ratio, so this part of the deb stays about the same: 0.5 MB larger with the codec measured.
- Without a signing identity, as in local unsigned builds, the archive keeps the CDN binary's ad-hoc signature, the one on-demand PHP versions run with today.

**Claims:**

- observed: the package is 71.5 MB unpacked, 26.4 MB with deflate, 18.5 MB with a codec Node's runtime has (tar plus brotli) and 18.0 MB with xz (`design-doc/php-archive-compression.txt`).
- observed: the 2.2.0 deb is xz-compressed (`design-doc/php-archive-compression.txt`).
- observed: the CDN `php` binary is ad-hoc signed (`codesign -dv` on the packaged `php-bin/8.4.27-studio-1/php`).
- observed: the migration's run condition, staging and rename, and race handling (read `apps/cli/migrations/06-install-bundled-default-php.ts` and its tests).
- observed: `php.ini` and the CA bundle are written beside the binary (read `apps/cli/lib/native-php/config.ts`).
- observed: the Windows installation lives in a versioned folder whose path changes with each update (read `windows-installation-manager.ts`, `installProxyBatFile`). Sites left running across an update are restarted by the new release (read `apps/cli/lib/daemon-client.ts` `runSiteStart`; `apps/studio/e2e/upgrade.test.ts`).
- assumed: today's Windows release signing signs the PHP executables and DLLs under `resources/php-bin`. Inspecting a signed release build confirms it (design-doc-assumption-3).

design-doc-decision-7: The DMG is LZMA-compressed

**Serves:** spec-requirement-2, spec-acceptance-criterion-2

**Decision:** The DMG that Studio publishes, built by `scripts/make-dmg.mjs`, uses LZMA compression (UDIF `ULMO`) in place of zlib (`UDZO`). Its layout and contents are unchanged. `ULMO` needs macOS 10.15, and Studio requires macOS 13.0.

**Alternatives:**

- **LZFSE (`ULFO`):** only 1.7% smaller than zlib.
- **Keep zlib:** nothing is saved.

**Trade-offs:** Building the DMG takes seconds longer, and mounting it decompresses LZMA instead of zlib.

**Claims:**

- observed: built as CI builds it, the baseline DMG is 336,770,658 bytes with zlib, 331,125,506 with LZFSE and 267,061,374 with LZMA (`design-doc/dmg-compression.txt`).
- observed: `LSMinimumSystemVersion` is 13.0, and appdmg takes a `format` option that defaults to `UDZO` (`design-doc/dmg-compression.txt`).

## Interfaces

Each artifact Studio publishes has the same layout as the baseline's, with these differences:

- **Packaged CLI** (`resources/cli/node_modules`): no `*.map`, `*.d.ts`, `*.d.mts` or `*.d.cts`. All other files are unchanged.
- **`app.asar`, and `app.asar.unpacked`, where native modules are unpacked:** none of these:
  - `*.map`, as today
  - `*.d.ts`, `*.d.mts` or `*.d.cts`
  - `node_modules/sentry`, `node_modules/@sentry/bundler-plugins`, `node_modules/oxc-parser`, `node_modules/@oxc-parser/*` or `node_modules/@oxc-project/*`
- **Electron locale packs:** all 55 locales keep a pack at the baseline's path. A locale that `getSupportedLocale`'s matcher maps to a Studio translation, and English itself, keeps its own pack. Every other locale's packs, including the macOS gendered variants, hold the English pack's content: a symbolic link to it on macOS and Linux, a copy on Windows. On macOS the app bundle's own `Contents/Resources/*.lproj` folders are unchanged.
- **Default PHP:** the installation holds one archive of the default PHP package where `php-bin/<package-id>/` was. It unpacks to the files of that folder in the signed baseline installation.
- **Windows setup program and update package:** no `resources/bin/studio-cli.exe`.
- **Microsoft Store package:** `app\resources\bin\studio-cli.exe`, as today.
- **DMG:** UDIF `ULMO`.

Migration 06's contract with the CLI's runtime stays as it is. When the config folder lacks the default package, it ends with `<config>/php-bin/<package-id>/` holding the package's files, with the binary executable. Otherwise it changes nothing.

## Dependencies

No new runtime dependency: the CLI extracts the archive with what it already ships.

At build time:

- Signing PHP's executables before archiving uses the tools the release builds already use: `codesign` with the release identity on macOS, and the Azure Trusted Signing hook (`scripts/azure-sign-hook.cjs`) on Windows.
- The DMG format uses appdmg's existing `format` option.

## Failure modes and observability

- **Migration 06 can't unpack the archive,** because the disk is full or the archive is corrupt. It warns, as a failed copy does today, and leaves no folder. When online, the first site start then downloads the package through `ensurePhpBinaryAvailable`. Offline, the start fails with the existing error. The warning appears in the CLI output the Desktop app logs.
- **A dependency upgrade makes runtime code read a removed file, or import an excluded package.** The packaged app fails with a module or file-not-found error where that code runs. The packaged end-to-end suite catches it on each platform.
- **A release build archives PHP without the release signature,** for example when signing is skipped. The installed PHP is ad-hoc signed on macOS and unsigned on Windows, as on-demand versions are today. The signature inspection in Verification detects it.
- **The Store package lacks its launcher,** so the `studio` alias fails. The packaged-output test detects it.

## Verification

- existing test `tools/metrics/tests/app-size.test.ts` › "measure packaged app size" — spec-acceptance-criterion-1 — the packaged macOS Apple silicon installation (`appSizeMac`) is smaller than the baseline's.
- end-to-end flow — spec-acceptance-criterion-1, spec-acceptance-criterion-2, spec-acceptance-criterion-3, design-doc-decision-2, design-doc-decision-3, design-doc-decision-4, design-doc-decision-5, design-doc-decision-6, design-doc-decision-7 — on each of the six pairs, compared with the baseline packaged the same way, three things are smaller: the installed application, each download file, and the installation plus Studio's config folder after a site is created and started.
- new test at the packaged-output boundary, run after each platform's CI packaging — design-doc-decision-2, design-doc-decision-3, design-doc-decision-4, design-doc-decision-5, design-doc-decision-6 — the output matches the composition contracts under Interfaces.
- new test at the boundary of the locale split's derivation — design-doc-decision-4, spec-acceptance-criterion-7 — a locale keeps its own pack exactly when it is English or Studio's matcher maps it to a translation, whichever language that translation is in.
- new test at the packaged-app boundary (end-to-end), on each platform — design-doc-decision-4, spec-acceptance-criterion-7 — whatever languages the system lists, Studio picks the same language and Chromium the same app locale as the baseline. For a locale that carries the English pack, Chromium's own strings are in English and never empty.
- inspection — design-doc-decision-4 — a signed and notarized macOS release build with the linked packs passes code-signature verification and Gatekeeper.
- existing tests `apps/studio/e2e/localization.test.ts` › "applies a language, right-to-left included, and keeps it across a restart" and "created site language matches Studio language", on each platform's packaged build — spec-acceptance-criterion-5, spec-acceptance-criterion-7 — Settings → Language and the new site's language work with the locales that carry the English pack.
- existing tests `apps/cli/migrations/tests/06-install-bundled-default-php.test.ts` › "does not run when bundled PHP is unavailable", "does not replace an existing destination patch folder" and "keeps the folder another process installed first" — design-doc-decision-6 — the migration's run condition and race contract hold with the archive as the source.
- new test at the migration-06 boundary — design-doc-decision-6 — from the bundled archive, the migration installs the default package into the config folder with the unpacked package's files and executable permission, and leaves no folder when unpacking fails.
- inspection — design-doc-decision-6 — on signed macOS and Windows release builds, the PHP files the first run installs carry the same signatures as the baseline's installed copy: identity, hardened runtime and entitlements.
- end-to-end flow — spec-acceptance-criterion-4, spec-acceptance-criterion-5, spec-acceptance-criterion-6, design-doc-decision-6 — on each platform, a fresh installation on a computer without PHP, Node.js or a network creates and starts a site in a language spec-requirement-5 names, on the latest WordPress and bundled PHP, and imports a WXR file into it.
- existing packaged end-to-end suite `apps/studio/e2e` (app, sites, blueprints, import, import-formats, import-export, publish, chat, app-settings, ipc-bridge) on each platform — spec-acceptance-criterion-8, spec-acceptance-criterion-9, design-doc-decision-2, design-doc-decision-3, design-doc-decision-6 — the app's features run on the filtered dependency trees and the archived PHP.
- end-to-end flow — spec-acceptance-criterion-8 — on each platform's packaged build, each spec-requirement-7 feature the suite above doesn't reach produces the baseline's result: phpMyAdmin, Xdebug, `studio wp`, static export and publishing to Spacefast, WordPress.com pull and push, preview sites, and custom domains with HTTPS.
- end-to-end flow — spec-acceptance-criterion-9, design-doc-decision-2 — on the packaged build, Studio Code chats on each provider and runs its tools and skills. Each provider's SDK loads only when used, so each one is exercised.
- end-to-end flow — spec-acceptance-criterion-10, design-doc-decision-5 — `studio` commands, `studio ui` and `studio mcp` run from a terminal on each installer build with Settings' terminal CLI on, and on the Store build through its alias.
- existing test `apps/studio/e2e/upgrade.test.ts` › "starts the sites the previous version left running again after an update", on each platform — spec-acceptance-criterion-11 — sites the previous release left running start again after the update.
- end-to-end flow — spec-acceptance-criterion-11, design-doc-decision-1, design-doc-decision-6 — an installation of the previous release, with sites, settings and chats, updates through its platform's path (the in-app updater on macOS and Windows, the deb on Linux, the Store) and keeps them all. Its config folder's PHP stays in use without reinstalling.
- end-to-end flow — design-doc-decision-7, spec-acceptance-criterion-2 — the LZMA DMG mounts and installs Studio on macOS 13.
- end-to-end flow — design-doc-decision-2 — a standalone CLI bundle built from the change creates and starts a site.

## Risks

- **Second Node runtime.** It stays as the largest removable item: 122.5 MB on macOS Apple silicon (design-doc-decision-1).
- **Users whose system language is one of the 28 locales Studio maps to English** see Chromium's built-in strings in English instead of their language. Studio's interface was already English for them (design-doc-decision-4).
- **Locale choice on Windows was not observed.** It keeps the baseline's choice only if Chromium chooses from the pack files present, which the copies keep identical (design-doc-assumption-4).
- **The build-tool exclusion is a list of names.** A dependency upgrade can bring another build tool into the runtime tree, and only the size grows until the list follows (design-doc-decision-3).
- **PHP signature parity depends on packaging signing PHP before archiving it.** A release build that skipped it would run an ad-hoc-signed PHP on macOS and an unsigned one on Windows for every user, not only for on-demand versions (design-doc-assumption-3).
- **The deb gains about 0.5 MB from the PHP archive.** Its net decrease depends on the other removals on Linux, where the locale packs are already compressed (spec-assumption-1).

## Open assumptions

spec-assumption-1: Every installation and download can be made smaller than the baseline's on all six pairs while spec-requirement-3 through spec-requirement-10 hold. On macOS Apple silicon the removals are measured: about 177 MB of the 846 MB installation, about 41 MB of the update zip, and 70 MB more off the DMG from LZMA. The other five pairs were not packaged. — assumed: packaging the six pairs at the baseline and with the change and comparing them, and running the features those requirements list (Verification).

design-doc-assumption-2: No code path that spec-requirement-5 to spec-requirement-10 exercise reads a source map or type declaration from the CLI's or the app's dependencies, or loads an excluded build-tool package. — assumed: the packaged end-to-end suite and the end-to-end flows in Verification on each platform.

design-doc-assumption-3: Today's Windows release signing signs the PHP executables and DLLs under `resources/php-bin`, so the archive must carry that signature to keep parity. — assumed: listing the Authenticode signatures of those files in a signed baseline release build.

design-doc-assumption-4: On Windows, Chromium chooses the app locale from the locale pack files present, so copies of the English pack in place of the 28 locales Studio maps to English keep the baseline's choice of locale. — assumed: the new system-language end-to-end test on Windows.

design-doc-assumption-5: Locale packs linked to the English pack pass macOS signing and notarization, and survive the DMG, the Squirrel.Mac update install and the deb install. — assumed: the signed-build inspection, the packaged-output test, and the update and installation flows in Verification.
